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
        print("🔍 Quick List ID: \(quickList.id ?? "nil"), User ID: \(userId)")
        
        // Get all list items for this list
        let fetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "listId == %@", quickList.id ?? "")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "addedAt", ascending: false)]
        
        do {
            let listItems = try context.fetch(fetchRequest)
            print("🔍 Found \(listItems.count) list items in Quick List")
            
            // Debug: Print all listItem details
            for (index, listItem) in listItems.enumerated() {
                print("🔍 ListItem \(index + 1): id=\(listItem.id ?? "nil"), listId=\(listItem.listId ?? "nil"), placeId=\(listItem.placeId ?? "nil"), addedAt=\(listItem.addedAt)")
            }
            
            var result: [any RListViewItem] = []
            
            for (index, listItem) in listItems.enumerated() {
                print("🔍 Processing item \(index + 1): placeId = \(listItem.placeId ?? "nil")")
                
                // All items are stored as Places - some may represent photos from library
                if let placeId = listItem.placeId,
                   let place = getPlaceFromId(placeId, context: context) {
                    
                    print("🔍 Found place for item \(index + 1): url = \(place.url ?? "nil")")
                    
                    // Check if this place represents a photo from library (has special marker in URL)
                    if let url = place.url, url.hasPrefix("photo://") {
                        // Extract the photo identifier and try to get the asset
                        let photoId = String(url.dropFirst(8)) // Remove "photo://" prefix
                        print("🔍 Extracting photo ID: \(photoId)")
                        
                        if let asset = getAssetFromId(photoId) {
                            print("🔍 Found asset for photo ID: \(photoId)")
                            result.append(RListPhotoItem(asset: asset))
                        } else {
                            print("🔍 Asset not found for photo ID: \(photoId), showing as pin")
                            // Photo no longer exists, but show as pin anyway
                            result.append(RListPinItem(place: place))
                        }
                    } else {
                        print("🔍 Regular pin item")
                        // Regular pin
                        result.append(RListPinItem(place: place))
                    }
                } else {
                    print("🔍 ❌ Could not find place for item \(index + 1) - place lookup failed")
                }
            }
            
            print("🔍 Final result: \(result.count) items")
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
        //print("🔍 Checking if asset \(asset.localIdentifier) is in list \(list.id ?? "nil")")
        
        // First find places with this URL
        let placeFetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
        placeFetchRequest.predicate = NSPredicate(format: "url == %@", photoURL)
        
        do {
            let places = try context.fetch(placeFetchRequest)
            //print("🔍 Found \(places.count) places with URL: \(photoURL)")
            
            if places.count > 1 {
                print("🔍 ⚠️ WARNING: Multiple places found for same photo URL!")
            }
            
            guard let place = places.first else { 
                //print("🔍 No place found for URL: \(photoURL)")
                return false 
            }
            
            // Check if this place is in the list
            let placeId = place.objectID.uriRepresentation().absoluteString
            let listItemFetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
            listItemFetchRequest.predicate = NSPredicate(format: "listId == %@ AND placeId == %@", 
                                                       list.id ?? "", placeId)
            
            let count = try context.count(for: listItemFetchRequest)
            print("🔍 Found \(count) list items for place \(placeId)")
            return count > 0
        } catch {
            print("❌ Failed to check if asset is in list: \(error)")
            return false
        }
    }
    
    private func addAssetToList(_ asset: PHAsset, list: UserList, context: NSManagedObjectContext) -> Bool {
        print("🔍 Adding asset \(asset.localIdentifier) to list \(list.id ?? "nil")")
        
        // Check if already exists
        if isAssetInList(asset, list: list, context: context) {
            print("🔍 Asset already in list")
            return true // Already in list
        }
        
        // Create a Place entity to represent this photo
        let place = createPlaceFromAsset(asset, context: context)
        print("🔍 Created place with URL: \(place.url ?? "nil")")
        
        // Add the place to the list
        let listItem = ListItem(context: context)
        listItem.id = UUID().uuidString
        listItem.listId = list.id ?? ""
        listItem.placeId = place.objectID.uriRepresentation().absoluteString
        listItem.addedAt = Date()
        
        print("🔍 Created list item with ID: \(listItem.id ?? "nil"), listId: \(listItem.listId ?? "nil"), placeId: \(listItem.placeId ?? "nil")")
        
        do {
            try context.save()
            print("🔍 ✅ Successfully saved asset to list")
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
                print("🔍 Reusing existing place for asset \(asset.localIdentifier)")
                return existingPlace
            }
        } catch {
            print("❌ Failed to check for existing place: \(error)")
        }
        
        print("🔍 Creating new place for asset \(asset.localIdentifier)")
        
        // Create new place
        let place = Place(context: context)
        place.dateAdded = asset.creationDate ?? Date()
        place.url = photoURL // Special marker to indicate this is a photo from library
        place.post = "Photo from library"
        place.isPrivate = false  // Default to public
        
        // Store location if available
        if let location = asset.location {
            if let locationData = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false) {
                place.setValue(locationData, forKey: "coordinates")
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
        do {
            if let url = URL(string: placeId),
               let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) {
                let place = try context.existingObject(with: objectID) as? Place
                if place != nil {
                    print("🔍 Successfully found place via objectID for: \(placeId)")
                } else {
                    print("🔍 ❌ Found objectID but could not cast to Place for: \(placeId)")
                }
                return place
            } else {
                print("🔍 ❌ Could not create objectID from URI: \(placeId)")
            }
        } catch {
            print("🔍 ❌ Error getting place from ID \(placeId): \(error)")
        }
        
        return nil
    }
    
    private func getAssetFromId(_ photoId: String) -> PHAsset? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photoId], options: nil)
        return fetchResult.firstObject
    }
    
    // MARK: - Quick List Management Actions
    
    /// Creates a new list with the given name and moves all Quick List items to it
    func createListFromQuickList(newListName: String, context: NSManagedObjectContext, userId: String) async -> Bool {
        print("🔍 Creating new list '\(newListName)' from Quick List")
        
        do {
            // Create the new list
            let newList = UserList(context: context)
            newList.id = UUID().uuidString
            newList.name = newListName
            newList.createdAt = Date()
            newList.userId = userId
            
            // Get Quick List
            let quickList = getOrCreateQuickList(in: context, userId: userId)
            
            // Move all items from Quick List to new list
            let fetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "listId == %@", quickList.id ?? "")
            
            let quickListItems = try context.fetch(fetchRequest)
            print("🔍 Moving \(quickListItems.count) items to new list")
            
            for item in quickListItems {
                item.listId = newList.id ?? ""
            }
            
            try context.save()
            print("🔍 ✅ Successfully created list '\(newListName)' with \(quickListItems.count) items")
            
            // Send notification to refresh the AllRListsView
            NotificationCenter.default.post(name: NSNotification.Name("UserListsChanged"), object: nil)
            
            return true
        } catch {
            print("❌ Failed to create list from Quick List: \(error)")
            return false
        }
    }
    
    /// Moves all Quick List items to an existing list
    func moveQuickListToExistingList(targetListId: String, context: NSManagedObjectContext, userId: String) async -> Bool {
        print("🔍 Moving Quick List items to existing list: \(targetListId)")
        
        do {
            // Get Quick List
            let quickList = getOrCreateQuickList(in: context, userId: userId)
            
            // Get all Quick List items
            let fetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "listId == %@", quickList.id ?? "")
            
            let quickListItems = try context.fetch(fetchRequest)
            print("🔍 Moving \(quickListItems.count) items to target list")
            
            for item in quickListItems {
                item.listId = targetListId
            }
            
            try context.save()
            print("🔍 ✅ Successfully moved \(quickListItems.count) items to existing list")
            
            // Send notification to refresh the AllRListsView
            NotificationCenter.default.post(name: NSNotification.Name("UserListsChanged"), object: nil)
            
            return true
        } catch {
            print("❌ Failed to move Quick List to existing list: \(error)")
            return false
        }
    }
    
    /// Clears all items from the Quick List
    func clearQuickList(context: NSManagedObjectContext, userId: String) async -> Bool {
        print("🔍 Clearing Quick List")
        
        do {
            // Get Quick List
            let quickList = getOrCreateQuickList(in: context, userId: userId)
            
            // Get all Quick List items
            let fetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "listId == %@", quickList.id ?? "")
            
            let quickListItems = try context.fetch(fetchRequest)
            print("🔍 Deleting \(quickListItems.count) items from Quick List")
            
            for item in quickListItems {
                context.delete(item)
            }
            
            try context.save()
            print("🔍 ✅ Successfully cleared \(quickListItems.count) items from Quick List")
            
            // Send notification to refresh the AllRListsView
            NotificationCenter.default.post(name: NSNotification.Name("UserListsChanged"), object: nil)
            
            return true
        } catch {
            print("❌ Failed to clear Quick List: \(error)")
            return false
        }
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
        onPhotoStackTap: @escaping ([PHAsset]) -> Void,
        onLocationTap: ((LocationInfo) -> Void)? = nil
    ) -> some View {
        QuickListView(
            context: context,
            userId: userId,
            onPhotoTap: onPhotoTap,
            onPinTap: onPinTap,
            onPhotoStackTap: onPhotoStackTap,
            onLocationTap: onLocationTap
        )
    }
}


