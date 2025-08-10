import CoreData
import CoreLocation
import Foundation
import Photos
import SwiftUI

// MARK: - Unified RList Service
class RListService: ObservableObject {
    static let shared = RListService()

    private init() {}

    // Default list names
    static let sharedListName = "Shared"
    static let quickListName = "Quick"

    // MARK: - List Management

    /// Gets or creates the Shared List for the current user
    func getOrCreateSharedList(in context: NSManagedObjectContext, userId: String) -> RListData {
        // Validate userId is not empty
        guard !userId.isEmpty else {
            print("❌ Cannot create SharedList with empty userId")
            fatalError("SharedList requires valid userId")
        }

        let fetchRequest: NSFetchRequest<RListData> = RListData.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "name == %@ AND userId == %@", Self.sharedListName, userId)

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

    /// Gets or creates the Quick List for the current user
    func getOrCreateQuickList(in context: NSManagedObjectContext, userId: String) -> RListData {
        let fetchRequest: NSFetchRequest<RListData> = RListData.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "name == %@ AND userId == %@", Self.quickListName, userId)

        do {
            let existingLists = try context.fetch(fetchRequest)
            if let quickList = existingLists.first {
                return quickList
            } else {
                // Create new Quick List
                let quickList = RListData(context: context)
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
            let tempList = RListData(context: context)
            tempList.id = UUID().uuidString
            tempList.name = Self.quickListName
            tempList.createdAt = Date()
            tempList.userId = userId
            return tempList
        }
    }

    // MARK: - Shared List Management

