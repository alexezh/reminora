import CoreData
import CoreLocation
import SwiftUI
import Photos
import MapKit

// shows list of places saved into list
struct RListDetailView: View {
    let list: RListData
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode

    @FetchRequest private var listItems: FetchedResults<RListItemData>
    @FetchRequest private var places: FetchedResults<PinData>
    
    // Quick List menu states
    @State private var showingMenu = false
    @State private var showingCreateList = false
    @State private var showingAddToList = false
    @State private var showingClearConfirmation = false
    @State private var newListName = ""
    @State private var selectedListId: String?
    
    // View presentation states
    @State private var selectedPin: PinData? = nil

    init(list: RListData) {
        self.list = list

        // Fetch items for this list
        self._listItems = FetchRequest<RListItemData>(
            sortDescriptors: [NSSortDescriptor(keyPath: \RListItemData.addedAt, ascending: false)],
            predicate: NSPredicate(format: "listId == %@", list.id ?? ""),
            animation: .default
        )

        // Fetch all places to match with list items
        self._places = FetchRequest<PinData>(
            sortDescriptors: [NSSortDescriptor(keyPath: \PinData.dateAdded, ascending: false)],
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            Divider()
            
            // RList content - always use mixed content approach
            if isQuickList {
                // Use RListService for Quick List to get mixed content
                QuickListView(
                    context: viewContext,
                    onPhotoStackTap: { photoStack in
                        // Navigate to SwipePhotoView using NavigationStack
                        let tempCollection = RPhotoStackCollection(stacks: [photoStack])
                        ActionRouter.shared.openPhotoView(collection: tempCollection, photo: photoStack)
                    },
                    onPinTap: { place in
                        // Show PinDetailView for pin
                        selectedPin = place
                    },
                    onLocationTap: { location in
                        // Open location in native map
                        openLocationInMap(location)
                    }
                )
            } else if isSharedList {
                // Use RListService for Shared List to get shared content
                SharedListView(
                    context: viewContext,
                    userId: getCurrentUserId(),
                    onPhotoStackTap: { photoStack in
                        // Navigate to SwipePhotoView using NavigationStack
                        let tempCollection = RPhotoStackCollection(stacks: [photoStack])
                        ActionRouter.shared.openPhotoView(collection: tempCollection, photo: photoStack)
                    },
                    onPinTap: { place in
                        // Show PinDetailView for pin
                        selectedPin = place
                    },
                    onLocationTap: { location in
                        // Open location in native map
                        openLocationInMap(location)
                    }
                )
            } else {
                // Use RListView for regular lists with mixed content
                RListView(
                    dataSource: .mixed(createMixedContent()),
                    onPhotoStackTap: { photoStack in
                        // Navigate to SwipePhotoView using NavigationStack
                        let tempCollection = RPhotoStackCollection(stacks: [photoStack])
                        ActionRouter.shared.openPhotoView(collection: tempCollection, photo: photoStack)
                    },
                    onPinTap: { place in
                        // Show PinDetailView for pin
                        selectedPin = place
                    },
                    onLocationTap: { location in
                        // Open location in native map
                        openLocationInMap(location)
                    },
                    onDeleteItem: { item in
                        // Handle delete - remove from list
                        deleteItemFromList(item)
                    }
                )
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Set ActionSheet context based on list type
            if isQuickList {
                UniversalActionSheetModel.shared.setContext(.quickList)
            } else {
                UniversalActionSheetModel.shared.setContext(.lists)
            }
        }
        .onDisappear {
            // Reset to lists context when leaving
            UniversalActionSheetModel.shared.setContext(.lists)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EmptyQuickList"))) { _ in
            if isQuickList {
                showingClearConfirmation = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CreateListFromQuickList"))) { _ in
            if isQuickList {
                showingCreateList = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AddQuickListToExistingList"))) { _ in
            if isQuickList {
                showingAddToList = true
            }
        }
        .alert("Create New List", isPresented: $showingCreateList) {
            TextField("List name", text: $newListName)
            Button("Create") {
                createNewList()
            }
            .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {
                newListName = ""
            }
        } message: {
            Text("Enter a name for the new list. All items from Quick List will be moved to this list.")
        }
        .alert("Clear Quick List", isPresented: $showingClearConfirmation) {
            Button("Clear", role: .destructive) {
                clearQuickList()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to clear all items from Quick List? This action cannot be undone.")
        }
        .sheet(isPresented: $showingAddToList) {
            AddToListPickerView(
                context: viewContext,
                userId: getCurrentUserId(),
                onListSelected: { listId in
                    selectedListId = listId
                    addToExistingList()
                },
                onDismiss: {
                    showingAddToList = false
                }
            )
        }
        // Present PinDetailView when a pin is selected
        .overlay {
            if let selectedPin = selectedPin {
                PinDetailView(
                    place: selectedPin,
                    allPlaces: getAllPlaces(),
                    onBack: {
                        self.selectedPin = nil
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.1).combined(with: .opacity),
                    removal: .scale(scale: 0.1).combined(with: .opacity)
                ))
            }
        }
    }
    
    // MARK: - Quick List Actions
    
    private func createNewList() {
        let trimmedName = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        Task {
            let success = await RListService.shared.createListFromQuickList(
                newListName: trimmedName,
                context: viewContext,
                userId: getCurrentUserId()
            )
            
            await MainActor.run {
                if success {
                    newListName = ""
                    
                    // Show success feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    // Navigate back to the lists view since Quick List is now empty
                    presentationMode.wrappedValue.dismiss()
                } else {
                    // Handle error - could show an alert
                    print("❌ Failed to create new list")
                }
            }
        }
    }
    
    private func addToExistingList() {
        guard let listId = selectedListId else { return }
        
        Task {
            let success = await RListService.shared.moveQuickListToExistingList(
                targetListId: listId,
                context: viewContext,
                userId: getCurrentUserId()
            )
            
            await MainActor.run {
                if success {
                    selectedListId = nil
                    showingAddToList = false
                    
                    // Show success feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    // Navigate back to the lists view since Quick List is now empty
                    presentationMode.wrappedValue.dismiss()
                } else {
                    // Handle error
                    print("❌ Failed to add to existing list")
                    showingAddToList = false
                }
            }
        }
    }
    
    private func clearQuickList() {
        Task {
            let success = await RListService.shared.clearQuickList(
                context: viewContext,
                userId: getCurrentUserId()
            )
            
            await MainActor.run {
                if success {
                    // Show success feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    // Navigate back to the lists view since Quick List is now empty
                    presentationMode.wrappedValue.dismiss()
                } else {
                    // Handle error
                    print("❌ Failed to clear Quick List")
                }
            }
        }
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
                    mixedItems.append(RListPhotoStackItem(photoStack: RPhotoStack(asset: asset)))
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

    private func placeForItem(_ item: RListItemData) -> PinData? {
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
    
    private func deleteItemFromList(_ item: any RListViewItem) {
        
        // Find the corresponding RListItemData to delete
        let itemToDelete = listItems.first { listItem in
            switch item.itemType {
            case .pin(let pinData):
                return listItem.placeId == pinData.objectID.uriRepresentation().absoluteString
            case .photoStack(let photoStack):
                return photoStack.assets.allSatisfy { asset in
                    listItem.placeId?.contains(asset.localIdentifier) == true
                }
            case .location(_):
                // Location items are not stored in Core Data lists yet
                return false
            case .header(_):
                // Headers cannot be deleted
                return false
            }
        }
        
        if let itemToDelete = itemToDelete {
            viewContext.delete(itemToDelete)
            
            do {
                try viewContext.save()
                print("✅ Successfully deleted item from list '\(list.name ?? "Unknown")'")
            } catch {
                print("❌ Failed to delete item from list: \(error)")
            }
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
    
    private func getAllPlaces() -> [PinData] {
        // Return all places for PinDetailView context
        // This could be optimized to return only nearby places
        return Array(places)
    }
    
    private func openLocationInMap(_ location: LocationInfo) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        mapItem.name = location.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let sampleList = RListData(context: context)
    sampleList.id = "sample"
    sampleList.name = "Quick"
    sampleList.createdAt = Date()

    return RListDetailView(list: sampleList)
        .environment(\.managedObjectContext, context)
}
