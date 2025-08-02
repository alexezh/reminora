import SwiftUI
import Photos
import PhotosUI
import UIKit
import CoreData
import MapKit
import CoreLocation

struct PhotoMainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.toolbarManager) private var toolbarManager
    @Binding var isSwipePhotoViewOpen: Bool
    @State private var photoAssets: [PHAsset] = []
    @State private var filteredPhotoStacks: [PhotoStack] = []
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var selectedStack: PhotoStack?
    @State private var selectedStackIndex = 0
    @State private var currentFilter: PhotoFilterType = .notDisliked
    @State private var isCoreDataReady = false
    @State private var hasTriedInitialLoad = false
    @State private var showingQuickList = false
    @State private var showingSearch = false
    @State private var searchText = ""
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var allPhotoAssets: [PHAsset] = [] // Store all photos before filtering
    
    // Selection mode state
    @State private var isSelectionMode = false
    @State private var selectedAssets: Set<String> = [] // Using asset localIdentifiers
    
    // Track stacking state to reduce repetitive logging
    @State private var lastEmbeddingCount = -1
    @State private var hasStacksBeenCleared = false
    @State private var hasTriggeredEmbeddingComputation = false
    
    private var preferenceManager: PhotoPreferenceManager {
        PhotoPreferenceManager(viewContext: viewContext)
    }
    
    private var searchDialogView: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Search text field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Search Photos")
                        .font(.headline)
                    TextField("Enter search terms...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Date range picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date Range")
                        .font(.headline)
                    
                    DatePicker("Start Date", selection: Binding(
                        get: { startDate ?? Date.distantPast },
                        set: { startDate = $0 }
                    ), displayedComponents: .date)
                    .onChange(of: startDate) { _, _ in
                        if startDate == Date.distantPast {
                            startDate = nil
                        }
                    }
                    
                    DatePicker("End Date", selection: Binding(
                        get: { endDate ?? Date() },
                        set: { endDate = $0 }
                    ), displayedComponents: .date)
                    .onChange(of: endDate) { _, _ in
                        if endDate == Date() {
                            endDate = nil
                        }
                    }
                    
                    Button("Clear Dates") {
                        startDate = nil
                        endDate = nil
                    }
                    .foregroundColor(.blue)
                }
                
                // Filter buttons (moved from main view)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Filters")
                        .font(.headline)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach([PhotoFilterType.notDisliked, .favorites, .dislikes, .all], id: \.self) { filter in
                            Button(action: {
                                currentFilter = filter
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: filter.iconName)
                                    Text(filter.displayName)
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    currentFilter == filter
                                        ? Color.blue
                                        : Color.gray.opacity(0.2)
                                )
                                .foregroundColor(
                                    currentFilter == filter
                                        ? .white
                                        : .primary
                                )
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Search Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingSearch = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applySearchFilter()
                        showingSearch = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var quickListView: some View {
        RListService.createQuickListView(
            context: viewContext,
            userId: AuthenticationService.shared.currentAccount?.id ?? "",
            onPhotoTap: { asset in
                // Create a stack with just this photo and show it
                let stack = PhotoStack(assets: [asset])
                selectedStackIndex = 0
                showingQuickList = false
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedStack = stack
                    isSwipePhotoViewOpen = true
                }
            },
            onPinTap: { place in
                // Handle pin tap - you might want to show pin detail
                showingQuickList = false
                print("📍 Pin tapped: \(place.post ?? "Unknown")")
            },
            onPhotoStackTap: { assets in
                // Create a stack and show it
                let stack = PhotoStack(assets: assets)
                selectedStackIndex = 0
                showingQuickList = false
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedStack = stack
                    isSwipePhotoViewOpen = true
                }
            }
        )
    }
    
    // Time interval for grouping photos into stacks (in minutes)
    private let stackingInterval: TimeInterval = 10 * 60 // 10 minutes
    
    var body: some View {
        VStack {
            // Top buttons: Search and Select/Cancel
            HStack {
                Spacer()
                
                // Search button
                Button(action: {
                    showingSearch = true
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
                .padding(.trailing, 16)
            }
            .padding(.top, 8)
            
            // Selection status
            if isSelectionMode {
                HStack {
                    Text(selectedAssets.isEmpty ? "Select photos" : "\(selectedAssets.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
            
            if !isCoreDataReady {
                // Show loading UI while Core Data is initializing
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Initializing...")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if authorizationStatus == .authorized || authorizationStatus == .limited {
                
                if filteredPhotoStacks.isEmpty && isCoreDataReady {
                    // Show empty state with retry option
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
                            hasTriedInitialLoad = false
                            loadPhotoAssets()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Use RListView to display photos with date separators
                    RListView(
                        dataSource: .photoLibrary(photoAssets),
                        isSelectionMode: isSelectionMode,
                        selectedAssets: selectedAssets,
                        onPhotoTap: { asset in
                            if isSelectionMode {
                                toggleAssetSelection(asset)
                            } else {
                                // Create a stack with just this photo and show it
                                let stack = PhotoStack(assets: [asset])
                                selectedStackIndex = 0
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedStack = stack
                                    isSwipePhotoViewOpen = true
                                }
                            }
                        },
                        onPinTap: { _ in
                            // Not used in photo library view
                        },
                        onPhotoStackTap: { assets in
                            if isSelectionMode {
                                // Select all photos in the stack
                                for asset in assets {
                                    if !selectedAssets.contains(asset.localIdentifier) {
                                        selectedAssets.insert(asset.localIdentifier)
                                    }
                                }
                                updateToolbar()
                            } else {
                                // Create a stack and show it
                                let stack = PhotoStack(assets: assets)
                                selectedStackIndex = 0
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedStack = stack
                                    isSwipePhotoViewOpen = true
                                }
                            }
                        },
                        onLocationTap: { _ in
                            // Not used in photo library view
                        }
                    )
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Photo Access Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Please allow access to your photo library to see your photos")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Grant Access") {
                        requestPhotoAccess()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
        }
        .padding(.bottom, LayoutConstants.totalToolbarHeight)
        .onAppear {
            initializeCoreData()
            requestPhotoAccess()
            setupToolbar()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RestoreToolbar"))) { _ in
            // Restore PhotoMainView specific toolbar when returning from SwipePhotoView
            print("🔧 PhotoMainView: Restoring toolbar after SwipePhotoView dismissal")
            setupToolbar()
        }
        .onChange(of: isCoreDataReady) { _, isReady in
            if isReady && !hasTriedInitialLoad {
                hasTriedInitialLoad = true
                print("Core Data became ready, triggering initial load")
                if authorizationStatus == .authorized || authorizationStatus == .limited {
                    loadPhotoAssets()
                }
            }
        }
        .overlay {
            if let selectedStack = selectedStack {
                SwipePhotoView(
                    allAssets: photoAssets,
                    photoStacks: filteredPhotoStacks,
                    initialAssetId: selectedStack.primaryAsset.localIdentifier,
                    onDismiss: {
                        print("SwipePhotoView dismissed")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.selectedStack = nil
                            isSwipePhotoViewOpen = false
                        }
                        // Refresh filter to remove disliked photos from view
                        applyFilter()
                        // Restore toolbar state via ContentView  
                        NotificationCenter.default.post(name: NSNotification.Name("RestoreToolbar"), object: nil)
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.1).combined(with: .opacity),
                    removal: .scale(scale: 0.1).combined(with: .opacity)
                ))
                .zIndex(999)
            }
        }
        .sheet(isPresented: $showingQuickList) {
            quickListView
        }
        .sheet(isPresented: $showingSearch) {
            searchDialogView
        }
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private func requestPhotoAccess() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        // If already authorized and Core Data is ready, load assets
        if (authorizationStatus == .authorized || authorizationStatus == .limited) && isCoreDataReady {
            loadPhotoAssets()
        } else if authorizationStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    authorizationStatus = status
                    if (status == .authorized || status == .limited) && isCoreDataReady {
                        loadPhotoAssets()
                    }
                }
            }
        }
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
    
    private func loadPhotoAssets() {
        print("Loading photo assets...")
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        // Remove fetchLimit to load all photos
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        print("Loaded \(assets.count) photo assets")
        
        DispatchQueue.main.async {
            allPhotoAssets = assets
            photoAssets = assets
            applyFilter()
        }
    }
    
    private func applySearchFilter() {
        var filteredAssets = allPhotoAssets
        
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
        
        // Apply preferences filter and update photoAssets
        let preferenceFilteredAssets = preferenceManager.getFilteredAssets(from: filteredAssets, filter: currentFilter)
        photoAssets = preferenceFilteredAssets
        
        // Create photo stacks for empty state check
        createPhotoStacks(from: preferenceFilteredAssets)
    }
    
    private func applyFilter() {
        guard isCoreDataReady else { 
            print("Core Data not ready, skipping filter")
            return 
        }
        print("Applying filter: \(currentFilter.displayName) to \(allPhotoAssets.count) assets")
        let filteredAssets = preferenceManager.getFilteredAssets(from: allPhotoAssets, filter: currentFilter)
        print("Filtered to \(filteredAssets.count) assets")
        
        // Update photoAssets with filtered results - RListView will handle stacking internally
        photoAssets = filteredAssets
        
        // Create photo stacks for empty state check
        createPhotoStacks(from: filteredAssets)
    }
    
    private func createPhotoStacks(from assets: [PHAsset]) {
        print("Creating photo stacks from \(assets.count) assets using similarity indices")
        
        Task {
            let stacks = await createSimilarityBasedStacks(from: assets)
            await MainActor.run {
                self.filteredPhotoStacks = stacks
                print("Created \(stacks.count) photo stacks using similarity")
            }
        }
    }
    
    private func createSimilarityBasedStacks(from assets: [PHAsset]) async -> [PhotoStack] {
        // Check if similarity indices are available
        let embeddingStats = PhotoEmbeddingService.shared.getEmbeddingStats(in: viewContext)
        let hasEmbeddings = embeddingStats.photosWithEmbeddings > 0
        
        // Only print embedding stats if they're meaningful or different from last time
        if embeddingStats.photosWithEmbeddings != lastEmbeddingCount {
            print("📊 Embedding coverage: \(embeddingStats.photosWithEmbeddings)/\(embeddingStats.totalPhotos) (\(embeddingStats.coveragePercentage)%)")
            lastEmbeddingCount = embeddingStats.photosWithEmbeddings
        }
        
        // Clear existing stack IDs only once per session to avoid repeated work
        if !hasStacksBeenCleared {
            preferenceManager.clearAllStackIds()
            hasStacksBeenCleared = true
        }
        
        if !hasEmbeddings {
            // Only log and trigger computation once per session
            if !hasTriggeredEmbeddingComputation {
                print("📊 No similarity indices available, using individual photos")
                hasTriggeredEmbeddingComputation = true
                
                // Trigger embedding computation in background without blocking UI
                Task.detached {
                    await PhotoEmbeddingService.shared.computeAllEmbeddings(in: viewContext) { processed, total in
                        // Only log every 10 photos to reduce spam
                        if processed % 10 == 0 || processed == total {
                            print("📊 Computing embeddings: \(processed)/\(total)")
                        }
                    }
                }
            }
            return assets.map { PhotoStack(assets: [$0]) }
        }
        
        // Limit processing to prevent hangs - process in batches
        let maxAssetsToProcess = 100
        let assetsToProcess = Array(assets.prefix(maxAssetsToProcess))
        
        var stacks: [PhotoStack] = []
        var processedAssets: Set<String> = []
        var currentStackId: Int32 = 1 // Start stack IDs at 1
        
        // Process assets sequentially by time with yield points
        for i in 0..<assetsToProcess.count {
            let currentAsset = assetsToProcess[i]
            
            // Skip if already processed
            if processedAssets.contains(currentAsset.localIdentifier) {
                continue
            }
            
            var currentStack = [currentAsset]
            processedAssets.insert(currentAsset.localIdentifier)
            
            // Only compare with next sequential photos (by time) - limit comparison window
            let maxComparisons = 5 // Only compare with next 5 photos to prevent hangs
            let endIndex = min(i + maxComparisons + 1, assetsToProcess.count)
            
            for j in (i + 1)..<endIndex {
                let nextAsset = assetsToProcess[j]
                
                // Skip if already processed
                if processedAssets.contains(nextAsset.localIdentifier) {
                    break // Stop checking if we hit a processed asset
                }
                
                // Check similarity between current stack's first photo and next photo
                let similarity = await getSimilarity(between: currentAsset, and: nextAsset)
                
                if let similarity = similarity, similarity > 0.95 {
                    print("📊 Found similar photos: \(currentAsset.localIdentifier) <-> \(nextAsset.localIdentifier) (similarity: \(Int(similarity * 100))%)")
                    currentStack.append(nextAsset)
                    processedAssets.insert(nextAsset.localIdentifier)
                } else {
                    // If similarity is not high enough or not available, stop stacking
                    break
                }
            }
            
            // Store stack ID for all photos in this stack if it has more than one photo
            if currentStack.count > 1 {
                for asset in currentStack {
                    preferenceManager.setStackId(for: asset, stackId: currentStackId)
                }
                print("📊 Created stack with ID \(currentStackId) containing \(currentStack.count) similar photos")
                currentStackId += 1 // Increment for next stack
            }
            
            stacks.append(PhotoStack(assets: currentStack))
            
            // Yield to prevent blocking main thread every 10 assets
            if i % 10 == 0 {
                await Task.yield()
            }
        }
        
        // Add remaining assets as individual stacks if we hit the limit
        if assets.count > maxAssetsToProcess {
            let remainingAssets = Array(assets.dropFirst(maxAssetsToProcess))
            let remainingStacks = remainingAssets.map { PhotoStack(assets: [$0]) }
            stacks.append(contentsOf: remainingStacks)
            print("📊 Added \(remainingAssets.count) remaining assets as individual photos (processing limit reached)")
        }
        
        print("📊 Stored stack IDs for \(currentStackId - 1) similarity-based stacks")
        return stacks
    }
    
    private func getSimilarity(between asset1: PHAsset, and asset2: PHAsset) async -> Float? {
        // Get embeddings for both assets
        guard let embedding1 = await PhotoEmbeddingService.shared.getEmbedding(for: asset1, in: viewContext),
              let embedding2 = await PhotoEmbeddingService.shared.getEmbedding(for: asset2, in: viewContext),
              let vector1 = getEmbeddingVector(from: embedding1),
              let vector2 = getEmbeddingVector(from: embedding2) else {
            return nil
        }
        
        return ImageEmbeddingService.shared.cosineSimilarity(vector1, vector2)
    }
    
    private func getEmbeddingVector(from photoEmbedding: PhotoEmbedding) -> [Float]? {
        guard let embeddingData = photoEmbedding.embedding else {
            return nil
        }
        return PhotoEmbeddingService.shared.dataToEmbedding(embeddingData)
    }
    
    // MARK: - Selection Mode
    
    private func toggleSelectionMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSelectionMode.toggle()
            if !isSelectionMode {
                selectedAssets.removeAll()
            }
            updateToolbar()
            notifySelectionChanged()
        }
    }
    
    private func toggleAssetSelection(_ asset: PHAsset) {
        if selectedAssets.contains(asset.localIdentifier) {
            selectedAssets.remove(asset.localIdentifier)
        } else {
            selectedAssets.insert(asset.localIdentifier)
        }
        notifySelectionChanged()
    }
    
    private func notifySelectionChanged() {
        let hasSelection = isSelectionMode && !selectedAssets.isEmpty
        NotificationCenter.default.post(
            name: NSNotification.Name("PhotoSelectionChanged"), 
            object: hasSelection
        )
    }
    
    // MARK: - Batch Actions
    
    private func favoriteSelectedPhotos() {
        let assetsToFavorite = allPhotoAssets.filter { selectedAssets.contains($0.localIdentifier) }
        
        PHPhotoLibrary.shared().performChanges({
            for asset in assetsToFavorite {
                let request = PHAssetChangeRequest(for: asset)
                request.isFavorite = true
            }
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully favorited \(assetsToFavorite.count) photos")
                } else {
                    print("❌ Failed to favorite photos: \(error?.localizedDescription ?? "Unknown error")")
                }
                // Exit selection mode after action
                self.isSelectionMode = false
                self.selectedAssets.removeAll()
                self.updateToolbar()
            }
        }
    }
    
    private func archiveSelectedPhotos() {
        let assetsToArchive = allPhotoAssets.filter { selectedAssets.contains($0.localIdentifier) }
        
        // Update preferences to mark as archived
        for asset in assetsToArchive {
            preferenceManager.setPreference(for: asset, preference: .archive)
        }
        
        print("✅ Archived \(assetsToArchive.count) photos")
        
        // Exit selection mode and refresh
        isSelectionMode = false
        selectedAssets.removeAll()
        updateToolbar()
        applyFilter() // Refresh to remove archived photos if current filter excludes them
    }
    
    private func addSelectedToQuickList() {
        let assetsToAdd = allPhotoAssets.filter { selectedAssets.contains($0.localIdentifier) }
        let userId = AuthenticationService.shared.currentAccount?.id ?? ""
        
        var successCount = 0
        for asset in assetsToAdd {
            if RListService.shared.togglePhotoInQuickList(asset, context: viewContext, userId: userId) {
                successCount += 1
            }
        }
        
        print("✅ Added \(successCount) photos to Quick List")
        
        // Exit selection mode after action
        isSelectionMode = false
        selectedAssets.removeAll()
        updateToolbar()
    }
    
    // MARK: - Toolbar Setup
    
    private func setupToolbar() {
        updateToolbar()
    }
    
    private func updateToolbar() {
        let hasSelection = !selectedAssets.isEmpty
        
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
            )
        ]
        
        toolbarManager.setCustomToolbar(buttons: photoButtons)
    }
}

