import Foundation
import CoreData
import CoreLocation
import UIKit

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
    
    // MARK: - Pin Management
    
    /**
     * Save a pin locally and sync to cloud
     * Use this for new pins created from photos
     */
    func savePinAndSyncToCloud(
        imageData: Data,
        location: CLLocation?,
        caption: String,
        isPrivate: Bool = false,
        context: NSManagedObjectContext
    ) async throws -> Place {
        
        // First, save to local database
        let place = try await MainActor.run {
            let newPlace = Place(context: context)
            newPlace.imageData = imageData
            newPlace.dateAdded = Date()
            newPlace.post = caption.isEmpty ? "Added from Photos" : caption
            newPlace.isPrivate = isPrivate
            
            if let location = location {
                let locationData = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false)
                newPlace.location = locationData
            }
            
            do {
                try context.save()
                print("📍 CloudSyncService: Pin saved locally")
                return newPlace
            } catch {
                print("❌ CloudSyncService: Failed to save pin locally: \(error)")
                throw error
            }
        }
        
        // If not private, sync to cloud immediately
        if !isPrivate {
            do {
                print("☁️ CloudSyncService: Syncing pin to cloud...")
                try await uploadPin(place: place)
                print("✅ CloudSyncService: Pin synced to cloud successfully")
            } catch {
                print("❌ CloudSyncService: Failed to sync pin to cloud: \(error)")
                // Don't throw error - local save succeeded, cloud sync can be retried later
            }
        }
        
        return place
    }
    
    /**
     * Upload a specific pin to cloud
     */
    func uploadPin(place: Place) async throws {
        guard let imageData = place.imageData else {
            throw APIError.invalidResponse
        }
        
        // Extract location from place
        var location: CLLocation?
        if let locationData = place.value(forKey: "location") as? Data,
           let storedLocation = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation {
            location = storedLocation
        }
        
        print("🌐 CloudSyncService: Uploading pin to backend...")
        
        // Upload to cloud using photos API (pins are stored as photos in backend)
        let cloudPhoto = try await apiService.uploadPin(
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
                print("💾 CloudSyncService: Updated pin with cloudId: \(cloudPhoto.id)")
            } catch {
                print("❌ CloudSyncService: Failed to save cloudId: \(error)")
            }
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
        // Use the new uploadPin method
        try await uploadPin(place: place)
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
    
    private func createOrUpdateLocalPhoto(from cloudPhoto: PinAPI) {
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
    
    private func createPlaceFromCloudPhoto(cloudPhoto: PinAPI, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Place", in: context)!
        let place = NSManagedObject(entity: entity, insertInto: context)
        
        // Set basic properties
        place.setValue(cloudPhoto.id, forKey: "cloudId")
        place.setValue(Date(timeIntervalSince1970: cloudPhoto.created_at), forKey: "dateAdded")
        place.setValue(cloudPhoto.caption, forKey: "post")
        place.setValue(Date(), forKey: "cloudSyncedAt")
        place.setValue(false, forKey: "isPrivate")  // Cloud photos are public by default
        place.setValue(cloudPhoto.location_name, forKey: "url")
        
        // Store original user information to preserve ownership
        place.setValue(cloudPhoto.account_id, forKey: "originalUserId")
        place.setValue(cloudPhoto.username, forKey: "originalUsername")
        place.setValue(cloudPhoto.display_name, forKey: "originalDisplayName")
        
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
    }
    
    private func updatePlaceFromCloudPhoto(place: Place, cloudPhoto: PinAPI) {
        // Update caption if it changed
        if place.post != cloudPhoto.caption {
            place.setValue(cloudPhoto.caption, forKey: "post")
        }
        
        place.setValue(Date(), forKey: "cloudSyncedAt")
    }
    
    // MARK: - User Profile Sync
    
    /**
     * Sync pins for a specific user profile
     */
    func syncUserPins(userId: String, limit: Int = 50) async throws -> [PinAPI] {
        print("🌐 CloudSyncService: Fetching user pins from cloud for user: \(userId)")
        let photos = try await apiService.getUserPins(userId: userId, limit: limit)
        print("🌐 CloudSyncService: Received \(photos.count) pins from API")
        
        // Sync to local storage for persistence
        await syncUserPinsToLocal(photos, userId: userId)
        
        print("✅ CloudSyncService: Loaded \(photos.count) pins from cloud and synced to local")
        return photos
    }
    
    /**
     * Sync user pins to local Core Data storage with proper ownership
     */
    private func syncUserPinsToLocal(_ photos: [PinAPI], userId: String) async {
        await MainActor.run {
            let context = persistenceController.container.viewContext
            print("🔄 CloudSyncService: Syncing \(photos.count) cloud photos to local storage")
            
            for photo in photos {
                // Check if this photo already exists locally
                let fetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "cloudId == %@", photo.id)
                
                do {
                    let existingPlaces = try context.fetch(fetchRequest)
                    
                    if existingPlaces.isEmpty {
                        // Create new local place from cloud data
                        let place = Place(context: context)
                        place.post = photo.caption ?? ""
                        place.url = photo.location_name ?? ""
                        place.dateAdded = Date(timeIntervalSince1970: photo.created_at)
                        place.isPrivate = false // Photos from API are shared
                        place.setValue(photo.id, forKey: "cloudId")
                        
                        // Store original user information to preserve ownership
                        place.setValue(photo.account_id, forKey: "originalUserId")
                        place.setValue(photo.username, forKey: "originalUsername")
                        place.setValue(photo.display_name, forKey: "originalDisplayName")
                        
                        // Store location
                        if let location = photo.location {
                            if let locationData = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false) {
                                place.setValue(locationData, forKey: "location")
                            }
                        }
                        
                        // Store image data
                        if let imageData = Data(base64Encoded: photo.photo_data.image_data) {
                            place.imageData = imageData
                        }
                        
                        print("📱 CloudSyncService: Created local place for cloud photo: \(photo.caption ?? photo.id)")
                    } else {
                        // Update existing local place with cloud data
                        let place = existingPlaces.first!
                        place.post = photo.caption ?? ""
                        place.url = photo.location_name ?? ""
                        place.dateAdded = Date(timeIntervalSince1970: photo.created_at)
                        place.isPrivate = false
                        
                        // Update original user information to preserve ownership
                        place.setValue(photo.account_id, forKey: "originalUserId")
                        place.setValue(photo.username, forKey: "originalUsername")
                        place.setValue(photo.display_name, forKey: "originalDisplayName")
                        
                        // Update image data
                        if let imageData = Data(base64Encoded: photo.photo_data.image_data) {
                            place.imageData = imageData
                        }
                        
                        print("📱 CloudSyncService: Updated local place for cloud photo: \(photo.caption ?? photo.id)")
                    }
                } catch {
                    print("❌ CloudSyncService: Failed to sync photo \(photo.id): \(error)")
                }
            }
            
            // Save all changes
            do {
                try context.save()
                print("✅ CloudSyncService: Successfully synced cloud photos to local storage")
            } catch {
                print("❌ CloudSyncService: Failed to save synced photos: \(error)")
            }
        }
    }
    
    /**
     * Convert cloud photo to virtual Place object for display
     */
    func convertPhotoToPlace(_ photo: PinAPI, context: NSManagedObjectContext) -> Place {
        // Create a detached place object for display (not saved to Core Data)
        let entity = NSEntityDescription.entity(forEntityName: "Place", in: context)!
        let place = Place(entity: entity, insertInto: nil) // insertInto: nil creates detached object
        
        // Use caption if available, otherwise use a default title
        let title = photo.caption?.isEmpty == false ? photo.caption! : "Pin \(photo.id.prefix(8))"
        place.post = title
        print("📝 CloudSyncService: Pin \(photo.id) caption='\(photo.caption ?? "nil")' -> title='\(title)'")
        print("📝 CloudSyncService: Place.post after assignment: '\(place.post ?? "nil")'")
        place.url = photo.location_name ?? ""
        place.dateAdded = Date(timeIntervalSince1970: photo.created_at)
        place.isPrivate = false // Photos from API are shared
        place.setValue(photo.id, forKey: "cloudId")
        
        // Store original user information to preserve ownership
        place.setValue(photo.account_id, forKey: "originalUserId")
        place.setValue(photo.username, forKey: "originalUsername")
        place.setValue(photo.display_name, forKey: "originalDisplayName")
        
        print("📍 CloudSyncService: Converting pin \(photo.id): title='\(title)', owner='\(photo.username)', has_image_data=\(photo.photo_data.image_data.count > 0)")
        
        // Store location
        if let location = photo.location {
            if let locationData = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false) {
                place.setValue(locationData, forKey: "location")
            }
        }
        
        // Store image data directly from photo
        print("🖼️ CloudSyncService: Base64 data length for pin \(photo.id): \(photo.photo_data.image_data.count) chars")
        if let imageData = Data(base64Encoded: photo.photo_data.image_data) {
            place.imageData = imageData
            print("✅ CloudSyncService: Successfully decoded image data for pin \(photo.id) - \(imageData.count) bytes")
            print("✅ CloudSyncService: Place.imageData after assignment: \(place.imageData?.count ?? 0) bytes")
        } else {
            print("❌ CloudSyncService: Failed to decode Base64 image data for pin \(photo.id)")
            // Create placeholder image for photos without images
            place.imageData = createPinPlaceholderImageData()
            print("🔧 CloudSyncService: Set placeholder image data: \(place.imageData?.count ?? 0) bytes")
        }
        
        // Don't refresh the object as virtual - let it be used normally for display
        // Note: This object won't be saved to Core Data since it's only used for display
        
        return place
    }
    
    /**
     * Create placeholder image for pins without actual images
     */
    private func createPinPlaceholderImageData() -> Data? {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Create a pin-themed placeholder
            UIColor.systemGreen.withAlphaComponent(0.2).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add pin icon
            let iconSize: CGFloat = 80
            let iconRect = CGRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            
            UIColor.systemGreen.setFill()
            let iconPath = UIBezierPath(ovalIn: iconRect)
            iconPath.fill()
            
            // Add pin text
            let text = "📍"
            let font = UIFont.systemFont(ofSize: 40)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        return image.jpegData(compressionQuality: 0.8)
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
