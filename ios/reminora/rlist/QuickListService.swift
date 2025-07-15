import Foundation
import CoreData
import Photos
import SwiftUI

// MARK: - Quick List Service
class QuickListService: ObservableObject {
    static let shared = QuickListService()
    
    private init() {}
    
    // Default Quick List name
    static let quickListName = "Quick"
    
    // MARK: - Quick List Management
    
    /// Gets or creates the Quick List for the current user
    func getOrCreateQuickList(in context: NSManagedObjectContext, userId: String) -> UserList {
        let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@ AND userId == %@", Self.quickListName, userId)
        
        do {
            let existingLists = try context.fetch(fetchRequest)
            if let quickList = existingLists.first {
                return quickList
            } else {
                // Create new Quick List
                let quickList = UserList(context: context)
                quickList.id = UUID().uuidString
                quickList.name = Self.quickListName
                quickList.createdAt = Date()
                quickList.userId = userId
                
                try context.save()
                return quickList
            }
        } catch {
            print("❌ Failed to get/create Quick List: \(error)")
            // Return a temporary one if database fails
            let tempList = UserList(context: context)
            tempList.id = UUID().uuidString
            tempList.name = Self.quickListName
            tempList.createdAt = Date()
            tempList.userId = userId
            return tempList
        }
    }
    
    // MARK: - Photo Management
    
    /// Checks if a photo is in the Quick List
    func isPhotoInQuickList(_ asset: PHAsset, context: NSManagedObjectContext, userId: String) -> Bool {
        let quickList = getOrCreateQuickList(in: context, userId: userId)
        return isAssetInList(asset, list: quickList, context: context)
    }
    
    /// Adds a photo to the Quick List by creating a Place entity
    func addPhotoToQuickList(_ asset: PHAsset, context: NSManagedObjectContext, userId: String) -> Bool {
        let quickList = getOrCreateQuickList(in: context, userId: userId)
        return addAssetToList(asset, list: quickList, context: context)
    }
    
    /// Removes a photo from the Quick List
    func removePhotoFromQuickList(_ asset: PHAsset, context: NSManagedObjectContext, userId: String) -> Bool {
        let quickList = getOrCreateQuickList(in: context, userId: userId)
        return removeAssetFromList(asset, list: quickList, context: context)
    }
    
    /// Toggles a photo in the Quick List
    func togglePhotoInQuickList(_ asset: PHAsset, context: NSManagedObjectContext, userId: String) -> Bool {
        if isPhotoInQuickList(asset, context: context, userId: userId) {
            return removePhotoFromQuickList(asset, context: context, userId: userId)
        } else {
            return addPhotoToQuickList(asset, context: context, userId: userId)
        }
    }
    
    // MARK: - Pin Management
    
    /// Checks if a pin is in the Quick List
    func isPinInQuickList(_ place: Place, context: NSManagedObjectContext, userId: String) -> Bool {
        let quickList = getOrCreateQuickList(in: context, userId: userId)
        return isPlaceInList(place, list: quickList, context: context)
    }
    
    /// Adds a pin to the Quick List
    func addPinToQuickList(_ place: Place, context: NSManagedObjectContext, userId: String) -> Bool {
        let quickList = getOrCreateQuickList(in: context, userId: userId)
        return addPlaceToList(place, list: quickList, context: context)
    }
    
    /// Removes a pin from the Quick List
    func removePinFromQuickList(_ place: Place, context: NSManagedObjectContext, userId: String) -> Bool {
        let quickList = getOrCreateQuickList(in: context, userId: userId)
        return removePlaceFromList(place, list: quickList, context: context)
    }
    
    /// Toggles a pin in the Quick List
    func togglePinInQuickList(_ place: Place, context: NSManagedObjectContext, userId: String) -> Bool {
        if isPinInQuickList(place, context: context, userId: userId) {
            return removePinFromQuickList(place, context: context, userId: userId)
        } else {
            return addPinToQuickList(place, context: context, userId: userId)
        }
    }
    
    // MARK: - Quick List Content
    
