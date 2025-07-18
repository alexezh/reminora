import Foundation
import CoreData
import CoreLocation

/**
 * Service to sync local Core Data with cloud backend
 */
class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()
    
    private let apiService = APIService.shared
    private let persistenceController = PersistenceController.shared
    
    @Published var isSyncing = false
    @Published var lastSyncTime: Date?
    
    private init() {
        loadLastSyncTime()
    }
    
    // MARK: - Sync Management
    
    func syncToCloud() async {
        await MainActor.run {
            isSyncing = true
        }
        
        do {
            // Upload any unsynced local photos
            try await uploadLocalPhotos()
            
            // Download new photos from timeline
            try await downloadTimelinePhotos()
            
            await MainActor.run {
                lastSyncTime = Date()
                saveLastSyncTime()
                isSyncing = false
            }
            
            print("Cloud sync completed successfully")
        } catch {
            await MainActor.run {
                isSyncing = false
            }
            print("Cloud sync failed: \(error)")
        }
    }
    
    // MARK: - Upload Local Photos
    
    private func uploadLocalPhotos() async throws {
        let context = persistenceController.container.viewContext
        
        // Fetch photos that haven't been uploaded yet (excluding private photos)
        let request: NSFetchRequest<Place> = Place.fetchRequest()
        request.predicate = NSPredicate(format: "cloudId == nil AND imageData != nil AND isPrivate == false")
        
        let localPhotos = try context.fetch(request)
        
        for place in localPhotos {
            do {
                try await uploadPhoto(place: place)
            } catch {
                print("Failed to upload photo \(place.objectID): \(error)")
                // Continue with other photos even if one fails
            }
        }
    }
    
    private func uploadPhoto(place: Place) async throws {
        guard let imageData = place.imageData else { return }
        
        // Extract location from place
        var location: CLLocation?
        if let locationData = place.value(forKey: "location") as? Data,
           let storedLocation = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation {
            location = storedLocation
        }
        
        // Upload to cloud
        let cloudPhoto = try await apiService.uploadPhoto(
            imageData: imageData,
            location: location,
            caption: place.post
        )
        
        // Update local record with cloud ID
        await MainActor.run {
            place.setValue(cloudPhoto.id, forKey: "cloudId")
            place.setValue(Date(), forKey: "cloudSyncedAt")
            
            do {
                try persistenceController.container.viewContext.save()
            } catch {
                print("Failed to save cloud ID: \(error)")
            }
        }
    }
    
    // MARK: - Download Timeline Photos
    
    private func downloadTimelinePhotos() async throws {
        let since = lastSyncTime?.timeIntervalSince1970 ?? 0
        let timeline = try await apiService.getTimeline(since: since, limit: 100)
        
        await MainActor.run {
            for cloudPhoto in timeline.photos {
                createOrUpdateLocalPhoto(from: cloudPhoto)
            }
        }
    }
    
    private func createOrUpdateLocalPhoto(from cloudPhoto: Photo) {
        let context = persistenceController.container.viewContext
        
        // Check if we already have this photo
        let request: NSFetchRequest<Place> = Place.fetchRequest()
        request.predicate = NSPredicate(format: "cloudId == %@", cloudPhoto.id)
        request.fetchLimit = 1
        
        do {
            let existingPlaces = try context.fetch(request)
            
            if let existingPlace = existingPlaces.first {
                // Update existing photo
                updatePlaceFromCloudPhoto(place: existingPlace, cloudPhoto: cloudPhoto)
            } else {
                // Create new photo
                createPlaceFromCloudPhoto(cloudPhoto: cloudPhoto, context: context)
            }
            
            try context.save()
        } catch {
            print("Failed to save photo from cloud: \(error)")
        }
    }
    
    private func createPlaceFromCloudPhoto(cloudPhoto: Photo, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Place", in: context)!
        let place = NSManagedObject(entity: entity, insertInto: context)
        
        // Set basic properties
        place.setValue(cloudPhoto.id, forKey: "cloudId")
        place.setValue(Date(timeIntervalSince1970: cloudPhoto.created_at), forKey: "dateAdded")
        place.setValue(cloudPhoto.caption, forKey: "post")
        place.setValue(Date(), forKey: "cloudSyncedAt")
        place.setValue(false, forKey: "isPrivate")  // Cloud photos are public by default
        
        // Convert image data
        if let imageData = Data(base64Encoded: cloudPhoto.photo_data.image_data) {
            place.setValue(imageData, forKey: "imageData")
        }
        
        // Set location
        if let location = cloudPhoto.location {
            let locationData = try? NSKeyedArchiver.archivedData(
                withRootObject: location,
                requiringSecureCoding: false
            )
            place.setValue(locationData, forKey: "location")
        }
        
        // Add user info as metadata
        let userInfo = "Shared by \(cloudPhoto.display_name) (@\(cloudPhoto.username))"
        place.setValue(userInfo, forKey: "url") // Using URL field for user info
    }
    
    private func updatePlaceFromCloudPhoto(place: Place, cloudPhoto: Photo) {
        // Update caption if it changed
        if place.post != cloudPhoto.caption {
            place.setValue(cloudPhoto.caption, forKey: "post")
        }
        
        place.setValue(Date(), forKey: "cloudSyncedAt")
    }
    
    // MARK: - Follow Management
    
    func followUser(username: String) async throws {
        // In a real implementation, you'd search for the user first
        let searchResults = try await apiService.searchUsers(query: username, limit: 1)
        guard let user = searchResults.first else {
            throw APIError.serverError("User not found")
        }
        
        if !user.isFollowing {
            _ = try await apiService.followUser(userId: user.id)
        }
    }
    
    func unfollowUser(userId: String) async throws {
        try await apiService.unfollowUser(userId: userId)
    }
    
    func getFollowingList() async throws -> [UserProfile] {
        return try await apiService.getFollowing()
    }
    
    // MARK: - Settings Persistence
    
    private func loadLastSyncTime() {
        if let timestamp = UserDefaults.standard.object(forKey: "lastCloudSync") as? Date {
            lastSyncTime = timestamp
        }
    }
    
    private func saveLastSyncTime() {
        UserDefaults.standard.set(lastSyncTime, forKey: "lastCloudSync")
    }
}