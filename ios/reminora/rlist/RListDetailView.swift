import CoreData
import CoreLocation
import SwiftUI
import Photos

// shows list of places saved into list
struct RListDetailView: View {
    let list: UserList
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode

    @FetchRequest private var listItems: FetchedResults<ListItem>
    @FetchRequest private var places: FetchedResults<Place>

    init(list: UserList) {
        self.list = list

        // Fetch items for this list
        self._listItems = FetchRequest<ListItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \ListItem.addedAt, ascending: false)],
            predicate: NSPredicate(format: "listId == %@", list.id ?? ""),
            animation: .default
        )

        // Fetch all places to match with list items
        self._places = FetchRequest<Place>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Place.dateAdded, ascending: false)],
            animation: .default
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom navigation header
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                        Text("Back")
                            .font(.body)
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(list.name ?? "Untitled List")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    // Handle menu action
                    print("Menu tapped")
                }) {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .rotationEffect(.degrees(90))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            Divider()
            
            // RList content - always use mixed content approach
            if isQuickList {
                // Use QuickListService for Quick List to get mixed content
                QuickListView(
                    context: viewContext,
                    userId: getCurrentUserId(),
                    onPhotoTap: { asset in
                        // Handle photo tap - could show photo detail or photo stack
                        print("📷 Photo tapped: \(asset.localIdentifier)")
                    },
                    onPinTap: { place in
                        // Handle pin tap - could show pin detail
                        print("📍 Pin tapped: \(place.post ?? "Unknown")")
                    },
                    onPhotoStackTap: { assets in
                        // Handle photo stack tap - could show stack viewer
                        print("📚 Photo stack tapped: \(assets.count) photos")
                    }
                )
            } else if isSharedList {
                // Use SharedListService for Shared List to get shared content
                SharedListView(
                    context: viewContext,
                    userId: getCurrentUserId(),
                    onPhotoTap: { asset in
                        print("📷 Photo tapped: \(asset.localIdentifier)")
                    },
                    onPinTap: { place in
                        print("📍 Pin tapped: \(place.post ?? "Unknown")")
                    },
                    onPhotoStackTap: { assets in
                        print("📚 Photo stack tapped: \(assets.count) photos")
                    }
                )
            } else {
                // Use RListView for regular lists with mixed content
                RListView(
                    dataSource: .mixed(createMixedContent()),
                    onPhotoTap: { asset in
                        print("📷 Photo tapped: \(asset.localIdentifier)")
                    },
                    onPinTap: { place in
                        print("📍 Pin tapped: \(place.post ?? "Unknown")")
                    },
                    onPhotoStackTap: { assets in
                        print("📚 Photo stack tapped: \(assets.count) photos")
                    }
                )
            }
        }
        .navigationBarHidden(true)
    }
    
    private func createMixedContent() -> [any RListViewItem] {
        let placesInList = listItems.compactMap { placeForItem($0) }
        var mixedItems: [any RListViewItem] = []
        
        for place in placesInList {
            // Check if this place represents a photo from library (has special marker in URL)
            if let url = place.url, url.hasPrefix("photo://") {
                // Extract the photo identifier and try to get the asset
                let photoId = String(url.dropFirst(8)) // Remove "photo://" prefix
                if let asset = getAssetFromId(photoId) {
                    mixedItems.append(RListPhotoItem(asset: asset))
                } else {
                    // Photo no longer exists, but show as pin anyway
                    mixedItems.append(RListPinItem(place: place))
                }
            } else {
                // Regular pin
                mixedItems.append(RListPinItem(place: place))
            }
        }
        
        return mixedItems
    }
    
    private func getAssetFromId(_ photoId: String) -> PHAsset? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photoId], options: nil)
        return fetchResult.firstObject
    }
    
    private var isQuickList: Bool {
        return list.name == "Quick"
    }
    
    private var isSharedList: Bool {
        return list.name == "Shared"
    }
    
    private func getCurrentUserId() -> String {
        // Get the current user ID from AuthenticationService
        return AuthenticationService.shared.currentAccount?.id ?? ""
    }

    private func placeForItem(_ item: ListItem) -> Place? {
        // Find place by matching the object ID stored in placeId
        return places.first { place in
            place.objectID.uriRepresentation().absoluteString == item.placeId
        }
    }

    private func iconForList(_ name: String) -> String {
        switch name {
        case "Shared":
            return "shared.with.you"
        case "Quick":
            return "bolt.fill"
        default:
            return "list.bullet"
        }
    }

    private func colorForList(_ name: String) -> Color {
        switch name {
        case "Shared":
            return .green
        case "Quick":
            return .orange
        default:
            return .blue
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let sampleList = UserList(context: context)
    sampleList.id = "sample"
    sampleList.name = "Quick"
    sampleList.createdAt = Date()
    sampleList.userId = "user1"

    return RListDetailView(list: sampleList)
        .environment(\.managedObjectContext, context)
}