    /// Gets all items in the Quick List as RListViewItems
    func getQuickListItems(context: NSManagedObjectContext, userId: String) async -> [any RListViewItem] {
        let quickList = getOrCreateQuickList(in: context, userId: userId)
        
        // Get all list items for this list
        let fetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "listId == %@", quickList.id ?? "")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "addedAt", ascending: false)]
        
        do {
            let listItems = try context.fetch(fetchRequest)
            var result: [any RListViewItem] = []
            
            for listItem in listItems {
                // All items are stored as Places - some may represent photos from library
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
                    } else {
                        // Regular pin
                        result.append(RListPinItem(place: place))
                    }
                }
            }
            
            return result
        } catch {
            print("❌ Failed to fetch Quick List items: \(error)")
            return []
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func isAssetInList(_ asset: PHAsset, list: UserList, context: NSManagedObjectContext) -> Bool {
        // Look for a place with URL pattern "photo://localIdentifier"
        let photoURL = "photo://\(asset.localIdentifier)"
        
        // First find places with this URL
        let placeFetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
        placeFetchRequest.predicate = NSPredicate(format: "url == %@", photoURL)
        placeFetchRequest.fetchLimit = 1
        
        do {
            let places = try context.fetch(placeFetchRequest)
            guard let place = places.first else { return false }
            
            // Check if this place is in the list
            let placeId = place.objectID.uriRepresentation().absoluteString
            let listItemFetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
            listItemFetchRequest.predicate = NSPredicate(format: "listId == %@ AND placeId == %@", 
                                                       list.id ?? "", placeId)
            listItemFetchRequest.fetchLimit = 1
            
            let count = try context.count(for: listItemFetchRequest)
            return count > 0
        } catch {
            print("❌ Failed to check if asset is in list: \(error)")
            return false
        }
    }
    
    private func addAssetToList(_ asset: PHAsset, list: UserList, context: NSManagedObjectContext) -> Bool {
        // Check if already exists
        if isAssetInList(asset, list: list, context: context) {
            return true // Already in list
        }
        
        // Create a Place entity to represent this photo
        let place = createPlaceFromAsset(asset, context: context)
        
        // Add the place to the list
        let listItem = ListItem(context: context)
        listItem.id = UUID().uuidString
        listItem.listId = list.id ?? ""
        listItem.placeId = place.objectID.uriRepresentation().absoluteString
        listItem.addedAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("❌ Failed to add asset to list: \(error)")
            return false
        }
    }
    
    private func removeAssetFromList(_ asset: PHAsset, list: UserList, context: NSManagedObjectContext) -> Bool {
        let photoURL = "photo://\(asset.localIdentifier)"
        
        // Find the place representing this photo
        let placeFetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
        placeFetchRequest.predicate = NSPredicate(format: "url == %@", photoURL)
        placeFetchRequest.fetchLimit = 1
        
        do {
            let places = try context.fetch(placeFetchRequest)
            guard let place = places.first else { return false }
            
            let placeId = place.objectID.uriRepresentation().absoluteString
            
            // Remove from list
            let listItemFetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
            listItemFetchRequest.predicate = NSPredicate(format: "listId == %@ AND placeId == %@", 
                                                       list.id ?? "", placeId)
            
            let items = try context.fetch(listItemFetchRequest)
            for item in items {
                context.delete(item)
            }
            
            // Optionally delete the place if it's not in any other lists
            // For now, we'll keep it to preserve the data
            
            try context.save()
            return true
        } catch {
            print("❌ Failed to remove asset from list: \(error)")
            return false
        }
    }
    
    private func createPlaceFromAsset(_ asset: PHAsset, context: NSManagedObjectContext) -> Place {
        // Check if place already exists for this photo
        let photoURL = "photo://\(asset.localIdentifier)"
        let fetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "url == %@", photoURL)
        fetchRequest.fetchLimit = 1
        
        do {
            let existingPlaces = try context.fetch(fetchRequest)
            if let existingPlace = existingPlaces.first {
                return existingPlace
            }
        } catch {
            print("❌ Failed to check for existing place: \(error)")
        }
        
        // Create new place
        let place = Place(context: context)
        place.dateAdded = asset.creationDate ?? Date()
        place.url = photoURL // Special marker to indicate this is a photo from library
        place.post = "Photo from library"
        
        // Store location if available
        if let location = asset.location {
            if let locationData = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false) {
                place.setValue(locationData, forKey: "location")
            }
        }
        
        // Asynchronously load and store image data
        loadImageDataForPlace(place, from: asset)
        
        return place
    }
    
    private func loadImageDataForPlace(_ place: Place, from asset: PHAsset) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 1024, height: 1024),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            guard let image = image,
                  let imageData = image.jpegData(compressionQuality: 0.8) else {
                return
            }
            
            DispatchQueue.main.async {
                place.imageData = imageData
                // Save the context if needed
                do {
                    try place.managedObjectContext?.save()
                } catch {
                    print("❌ Failed to save image data for place: \(error)")
                }
            }
        }
    }
    
    private func isPlaceInList(_ place: Place, list: UserList, context: NSManagedObjectContext) -> Bool {
        let placeId = place.objectID.uriRepresentation().absoluteString
        let fetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "listId == %@ AND placeId == %@", 
                                           list.id ?? "", placeId)
        fetchRequest.fetchLimit = 1
        
        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            print("❌ Failed to check if place is in list: \(error)")
            return false
        }
    }
    
    private func addPlaceToList(_ place: Place, list: UserList, context: NSManagedObjectContext) -> Bool {
        // Check if already exists
        if isPlaceInList(place, list: list, context: context) {
            return true // Already in list
        }
        
        let listItem = ListItem(context: context)
        listItem.id = UUID().uuidString
        listItem.listId = list.id ?? ""
        listItem.placeId = place.objectID.uriRepresentation().absoluteString
        listItem.addedAt = Date()
        
        do {
            try context.save()
            return true
        } catch {
            print("❌ Failed to add place to list: \(error)")
            return false
        }
    }
    
    private func removePlaceFromList(_ place: Place, list: UserList, context: NSManagedObjectContext) -> Bool {
        let placeId = place.objectID.uriRepresentation().absoluteString
        let fetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "listId == %@ AND placeId == %@", 
                                           list.id ?? "", placeId)
        
        do {
            let items = try context.fetch(fetchRequest)
            for item in items {
                context.delete(item)
            }
            try context.save()
            return true
        } catch {
            print("❌ Failed to remove place from list: \(error)")
            return false
        }
    }
    
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
}

// MARK: - Quick List View Helper
extension QuickListService {
    /// Creates an RListView configured for the Quick List
    static func createQuickListView(
        context: NSManagedObjectContext,
        userId: String,
        onPhotoTap: @escaping (PHAsset) -> Void,
        onPinTap: @escaping (Place) -> Void,
        onPhotoStackTap: @escaping ([PHAsset]) -> Void
    ) -> some View {
        QuickListView(
            context: context,
            userId: userId,
            onPhotoTap: onPhotoTap,
            onPinTap: onPinTap,
            onPhotoStackTap: onPhotoStackTap
        )
    }
}


