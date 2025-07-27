import Foundation
import CoreData
import Photos
import SwiftUI
import CoreLocation

// MARK: - Shared List Service
class SharedListService: ObservableObject {
    static let shared = SharedListService()
    
    private init() {}
    
    // Default Shared List name
    static let sharedListName = "Shared"
    
    // MARK: - Shared List Management
    
    /// Gets or creates the Shared List for the current user
    func getOrCreateSharedList(in context: NSManagedObjectContext, userId: String) -> RListData {
        // Validate userId is not empty
        guard !userId.isEmpty else {
            print("❌ Cannot create SharedList with empty userId")
            fatalError("SharedList requires valid userId")
        }
        
        let fetchRequest: NSFetchRequest<RListData> = RListData.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@ AND userId == %@", Self.sharedListName, userId)
        
        do {
            let existingLists = try context.fetch(fetchRequest)
            if let sharedList = existingLists.first {
                return sharedList
            } else {
                // Create new Shared List
                print("🗂️ Creating new Shared List for userId: \(userId)")
                let sharedList = RListData(context: context)
                sharedList.id = UUID().uuidString
                sharedList.name = Self.sharedListName
                sharedList.createdAt = Date()
                sharedList.userId = userId
                
                try context.save()
                return sharedList
            }
        } catch {
            print("❌ Failed to get/create Shared List: \(error)")
            // Return a temporary one if database fails - but don't insert it into context
            print("🗂️ Creating temporary Shared List for userId: \(userId)")
            let tempList = RListData(context: context)
            tempList.id = UUID().uuidString
            tempList.name = Self.sharedListName
            tempList.createdAt = Date()
            tempList.userId = userId
            
            // Don't save the context here - let the caller decide
            return tempList
        }
    }
    
    // MARK: - Shared Items Management
    