/// Represents a group of related photos that can be displayed as a stack
struct PhotoStack: Identifiable {
    let id = UUID()
    let assets: [PHAsset]
    
    var isStack: Bool {
        return assets.count > 1
    }
    
    var primaryAsset: PHAsset {
        return assets.first!
    }
    
    var count: Int {
        return assets.count
    }
}

struct PhotoStackCell: View {
    let stack: PhotoStack
    let onTap: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var image: UIImage?
    @State private var isInQuickList = false
    
    private var preferenceManager: PhotoPreferenceManager {
        PhotoPreferenceManager(viewContext: viewContext)
    }
    
    private var stackHasFavorite: Bool {
        stack.assets.contains { $0.isFavorite }
    }
    
    private var primaryAssetPreference: PhotoPreferenceType {
        preferenceManager.getPreference(for: stack.primaryAsset)
    }
    
    private var shouldShowFavoriteIcon: Bool {
        if stack.isStack {
            return stackHasFavorite
        } else {
            return stack.primaryAsset.isFavorite
        }
    }
    
    private var shouldShowDislikeIcon: Bool {
        !stack.isStack && primaryAssetPreference == .archive
    }
    
    private var shouldShowQuickListButton: Bool {
        !stack.isStack // Only show for individual photos, not stacks
    }
    