    /// Adds a pin to the shared list
    func addToSharedList(place: PinData, userId: String? = nil) async {
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
            fetchRequest.predicate = NSPredicate(
                format: "listId == %@ AND placeId == %@",
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
    func getSharedItems(context: NSManagedObjectContext, userId: String) async
        -> [any RListViewItem]
    {
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
                    let place = getPinDataFromId(placeId, context: context)
                {

                    // Check if this place represents a photo from library (has special marker in URL)
                    if let url = place.url, url.hasPrefix("photo://") {
                        // Extract the photo identifier and try to get the asset
                        let photoId = String(url.dropFirst(8))  // Remove "photo://" prefix
                        if let asset = getAssetFromId(photoId) {
                            result.append(
                                RListPhotoStackItem(photoStack: RPhotoStack(asset: asset)))
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

    // MARK: - Quick List Photo Management

    /// Checks if a photo is in the Quick List
    func isPhotoInQuickList(_ asset: PHAsset, context: NSManagedObjectContext, userId: String)
        -> Bool
    {
        let quickList = getOrCreateQuickList(in: context, userId: userId)
        return isAssetInList(asset, list: quickList, context: context)
    }

    /// Adds a photo to the Quick List by creating a Place entity
    func addPhotoToQuickList(_ asset: PHAsset, context: NSManagedObjectContext, userId: String)
        -> Bool
    {
        let quickList = getOrCreateQuickList(in: context, userId: userId)
        return addAssetToList(asset, list: quickList, context: context)
    }

    /// Removes a photo from the Quick List
    func removePhotoFromQuickList(_ asset: PHAsset, context: NSManagedObjectContext, userId: String)
        -> Bool
    {
        let quickList = getOrCreateQuickList(in: context, userId: userId)
        return removeAssetFromList(asset, list: quickList, context: context)
    }

    /// Toggles a photo in the Quick List
    func togglePhotoInQuickList(_ asset: PHAsset, context: NSManagedObjectContext, userId: String)
        -> Bool
    {
        if isPhotoInQuickList(asset, context: context, userId: userId) {
            return removePhotoFromQuickList(asset, context: context, userId: userId)
        } else {
            return addPhotoToQuickList(asset, context: context, userId: userId)
        }
    }

    // MARK: - Quick List Pin Management

    /// Checks if a pin is in the Quick List
    func isPinInQuickList(_ place: PinData, context: NSManagedObjectContext, userId: String) -> Bool
    {
        let quickList = getOrCreateQuickList(in: context, userId: userId)
        return isPlaceInList(place, list: quickList, context: context)
    }

    /// Adds a pin to the Quick List
    func addPinToQuickList(_ place: PinData, context: NSManagedObjectContext, userId: String)
        -> Bool
    {
        let quickList = getOrCreateQuickList(in: context, userId: userId)
        return addPlaceToList(place, list: quickList, context: context)
    }

    /// Removes a pin from the Quick List
    func removePinFromQuickList(_ place: PinData, context: NSManagedObjectContext, userId: String)
        -> Bool
    {
        let quickList = getOrCreateQuickList(in: context, userId: userId)
        return removePlaceFromList(place, list: quickList, context: context)
    }

    /// Toggles a pin in the Quick List
    func togglePinInQuickList(_ place: PinData, context: NSManagedObjectContext, userId: String)
        -> Bool
    {
        if isPinInQuickList(place, context: context, userId: userId) {
            return removePinFromQuickList(place, context: context, userId: userId)
        } else {
            return addPinToQuickList(place, context: context, userId: userId)
        }
    }

    // MARK: - Quick List Content

    /// Gets all items in the Quick List as RListViewItems
    func getQuickListItems(context: NSManagedObjectContext, userId: String) async
        -> [any RListViewItem]
    {
        let quickList = getOrCreateQuickList(in: context, userId: userId)
        print("🔍 Quick List ID: \(quickList.id ?? "nil"), User ID: \(userId)")

        // Get all list items for this list
        let fetchRequest: NSFetchRequest<RListItemData> = RListItemData.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "listId == %@", quickList.id ?? "")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "addedAt", ascending: false)]

        do {
            let listItems = try context.fetch(fetchRequest)
            print("🔍 Found \(listItems.count) list items in Quick List")

            // Debug: Print all listItem details
            for (index, listItem) in listItems.enumerated() {
                print(
                    "🔍 ListItem \(index + 1): id=\(listItem.id ?? "nil"), listId=\(listItem.listId ?? "nil"), placeId=\(listItem.placeId ?? "nil"), addedAt=\(listItem.addedAt)"
                )
            }

            var result: [any RListViewItem] = []

            for (index, listItem) in listItems.enumerated() {
                print("🔍 Processing item \(index + 1): placeId = \(listItem.placeId ?? "nil")")

                guard let placeId = listItem.placeId else {
                    print("🔍 ❌ No placeId for item \(index + 1)")
                    continue
                }

                // Check if this is a direct photo identifier
                if placeId.hasPrefix("photo://") {
                    // Direct photo reference - extract the photo identifier and get the asset
                    let photoId = String(placeId.dropFirst(8))  // Remove "photo://" prefix
                    print("🔍 Direct photo reference - extracting photo ID: \(photoId)")
                    if let asset = getAssetFromId(photoId) {
                        print("🔍 Found asset for photo ID: \(photoId)")
                        result.append(RListPhotoStackItem(photoStack: RPhotoStack(asset: asset)))
                    } else {
                        print("🔍 ❌ Asset not found for photo ID: \(photoId) - removing from list")
                        // Photo no longer exists, clean up the orphaned list item
                        context.delete(listItem)
                    }
                } else {
                    // Core Data object reference - try to get the PinData object
                    if let place = getPinDataFromId(placeId, context: context) {
                        print("🔍 Found place for item \(index + 1): url = \(place.url ?? "nil")")
                        result.append(RListPinItem(place: place))
                    } else {
                        print(
                            "🔍 ❌ Could not find place for item \(index + 1) - removing orphaned list item"
                        )
                        // Place no longer exists, clean up the orphaned list item
                        context.delete(listItem)
                    }
                }
            }

            // Save context if we cleaned up any orphaned items
            do {
                try context.save()
            } catch {
                print("❌ Failed to save context after cleanup: \(error)")
            }

            print("🔍 Final result: \(result.count) items")
            return result
        } catch {
            print("❌ Failed to fetch Quick List items: \(error)")
            return []
        }
    }

    // MARK: - Quick List Management Actions

    /// Creates a new list with the given name and moves all Quick List items to it
    func createListFromQuickList(
        newListName: String, context: NSManagedObjectContext, userId: String
    ) async -> Bool {
        print("🔍 Creating new list '\(newListName)' from Quick List")

        do {
            // Create the new list
            let newList = RListData(context: context)
            newList.id = UUID().uuidString
            newList.name = newListName
            newList.createdAt = Date()
            newList.userId = userId

            // Get Quick List
            let quickList = getOrCreateQuickList(in: context, userId: userId)

            // Move all items from Quick List to new list
            let fetchRequest: NSFetchRequest<RListItemData> = RListItemData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "listId == %@", quickList.id ?? "")

            let quickListItems = try context.fetch(fetchRequest)
            print("🔍 Moving \(quickListItems.count) items to new list")

            for item in quickListItems {
                item.listId = newList.id ?? ""
            }

            try context.save()
            print(
                "🔍 ✅ Successfully created list '\(newListName)' with \(quickListItems.count) items")

            // Send notification to refresh the AllRListsView
            NotificationCenter.default.post(
                name: NSNotification.Name("RListDatasChanged"), object: nil)

            return true
        } catch {
            print("❌ Failed to create list from Quick List: \(error)")
            return false
        }
    }

    /// Moves all Quick List items to an existing list
    func moveQuickListToExistingList(
        targetListId: String, context: NSManagedObjectContext, userId: String
    ) async -> Bool {
        print("🔍 Moving Quick List items to existing list: \(targetListId)")

        do {
            // Get Quick List
            let quickList = getOrCreateQuickList(in: context, userId: userId)

            // Get all Quick List items
            let fetchRequest: NSFetchRequest<RListItemData> = RListItemData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "listId == %@", quickList.id ?? "")

            let quickListItems = try context.fetch(fetchRequest)
            print("🔍 Moving \(quickListItems.count) items to target list")

            for item in quickListItems {
                item.listId = targetListId
            }

            try context.save()
            print("🔍 ✅ Successfully moved \(quickListItems.count) items to existing list")

            // Send notification to refresh the AllRListsView
            NotificationCenter.default.post(
                name: NSNotification.Name("RListDatasChanged"), object: nil)

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
            let fetchRequest: NSFetchRequest<RListItemData> = RListItemData.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "listId == %@", quickList.id ?? "")

            let quickListItems = try context.fetch(fetchRequest)
            print("🔍 Deleting \(quickListItems.count) items from Quick List")

            for item in quickListItems {
                context.delete(item)
            }

            try context.save()
            print("🔍 ✅ Successfully cleared \(quickListItems.count) items from Quick List")

            // Send notification to refresh the AllRListsView
            NotificationCenter.default.post(
                name: NSNotification.Name("RListDatasChanged"), object: nil)

            return true
        } catch {
            print("❌ Failed to clear Quick List: \(error)")
            return false
        }
    }

