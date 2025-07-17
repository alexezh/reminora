import Foundation
import CoreData
import Photos
import SwiftUI

// MARK: - Shared List Service
class SharedListService: ObservableObject {
    static let shared = SharedListService()
    
    private init() {}
    
    // Default Shared List name
    static let sharedListName = "Shared"
    
    // MARK: - Shared List Management
    
    /// Gets or creates the Shared List for the current user
    func getOrCreateSharedList(in context: NSManagedObjectContext, userId: String) -> UserList {
        let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@ AND userId == %@", Self.sharedListName, userId)
        
        do {
            let existingLists = try context.fetch(fetchRequest)
            if let sharedList = existingLists.first {
                return sharedList
            } else {
                // Create new Shared List
                let sharedList = UserList(context: context)
                sharedList.id = UUID().uuidString
                sharedList.name = Self.sharedListName
                sharedList.createdAt = Date()
                sharedList.userId = userId
                
                try context.save()
                return sharedList
            }
        } catch {
            print("❌ Failed to get/create Shared List: \(error)")
            // Return a temporary one if database fails
            let tempList = UserList(context: context)
            tempList.id = UUID().uuidString
            tempList.name = Self.sharedListName
            tempList.createdAt = Date()
            tempList.userId = userId
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
            print("❌ No user ID available for shared list")
            return
        }
        
        await MainActor.run {
            // Get or create the shared list
            let sharedList = getOrCreateSharedList(in: context, userId: currentUserId)
            
            // Check if this place is already in the shared list
            let fetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "listId == %@ AND placeId == %@", 
                                               sharedList.id ?? "", 
                                               place.objectID.uriRepresentation().absoluteString)
            
            do {
                let existingItems = try context.fetch(fetchRequest)
                if existingItems.isEmpty {
                    // Add the pin to the shared list
                    let listItem = ListItem(context: context)
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
        let fetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
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
}

// MARK: - Shared List View Helper
extension SharedListService {
    /// Creates an RListView configured for the Shared List
    static func createSharedListView(
        context: NSManagedObjectContext,
        userId: String,
        onPhotoTap: @escaping (PHAsset) -> Void,
        onPinTap: @escaping (Place) -> Void,
        onPhotoStackTap: @escaping ([PHAsset]) -> Void
    ) -> some View {
        SharedListView(
            context: context,
            userId: userId,
            onPhotoTap: onPhotoTap,
            onPinTap: onPinTap,
            onPhotoStackTap: onPhotoStackTap
        )
    }
}

// MARK: - Shared List View
struct SharedListView: View {
    let context: NSManagedObjectContext
    let userId: String
    let onPhotoTap: (PHAsset) -> Void
    let onPinTap: (Place) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    
    @State private var items: [any RListViewItem] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "shared.with.you")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Shared Items")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Items shared with you will appear here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    RListView(
                        dataSource: .mixed(items),
                        onPhotoTap: onPhotoTap,
                        onPinTap: onPinTap,
                        onPhotoStackTap: onPhotoStackTap
                    )
                }
            }
            .navigationTitle("Shared")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadItems()
        }
    }
    
    private func loadItems() async {
        isLoading = true
        let loadedItems = await SharedListService.shared.getSharedItems(context: context, userId: userId)
        print("🔍 SharedListView loaded \(loadedItems.count) items")
        await MainActor.run {
            self.items = loadedItems
            self.isLoading = false
        }
    }
}