import CoreData
import CoreLocation
import MapKit
import Photos
import PhotosUI
import SwiftUI
import UIKit

struct PhotoMainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.toolbarManager) private var toolbarManager
    @Environment(\.selectedAssetService) private var selectedAssetService
    @Environment(\.sheetStack) private var sheetStack
    @ObservedObject private var photoLibraryService = PhotoLibraryService.shared
    @State private var currentFilter: PhotoFilterType = .notDisliked
    @State private var isCoreDataReady = false
    @State private var showingQuickList = false
    @State private var showingSearch = false
    @State private var searchText = ""
    @State private var startDate: Date?
    @State private var endDate: Date?

    // Selection mode state
    @State private var isSelectionMode = false

    // Track stacking state to reduce repetitive logging
    @State private var lastEmbeddingCount = -1
    @State private var hasStacksBeenCleared = false
    @State private var hasTriggeredEmbeddingComputation = false

    private var preferenceManager: PhotoPreferenceManager {
        PhotoPreferenceManager(viewContext: viewContext)
    }


    // Time interval for grouping photos into stacks (in minutes)
    private let stackingInterval: TimeInterval = 10 * 60  // 10 minutes

    // MARK: - UI Components
    
    private var topButtonsView: some View {
        HStack {
            Spacer()

            // Search button
            Button(action: {
                sheetStack.push(.searchDialog)
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding(.trailing, 8)

            // Select/Cancel button
            Button(action: {
                toggleSelectionMode()
            }) {
                Text(isSelectionMode ? "Cancel" : "Select")
                    .font(.body)
                    .foregroundColor(.blue)
            }
            .padding(.trailing, 8)
        }
        .padding(.top, 8)
    }
    
    private var selectionStatusView: some View {
        Group {
            if isSelectionMode {
                HStack {
                    Text(
                        selectedAssetService.selectedPhotoCount == 0
                            ? "Select photos"
                            : "\(selectedAssetService.selectedPhotoCount) selected"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Initializing...")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Photos Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Unable to load photos. Try refreshing.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Refresh") {
                print("Manual refresh triggered")
                photoLibraryService.loadPhotoLibrary()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var noAccessView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Photo Access Required")
                .font(.title2)
                .fontWeight(.semibold)

            if photoLibraryService.authorizationStatus == .denied || photoLibraryService.authorizationStatus == .restricted {
                Text("Photo access was denied. Please go to Settings > Privacy & Security > Photos to allow access for Reminora.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Open Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            } else {
                Text("Please allow access to your photo library to see your photos")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Grant Access") {
                    photoLibraryService.requestPhotoAccess()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private var mainContentView: some View {
        Group {
            if !isCoreDataReady || photoLibraryService.isLoading {
                loadingView
            } else if photoLibraryService.authorizationStatus == .authorized || photoLibraryService.authorizationStatus == .limited {
                if photoLibraryService.photoStackCollection.isEmpty && photoLibraryService.hasLoaded {
                    emptyStateView
                } else {
                    photoListView
                }
            } else {
                noAccessView
            }
        }
    }
    
    private var photoListView: some View {
        RListView(
            dataSource: .photoLibrary(photoLibraryService.photoStackCollection),
            isSelectionMode: isSelectionMode,
            onPhotoStackTap: { photoStack in
                if isSelectionMode {
                    // Select all photos in the stack
                    if !selectedAssetService.isPhotoSelected(photoStack) {
                        selectedAssetService.addSelectedPhoto(photoStack)
                    }
                    updateToolbar()
                } else {
                    // Navigate to SwipePhotoView using NavigationStack
                    ActionRouter.shared.openPhotoView(collection: photoLibraryService.photoStackCollection, photo: photoStack)
                }
            },
            onPinTap: { _ in
                // Not used in photo library view
            },
            onLocationTap: { _ in
                // Not used in photo library view
            }
        )
    }
    
    var body: some View {
        VStack {
            // Top buttons: Search and Select/Cancel
            topButtonsView
            
            // Selection status
            selectionStatusView

            mainContentView
        }
        .padding(.bottom, LayoutConstants.totalToolbarHeight)
        .onAppear {
            initializeCoreData()
            setupToolbar()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RestoreToolbar")))
        { _ in
            // Restore PhotoMainView specific toolbar when returning from SwipePhotoView
            print("🔧 PhotoMainView: Restoring toolbar after SwipePhotoView dismissal")
            setupToolbar()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshPhotoFilter"))) { _ in
            // Refresh filter to remove disliked photos from view after SwipePhotoView dismissal
            print("🔄 PhotoMainView: Refreshing photo filter via PhotoLibraryService")
            photoLibraryService.refreshWithCurrentFilter()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("FindDuplicatePhotos"))
        ) { _ in
            print("📷 Finding duplicate photos across entire library")
            // Use first available photo as target for duplicate detection
            let allAssets = photoLibraryService.photoStackCollection.getAllPhotoAssets()
            if let firstAsset = allAssets.first {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToDuplicatePhotos"), object: firstAsset)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("ApplySearchFilter"))
        ) { notification in
            if let filterData = notification.object as? [String: Any] {
                // Handle search filter application
                print("🔍 Applying search filter: \(filterData)")
                // You can implement the actual filter logic here
            }
        }
        .onChange(of: isCoreDataReady) { _, isReady in
            if isReady {
                print("Core Data became ready, initializing PhotoLibraryService")
                photoLibraryService.initialize(
                    with: viewContext,
                    preferenceManager: preferenceManager,
                    initialFilter: currentFilter
                )
                photoLibraryService.requestPhotoAccess()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }


    private func initializeCoreData() {
        // Check if Core Data is ready
        if viewContext.persistentStoreCoordinator != nil {
            print("Core Data is ready")
            isCoreDataReady = true
            // The onChange observer will handle loading photos
        } else {
            print("Waiting for Core Data to be ready...")
            // Wait for Core Data to be ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                initializeCoreData()
            }
        }
    }


    private func applySearchFilter() {
        var filteredAssets = photoLibraryService.photoStackCollection.getAllPhotoAssets()

        // Apply date range filter
        if let startDate = startDate, let endDate = endDate {
            filteredAssets = filteredAssets.filter { asset in
                guard let creationDate = asset.creationDate else { return false }
                return creationDate >= startDate && creationDate <= endDate
            }
        } else if let startDate = startDate {
            filteredAssets = filteredAssets.filter { asset in
                guard let creationDate = asset.creationDate else { return false }
                return creationDate >= startDate
            }
        } else if let endDate = endDate {
            filteredAssets = filteredAssets.filter { asset in
                guard let creationDate = asset.creationDate else { return false }
                return creationDate <= endDate
            }
        }

        // Apply search text filter (placeholder - would need metadata indexing for real search)
        if !searchText.isEmpty {
            // For now, just filter by date if search text is provided
            // In a real app, you'd search through photo metadata, location data, etc.
            print("Search text: '\(searchText)' - would implement metadata search here")
        }

        // Apply preferences filter
        let preferenceFilteredAssets = preferenceManager.getFilteredAssets(
            from: filteredAssets, filter: currentFilter)

        // Create photo stacks for empty state check
        createPhotoStacks(from: preferenceFilteredAssets)
    }

    private func applyFilter() {
        guard isCoreDataReady else {
            print("Core Data not ready, skipping filter")
            return
        }
        
        if photoLibraryService.hasLoaded {
            print("📷 PhotoMainView: Applying filter \(currentFilter.displayName) via PhotoLibraryService")
            photoLibraryService.setFilter(currentFilter)
        } else {
            print("📷 PhotoMainView: Collection not loaded yet, will apply filter on load")
        }
    }

    private func createPhotoStacks(from assets: [PHAsset]) {
        print("📷 PhotoMainView: Creating photo stacks from \(assets.count) assets using RPhotoStackCollection")
        
        // For search filter results, create temporary stacks
        Task {
            // Create a wrapper struct to handle the inout parameters
            var embeddingCount = lastEmbeddingCount
            var stacksCleared = hasStacksBeenCleared
            var triggeredComputation = hasTriggeredEmbeddingComputation
            
            let stacks = await PhotoEmbeddingService.shared.createPhotoStacks(
                from: assets, 
                in: viewContext, 
                preferenceManager: preferenceManager,
                lastEmbeddingCount: &embeddingCount,
                hasStacksBeenCleared: &stacksCleared,
                hasTriggeredEmbeddingComputation: &triggeredComputation
            )
            
            await MainActor.run {
                // Update the state variables
                self.lastEmbeddingCount = embeddingCount
                self.hasStacksBeenCleared = stacksCleared
                self.hasTriggeredEmbeddingComputation = triggeredComputation
                
                // Set stacks directly for search results (bypassing the collection's filter logic)
                self.photoLibraryService.photoStackCollection.setStacks(stacks)
                print("📷 PhotoMainView: Created \(stacks.count) photo stacks for search results")
            }
        }
    }


    // MARK: - Selection Mode

    private func toggleSelectionMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSelectionMode.toggle()
            if !isSelectionMode {
                selectedAssetService.clearSelectedPhotos()
            }
            updateToolbar()
        }
    }

    private func toggleAssetSelection(_ stack: RPhotoStack) {
        if selectedAssetService.isPhotoSelected(stack) {
            selectedAssetService.removeSelectedPhoto(stack)
        } else {
            selectedAssetService.addSelectedPhoto(stack)
        }
    }

    // MARK: - Batch Actions

    private func favoriteSelectedPhotos() {
        PHPhotoLibrary.shared().performChanges({
            for asset in SelectionService.shared.selectedPhotos {
                let request = PHAssetChangeRequest(for: asset.primaryAsset)
                request.isFavorite = true
            }
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully favorited \(SelectionService.shared.selectedPhotos.count) photos")
                } else {
                    print(
                        "❌ Failed to favorite photos: \(error?.localizedDescription ?? "Unknown error")"
                    )
                }
                // Exit selection mode after action
                self.isSelectionMode = false
                self.selectedAssetService.clearSelectedPhotos()
                self.updateToolbar()
            }
        }
    }

    private func archiveSelectedPhotos() {
        // Update preferences to mark as archived
        for asset in selectedAssetService.selectedPhotos {
            preferenceManager.setPreference(for: asset.primaryAsset, preference: .archive)
        }

        // Exit selection mode and refresh
        isSelectionMode = false
        selectedAssetService.clearSelectedPhotos()
        updateToolbar()
        applyFilter()  // Refresh to remove archived photos if current filter excludes them
    }

    private func addSelectedToQuickList() {
//        var successCount = 0
//        for photoStack in selectedAssetService.selectedPhotos {
//            if RListService.shared.togglePhotoInQuickList(
//                photoStack, context: viewContext)
//            {
//                successCount += 1
//            }
//        }
//
//        print("✅ Added \(successCount) photos to Quick List")
//
//        // Exit selection mode after action
//        isSelectionMode = false
//        selectedAssetService.clearSelectedPhotos()
//        updateToolbar()
    }

    // MARK: - Toolbar Setup

    private func setupToolbar() {
        updateToolbar()
    }

    private func updateToolbar() {
        let hasSelection = selectedAssetService.selectedPhotoCount > 0

        // Always show these buttons, but enable/disable based on selection mode and selection count
        let photoButtons = [
            ToolbarButtonConfig(
                id: "favorite",
                title: "Favorite",
                systemImage: "heart",
                action: { self.favoriteSelectedPhotos() },
                isEnabled: isSelectionMode && hasSelection,
                color: (isSelectionMode && hasSelection) ? .red : .gray
            ),
            ToolbarButtonConfig(
                id: "archive",
                title: "Archive",
                systemImage: "archivebox",
                action: { self.archiveSelectedPhotos() },
                isEnabled: isSelectionMode && hasSelection,
                color: (isSelectionMode && hasSelection) ? .orange : .gray
            ),
            ToolbarButtonConfig(
                id: "quick",
                title: "Quick List",
                systemImage: "list.bullet.rectangle",
                action: { self.addSelectedToQuickList() },
                isEnabled: isSelectionMode && hasSelection,
                color: (isSelectionMode && hasSelection) ? .blue : .gray
            ),
        ]

        toolbarManager.setCustomToolbar(buttons: photoButtons)
    }
}

struct PhotoShareData: Identifiable {
    let id = UUID()
    let message: String
    let link: String
}

// Helper functions for SwipePhotoView
extension SwipePhotoView {
    private func formatLocation(_ location: CLLocation) -> String {
        let _ = CLGeocoder()  // Reserved for future reverse geocoding
        // For now, just show coordinates. In real app, you'd reverse geocode
        return String(
            format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct PhotoMainView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoMainView()
    }
}