    // MARK: - Private Helper Methods

    private func isAssetInList(_ asset: PHAsset, list: RListData, context: NSManagedObjectContext)
        -> Bool
    {
        // Look directly for the photo identifier in list items
        let photoIdentifier = "photo://\(asset.localIdentifier)"

        let listItemFetchRequest: NSFetchRequest<RListItemData> = RListItemData.fetchRequest()
        listItemFetchRequest.predicate = NSPredicate(
            format: "listId == %@ AND placeId == %@",
            list.id ?? "", photoIdentifier)

        do {
            let count = try context.count(for: listItemFetchRequest)
            return count > 0
        } catch {
            print("❌ Failed to check if asset is in list: \(error)")
            return false
        }
    }

    private func addAssetToList(_ asset: PHAsset, list: RListData, context: NSManagedObjectContext)
        -> Bool
    {
        print("🔍 Adding asset \(asset.localIdentifier) to list \(list.id ?? "nil")")

        // Check if already exists
        if isAssetInList(asset, list: list, context: context) {
            print("🔍 Asset already in list")
            return true  // Already in list
        }

        // Store photo directly using its localIdentifier (no PinData needed)
        let photoIdentifier = "photo://\(asset.localIdentifier)"
        print("🔍 Storing photo directly with identifier: \(photoIdentifier)")

        // Add the photo to the list
        let listItem = RListItemData(context: context)
        listItem.id = UUID().uuidString
        listItem.listId = list.id ?? ""
        listItem.placeId = photoIdentifier  // Store photo ID directly, not Core Data objectID
        listItem.addedAt = Date()

        print(
            "🔍 Created list item with ID: \(listItem.id ?? "nil"), listId: \(listItem.listId ?? "nil"), placeId: \(listItem.placeId ?? "nil")"
        )

        do {
            try context.save()
            print("🔍 ✅ Successfully saved asset to list")

            // Send notification to update UI
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("RListDatasChanged"), object: nil)
            }