    /// Adds a pin to the shared list
    func addToSharedList(place: Place, userId: String? = nil) async {
        guard let context = place.managedObjectContext else {
            print("❌ No managed object context for place")
            return
        }
        
        let currentUserId = userId ?? AuthenticationService.shared.currentAccount?.id ?? ""
        guard !currentUserId.isEmpty else {
            print("⚠️ No user ID available for shared list - skipping shared list addition")
            return
        }
        
        await MainActor.run {
            // Get or create the shared list
            let sharedList = getOrCreateSharedList(in: context, userId: currentUserId)
            
            // Check if this place is already in the shared list
            let fetchRequest: NSFetchRequest<RListItemData> = RListItemData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "listId == %@ AND placeId == %@",
                                               sharedList.id ?? "", 
                                               place.objectID.uriRepresentation().absoluteString)
            
            do {
                let existingItems = try context.fetch(fetchRequest)
                if existingItems.isEmpty {
                    // Add the pin to the shared list
                    let listItem = RListItemData(context: context)
                    listItem.id = UUID().uuidString
                    listItem.placeId = place.objectID.uriRepresentation().absoluteString
                    listItem.addedAt = Date()
                    listItem.listId = sharedList.id ?? ""
                    listItem.sharedByUserId = currentUserId
                    listItem.sharedByUserName = AuthenticationService.shared.currentAccount?.display_name
                    
                    try context.save()
                    print("✅ Added shared pin to shared list")
                } else {
                    print("📌 Pin already exists in shared list")
                }
            } catch {
                print("❌ Failed to add pin to shared list: \(error)")
            }
        }
    }
    
    /// Gets all items shared with the current user
    func getSharedItems(context: NSManagedObjectContext, userId: String) async -> [any RListViewItem] {
        // For now, return items in the Shared list
        // In a real implementation, this would fetch items from a sharing service
        // or items marked as shared with this user
        
        let sharedList = getOrCreateSharedList(in: context, userId: userId)
        
        // Get all list items for the shared list
        let fetchRequest: NSFetchRequest<RListItemData> = RListItemData.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "listId == %@", sharedList.id ?? "")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "addedAt", ascending: false)]
        
        do {
            let listItems = try context.fetch(fetchRequest)
            var result: [any RListViewItem] = []
            
            for listItem in listItems {
                if let placeId = listItem.placeId,
                   let place = getPlaceFromId(placeId, context: context) {
                    
                    // Check if this place represents a photo from library (has special marker in URL)
                    if let url = place.url, url.hasPrefix("photo://") {
                        // Extract the photo identifier and try to get the asset
                        let photoId = String(url.dropFirst(8)) // Remove "photo://" prefix
                        if let asset = getAssetFromId(photoId) {
                            result.append(RListPhotoItem(asset: asset))
                        } else {
                            // Photo no longer exists, but show as pin anyway
                            result.append(RListPinItem(place: place))
                        }
                    } else if let url = place.url, url.hasPrefix("location://") {
                        // This is a shared location, convert to LocationInfo
                        if let locationInfo = convertPlaceToLocationInfo(place) {
                            result.append(RListLocationItem(location: locationInfo))
                        } else {
                            // Fallback to showing as pin if conversion fails
                            result.append(RListPinItem(place: place))
                        }
                    } else {
                        // Regular pin
                        result.append(RListPinItem(place: place))
                    }
                }
            }
            
            return result
        } catch {
            print("❌ Failed to fetch Shared List items: \(error)")
            return []
        }
    }
    
    // MARK: - Helper Methods
    
    private func getPlaceFromId(_ placeId: String, context: NSManagedObjectContext) -> Place? {
        // Try to find the place using Core Data URI
        if let url = URL(string: placeId),
           let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) {
            return try? context.existingObject(with: objectID) as? Place
        }
        return nil
    }
    
    private func getAssetFromId(_ photoId: String) -> PHAsset? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photoId], options: nil)
        return fetchResult.firstObject
    }
    
    private func convertPlaceToLocationInfo(_ place: Place) -> LocationInfo? {
        guard let url = place.url,
              url.hasPrefix("location://"),
              let placeName = place.post else {
            return nil
        }
        
        // Extract location data
        let urlComponents = url.dropFirst("location://".count)
        let parts = urlComponents.components(separatedBy: "|")
        
        guard let locationId = parts.first else { return nil }
        
        // Get location address and distance from URL if available
        var address = "Unknown address"
        var distance: Double = 0
        
        if parts.count > 1 {
            let infoString = parts[1]
            let infoLines = infoString.components(separatedBy: "\n")
            
            if infoLines.count >= 2 {
                address = infoLines[0]
                let distanceLine = infoLines[1]
                
                // Extract distance from "Distance: X.X km" format
                if let distanceMatch = distanceLine.range(of: #"Distance: ([\d.]+) km"#, options: .regularExpression) {
                    let distanceString = String(distanceLine[distanceMatch]).replacingOccurrences(of: "Distance: ", with: "").replacingOccurrences(of: " km", with: "")
                    distance = Double(distanceString) ?? 0
                    distance *= 1000 // Convert km to meters
                }
            }
        }
        
        // Get location coordinates from Core Data
        var coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        if let locationData = place.value(forKey: "coordinates") as? Data,
           let clLocation = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation {
            coordinate = clLocation.coordinate
        }
        
        return LocationInfo(
            id: locationId,
            name: placeName,
            address: address,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            category: "shared location",
            phoneNumber: nil,
            distance: distance,
            url: nil
        )
    }
}

// MARK: - Shared List View Helper
extension SharedListService {
    /// Creates an RListView configured for the Shared List
    static func createSharedListView(
        context: NSManagedObjectContext,
        userId: String,
        onPhotoTap: @escaping (PHAsset) -> Void,
        onPinTap: @escaping (Place) -> Void,
        onPhotoStackTap: @escaping ([PHAsset]) -> Void,
        onLocationTap: ((LocationInfo) -> Void)? = nil
    ) -> some View {
        SharedListView(
            context: context,
            userId: userId,
            onPhotoTap: onPhotoTap,
            onPinTap: onPinTap,
            onPhotoStackTap: onPhotoStackTap,
            onLocationTap: onLocationTap
        )
    }
}


