import SwiftUI
import Photos
import PhotosUI
import UIKit
import CoreData
import MapKit
import CoreLocation

struct PhotoStackView: View {
    @Environment(\.managedObjectContext) private var viewContext
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
    
    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    var body: some View {
        VStack {
            // Search button at top
            HStack {
                Spacer()
                Button(action: {
                    showingSearch = true
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
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
                        GeometryReader { geometry in
                            let squareSize = (geometry.size.width - 3) / 4 // 4 photos with 3 gaps of 1px
                            
                            ScrollView {
                                LazyVGrid(columns: columns, spacing: 1) {
                                    ForEach(filteredPhotoStacks, id: \.id) { stack in
                                        PhotoStackCell(
                                            stack: stack,
                                            onTap: {
                                                print("PhotoStackCell tapped for stack with \(stack.assets.count) assets")
                                                selectedStackIndex = 0
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    selectedStack = stack
                                                    isSwipePhotoViewOpen = true
                                                }
                                                print("Set selectedStack")
                                            }
                                        )
                                        .frame(width: squareSize, height: squareSize)
                                        .clipped()
                                    }
                                }
                                .padding(.horizontal, 0)
                            }
                        }
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
            .onAppear {
                initializeCoreData()
                requestPhotoAccess()
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
                    stack: selectedStack,
                    initialIndex: selectedStackIndex,
                    onDismiss: {
                        print("SwipePhotoView dismissed")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.selectedStack = nil
                            isSwipePhotoViewOpen = false
                        }
                        // Refresh filter to remove disliked photos from view
                        applyFilter()
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
        
        photoAssets = filteredAssets
        applyFilter()
    }
    
    private func applyFilter() {
        guard isCoreDataReady else { 
            print("Core Data not ready, skipping filter")
            return 
        }
        //print("Applying filter: \(currentFilter.displayName) to \(photoAssets.count) assets")
        let filteredAssets = preferenceManager.getFilteredAssets(from: photoAssets, filter: currentFilter)
        //print("Filtered to \(filteredAssets.count) assets")
        createPhotoStacks(from: filteredAssets)
    }
    
    private func createPhotoStacks(from assets: [PHAsset]) {
        print("Creating photo stacks from \(assets.count) assets")
        var stacks: [PhotoStack] = []
        var currentStack: [PHAsset] = []
        var lastDate: Date?
        
        for asset in assets {
            guard let creationDate = asset.creationDate else {
                // Handle assets without creation date
                if !currentStack.isEmpty {
                    stacks.append(PhotoStack(assets: currentStack))
                    currentStack = []
                }
                stacks.append(PhotoStack(assets: [asset]))
                lastDate = nil
                continue
            }
            
            if let lastDate = lastDate {
                let timeDifference = lastDate.timeIntervalSince(creationDate)
                
                if timeDifference <= stackingInterval {
                    // Add to current stack
                    currentStack.append(asset)
                } else {
                    // Start new stack
                    if !currentStack.isEmpty {
                        stacks.append(PhotoStack(assets: currentStack))
                    }
                    currentStack = [asset]
                }
            } else {
                // First asset
                currentStack = [asset]
            }
            
            lastDate = creationDate
        }
        
        // Add final stack
        if !currentStack.isEmpty {
            stacks.append(PhotoStack(assets: currentStack))
        }
        
        print("Created \(stacks.count) photo stacks")
        filteredPhotoStacks = stacks
    }
}

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
        !stack.isStack && primaryAssetPreference == .dislike
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
        let geocoder = CLGeocoder()
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
        PhotoStackView(isSwipePhotoViewOpen: .constant(false))
    }
}