    var body: some View {
        ZStack {
            // Background image with tap gesture
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onTapGesture {
                print("PhotoStackCell onTapGesture triggered")
                onTap()
            }
            
            // Overlay indicators
            VStack {
                HStack {
                    // Favorite indicator (top-left)
                    if shouldShowFavoriteIcon {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        .padding(4)
                    }
                    
                    Spacer()
                    
                    // Stack indicator (top-right)
                    if stack.isStack {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 28, height: 28)
                            
                            HStack(spacing: 1) {
                                Image(systemName: "rectangle.stack.fill")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                Text("\(stack.count)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(4)
                    }
                    
                    // Quick List button (top-right for individual photos)
                    if shouldShowQuickListButton {
                        Button(action: {
                            toggleQuickList()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: isInQuickList ? "circle.fill" : "circle")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(4)
                    }
                }
                
                Spacer()
                
                // Dislike indicator (bottom-right)
                if shouldShowDislikeIcon {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        .padding(4)
                    }
                }
            }
        }
        .onAppear {
            loadThumbnail()
            updateQuickListStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RListDatasChanged"))) { _ in
            updateQuickListStatus()
        }
    }
    
    private func loadThumbnail() {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        
        let targetSize = CGSize(width: 300, height: 300)
        
        imageManager.requestImage(for: stack.primaryAsset, targetSize: targetSize, contentMode: .aspectFill, options: options) { loadedImage, _ in
            DispatchQueue.main.async {
                image = loadedImage
            }
        }
    }
    
    private func updateQuickListStatus() {
        guard shouldShowQuickListButton else { return }
        
        let userId = AuthenticationService.shared.currentAccount?.id ?? ""
        let newStatus = RListService.shared.isPhotoInQuickList(stack.primaryAsset, context: viewContext, userId: userId)
        
        print("🔍 DEBUG updateQuickListStatus: assetId=\(stack.primaryAsset.localIdentifier), oldStatus=\(isInQuickList), newStatus=\(newStatus)")
        
        isInQuickList = newStatus
    }
    
    private func toggleQuickList() {
        guard shouldShowQuickListButton else { return }
        
        let userId = AuthenticationService.shared.currentAccount?.id ?? ""
        let wasInList = isInQuickList
        
        print("🔍 DEBUG toggleQuickList: wasInList=\(wasInList), userId=\(userId), assetId=\(stack.primaryAsset.localIdentifier)")
        
        let success = RListService.shared.togglePhotoInQuickList(stack.primaryAsset, context: viewContext, userId: userId)
        
        print("🔍 DEBUG toggleQuickList: success=\(success)")
        
        if success {
            isInQuickList = !wasInList
            print("🔍 DEBUG toggleQuickList: Updated state - isInQuickList=\(isInQuickList)")
            
            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            print("📝 \(wasInList ? "Removed from" : "Added to") Quick List: \(stack.primaryAsset.localIdentifier)")
        } else {
            print("❌ Failed to toggle Quick List status")
        }
    }
}

struct PhotoDetailView: View {
    let asset: PHAsset
    let onDismiss: () -> Void
    
    @State private var image: UIImage?
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: UIScreen.main.bounds.height * 0.8)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .onAppear {
            loadFullImage()
        }
    }
    
    private func loadFullImage() {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        let targetSize = CGSize(width: UIScreen.main.bounds.width * UIScreen.main.scale,
                               height: UIScreen.main.bounds.height * UIScreen.main.scale)
        
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { loadedImage, _ in
            DispatchQueue.main.async {
                image = loadedImage
            }
        }
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
        let _ = CLGeocoder() // Reserved for future reverse geocoding
        // For now, just show coordinates. In real app, you'd reverse geocode
        return String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct PhotoStackView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoMainView(isSwipePhotoViewOpen: .constant(false))
    }
}