            return true
        } catch {
            print("❌ Failed to add asset to list: \(error)")
            return false
        }
    }

    private func removeAssetFromList(
        _ asset: PHAsset, list: RListData, context: NSManagedObjectContext
    ) -> Bool {
        let photoIdentifier = "photo://\(asset.localIdentifier)"

        // Remove from list by finding the list item with the photo identifier
        let listItemFetchRequest: NSFetchRequest<RListItemData> = RListItemData.fetchRequest()
        listItemFetchRequest.predicate = NSPredicate(
            format: "listId == %@ AND placeId == %@",
            list.id ?? "", photoIdentifier)

        do {
            let items = try context.fetch(listItemFetchRequest)
            for item in items {
                context.delete(item)
            }

            try context.save()

            // Send notification to update UI
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("RListDatasChanged"), object: nil)
            }

            return true
        } catch {
            print("❌ Failed to remove asset from list: \(error)")
            return false
        }
    }

    private func createPinDataFromAsset(_ asset: PHAsset, context: NSManagedObjectContext)
        -> PinData
    {
        // Check if place already exists for this photo
        let photoURL = "photo://\(asset.localIdentifier)"
        let fetchRequest: NSFetchRequest<PinData> = PinData.fetchRequest()
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
        let place = PinData(context: context)
        place.dateAdded = asset.creationDate ?? Date()
        place.url = photoURL  // Special marker to indicate this is a photo from library
        place.post = "Photo from library"
        place.isPrivate = false  // Default to public

        // Store location if available
        if let location = asset.location {
            if let locationData = try? NSKeyedArchiver.archivedData(
                withRootObject: location, requiringSecureCoding: false)
            {
                place.coordinates = locationData
            }
        }

        // Asynchronously load and store image data
        loadImageDataForPlace(place, from: asset)

        return place
    }

    private func loadImageDataForPlace(_ place: PinData, from asset: PHAsset) {
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
                let imageData = image.jpegData(compressionQuality: 0.8)
            else {
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

    private func isPlaceInList(_ place: PinData, list: RListData, context: NSManagedObjectContext)
        -> Bool
    {
        let placeId = place.objectID.uriRepresentation().absoluteString
        let fetchRequest: NSFetchRequest<RListItemData> = RListItemData.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "listId == %@ AND placeId == %@",
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

    private func addPlaceToList(_ place: PinData, list: RListData, context: NSManagedObjectContext)
        -> Bool
    {
        // Check if already exists
        if isPlaceInList(place, list: list, context: context) {
            return true  // Already in list
        }

        let listItem = RListItemData(context: context)
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

    private func removePlaceFromList(
        _ place: PinData, list: RListData, context: NSManagedObjectContext
    ) -> Bool {
        let placeId = place.objectID.uriRepresentation().absoluteString
        let fetchRequest: NSFetchRequest<RListItemData> = RListItemData.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "listId == %@ AND placeId == %@",
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

    private func getPinDataFromId(_ placeId: String, context: NSManagedObjectContext) -> PinData? {
        // Try to find the place using Core Data URI
        do {
            if let url = URL(string: placeId),
                let objectID = context.persistentStoreCoordinator?.managedObjectID(
                    forURIRepresentation: url)
            {
                let place = try context.existingObject(with: objectID) as? PinData
                if place != nil {
                    print("🔍 Successfully found place via objectID for: \(placeId)")
                } else {
                    print("🔍 ❌ Found objectID but could not cast to PinData for: \(placeId)")
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

    private func convertPlaceToLocationInfo(_ place: PinData) -> LocationInfo? {
        guard let url = place.url,
            url.hasPrefix("location://"),
            let placeName = place.post
        else {
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
                if let distanceMatch = distanceLine.range(
                    of: #"Distance: ([\d.]+) km"#, options: .regularExpression)
                {
                    let distanceString = String(distanceLine[distanceMatch]).replacingOccurrences(
                        of: "Distance: ", with: ""
                    ).replacingOccurrences(of: " km", with: "")
                    distance = Double(distanceString) ?? 0
                    distance *= 1000  // Convert km to meters
                }
            }
        }

        // Get location coordinates from Core Data
        var coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        if let locationData = place.coordinates,
            let clLocation = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData)
                as? CLLocation
        {
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

// MARK: - View Helper Extensions
extension RListService {
    /// Creates an RListView configured for the Shared List
    static func createSharedListView(
        context: NSManagedObjectContext,
        userId: String,
        onPhotoStackTap: @escaping (RPhotoStack) -> Void,
        onPinTap: @escaping (PinData) -> Void,
        onLocationTap: ((LocationInfo) -> Void)? = nil
    ) -> some View {
        SharedListView(
            context: context,
            userId: userId,
            onPhotoStackTap: onPhotoStackTap,
            onPinTap: onPinTap,
            onLocationTap: onLocationTap
        )
    }

    /// Creates an RListView configured for the Quick List
    static func createQuickListView(
        context: NSManagedObjectContext,
        userId: String,
        onPhotoStackTap: @escaping (RPhotoStack) -> Void,
        onPinTap: @escaping (PinData) -> Void,
        onLocationTap: ((LocationInfo) -> Void)? = nil
    ) -> some View {
        QuickListView(
            context: context,
            userId: userId,
            onPhotoStackTap: onPhotoStackTap,
            onPinTap: onPinTap,
            onLocationTap: onLocationTap
        )
    }
}
