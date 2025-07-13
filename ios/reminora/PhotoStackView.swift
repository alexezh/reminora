import SwiftUI
import Photos
import PhotosUI
import UIKit
import CoreData
import MapKit
import CoreLocation

struct PhotoStackView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var photoAssets: [PHAsset] = []
    @State private var filteredPhotoStacks: [PhotoStack] = []
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var selectedStack: PhotoStack?
    @State private var selectedStackIndex = 0
    @State private var currentFilter: PhotoFilterType = .notDisliked
    @State private var isCoreDataReady = false
    @State private var hasTriedInitialLoad = false
    
    private var preferenceManager: PhotoPreferenceManager {
        PhotoPreferenceManager(viewContext: viewContext)
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
        NavigationView {
            VStack {
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
                    // Filter buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach([PhotoFilterType.notDisliked, .all, .favorites, .dislikes], id: \.self) { filter in
                                Button(action: {
                                    currentFilter = filter
                                    applyFilter()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: filter.iconName)
                                        Text(filter.displayName)
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
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
                                    .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                    
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
                                                selectedStack = stack
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
            .navigationTitle("Photos")
            .navigationBarTitleDisplayMode(.large)
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
        }
        .sheet(item: $selectedStack) { stack in
            SwipePhotoView(
                stack: stack,
                initialIndex: selectedStackIndex,
                onDismiss: {
                    print("SwipePhotoView dismissed")
                    selectedStack = nil
                    // Refresh filter to remove disliked photos from view
                    applyFilter()
                }
            )
            .onAppear {
                print("Sheet presented with stack of \(stack.assets.count) assets")
            }
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
        fetchOptions.fetchLimit = 1000 // Load recent photos
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        print("Loaded \(assets.count) photo assets")
        
        DispatchQueue.main.async {
            photoAssets = assets
            applyFilter()
        }
    }
    
    private func applyFilter() {
        guard isCoreDataReady else { 
            print("Core Data not ready, skipping filter")
            return 
        }
        print("Applying filter: \(currentFilter.displayName) to \(photoAssets.count) assets")
        let filteredAssets = preferenceManager.getFilteredAssets(from: photoAssets, filter: currentFilter)
        print("Filtered to \(filteredAssets.count) assets")
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
    
    var body: some View {
        ZStack {
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
        .onTapGesture {
            print("PhotoStackCell onTapGesture triggered")
            onTap()
        }
        .onAppear {
            loadThumbnail()
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

struct SwipePhotoView: View {
    let stack: PhotoStack
    let initialIndex: Int
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var currentIndex: Int
    @State private var showingNearbyPhotos = false
    @State private var showingAddPin = false
    @State private var showingSimilarImages = false
    @State private var showingSimilarGridView = false
    @State private var showingMenu = false
    @State private var shareData: PhotoShareData?
    @State private var isLoading = false
    @State private var dragOffset: CGSize = .zero
    @State private var currentPreference: PhotoPreferenceType = .neutral
    @State private var isPreferenceManagerReady = false
    
    private var preferenceManager: PhotoPreferenceManager {
        PhotoPreferenceManager(viewContext: viewContext)
    }
    
    init(stack: PhotoStack, initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.stack = stack
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    private var currentAsset: PHAsset {
        return stack.assets[currentIndex]
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !isPreferenceManagerReady {
                // Show loading UI while preference manager is initializing
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .foregroundColor(.white)
                        .padding(.top, 16)
                }
            } else {
                VStack(spacing: 0) {
                    // Top info bar with navigation and date
                    VStack(spacing: 4) {
                        HStack {
                            // Navigation-style back button
                            Button(action: {
                                onDismiss()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            // Menu button (vertical dots)
                            Button(action: {
                                showingMenu = true
                            }) {
                                Image(systemName: "ellipsis")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(90))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                        // Location and date info
                        VStack(spacing: 2) {
                            if let location = currentAsset.location {
                                Text(formatLocation(location))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            if let date = currentAsset.creationDate {
                                Text(formatDate(date))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    
                    // Photo display using TabView for smooth swiping
                    if !stack.assets.isEmpty {
                        TabView(selection: $currentIndex) {
                            ForEach(Array(stack.assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                SwipePhotoImageView(asset: asset, isLoading: $isLoading)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    } else {
                        // Fallback for empty stack
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    
                    Spacer()
                    
                    // Bottom section with thumbnails and action buttons
                    VStack(spacing: 12) {
                        // Thumbnail strip (iOS Photos style)
                        if stack.assets.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(Array(stack.assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                        PhotoThumbnailView(
                                            asset: asset,
                                            isSelected: index == currentIndex,
                                            onTap: {
                                                currentIndex = index
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .frame(height: 60)
                        }
                        
                        // Action buttons (iOS Photos style)
                        HStack(spacing: 32) {
                            // Share button
                            Button(action: sharePhoto) {
                                VStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    Text("Share")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Favorite button
                            Button(action: thumbsUp) {
                                VStack(spacing: 4) {
                                    Image(systemName: currentPreference == .like ? "heart.fill" : "heart")
                                        .font(.title2)
                                        .foregroundColor(currentPreference == .like ? .red : .white)
                                    Text("Favorite")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Reject button
                            Button(action: thumbsDown) {
                                VStack(spacing: 4) {
                                    Image(systemName: currentPreference == .dislike ? "x.circle.fill" : "x.circle")
                                        .font(.title2)
                                        .foregroundColor(currentPreference == .dislike ? .orange : .white)
                                    Text("Reject")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            // Pin button
                            Button {
                                showingAddPin = true
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    Text("Pin")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 34) // Safe area padding
                    }
                }
            }
        }
        .offset(y: dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only respond to primarily vertical drags (more vertical than horizontal)
                    let translation = value.translation
                    let isVerticalDrag = abs(translation.height) > abs(translation.width) * 1.5
                    
                    // Only allow vertical downward drags that are primarily vertical
                    if translation.height > 0 && isVerticalDrag {
                        dragOffset = CGSize(width: 0, height: translation.height)
                    }
                }
                .onEnded { value in
                    let translation = value.translation
                    let isVerticalDrag = abs(translation.height) > abs(translation.width) * 1.5
                    
                    // Only dismiss if it was a primarily vertical drag
                    if translation.height > 150 && isVerticalDrag {
                        onDismiss()
                    } else {
                        // Snap back to original position
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .onAppear {
            print("SwipePhotoView onAppear called with stack of \(stack.assets.count) assets")
            isLoading = true
            // Ensure the current index is valid
            if currentIndex >= stack.assets.count {
                currentIndex = 0
            }
            print("Starting preference manager initialization...")
            initializePreferenceManager()
        }
        .onChange(of: currentIndex) { _, _ in
            updateCurrentPreference()
        }
        .sheet(isPresented: $showingAddPin) {
            NavigationView {
                AddPinFromPhotoView(
                    asset: currentAsset,
                    onDismiss: {
                        showingAddPin = false
                    }
                )
            }
        }
        .sheet(item: $shareData) { data in
            let _ = print("PhotoStackView ShareSheet - text: '\(data.message)', url: '\(data.link)'")
            ShareSheet(text: data.message, url: data.link)
        }
        .sheet(isPresented: $showingSimilarImages) {
            PhotoSimilarityView(targetAsset: currentAsset)
        }
        .confirmationDialog("Photo Options", isPresented: $showingMenu, titleVisibility: .hidden) {
            Button("Find Similar") {
                showingSimilarGridView = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingSimilarGridView) {
            SimilarPhotosGridView(targetAsset: currentAsset)
        }
    }
    
    
    private func thumbsUp() {
        guard isPreferenceManagerReady else { return }
        
        preferenceManager.setPreference(for: currentAsset, preference: .like)
        print("Thumbs up for photo at index \(currentIndex)")
        
        // Update UI state immediately
        currentPreference = .like
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func thumbsDown() {
        guard isPreferenceManagerReady else { return }
        
        preferenceManager.setPreference(for: currentAsset, preference: .dislike)
        print("Thumbs down for photo at index \(currentIndex)")
        
        // Update UI state immediately
        currentPreference = .dislike
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Auto-dismiss after marking as disliked
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
    
    private func showSimilarImages() {
        // Simply show the photo similarity view with the current asset
        showingSimilarImages = true
    }
    
    private func sharePhoto() {
        // First create a Place from this photo, then share it
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        imageManager.requestImage(for: currentAsset, targetSize: CGSize(width: 1024, height: 1024), contentMode: .aspectFit, options: options) { image, _ in
            guard let image = image,
                  let imageData = image.jpegData(compressionQuality: 0.8) else {
                print("Failed to get image data for sharing")
                return
            }
            
            DispatchQueue.main.async {
                // Create new Place for sharing
                let newPlace = Place(context: viewContext)
                newPlace.imageData = imageData
                newPlace.dateAdded = currentAsset.creationDate ?? Date()
                
                if let location = currentAsset.location {
                    let locationData = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false)
                    newPlace.location = locationData
                }
                
                // Add metadata about sharing
                var postText = "Shared from photo library"
                if let creationDate = currentAsset.creationDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    postText += " • Taken: \(formatter.string(from: creationDate))"
                }
                newPlace.post = postText
                
                do {
                    try viewContext.save()
                    print("Successfully saved place for sharing")
                    
                    // Now create the share URL using the new Place
                    createShareURL(for: newPlace)
                } catch {
                    print("Failed to save photo as place for sharing: \(error)")
                }
            }
        }
    }
    
    private func createShareURL(for place: Place) {
        let coord = coordinate(for: place)
        let placeId = place.objectID.uriRepresentation().absoluteString
        let encodedName = (place.post ?? "Shared Photo").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let lat = coord.latitude
        let lon = coord.longitude
        
        // Add owner information from auth service
        let authService = AuthenticationService.shared
        let ownerId = authService.currentAccount?.id ?? ""
        let ownerHandle = authService.currentAccount?.handle ?? ""
        let encodedOwnerHandle = ownerHandle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let reminoraLink = "reminora://place/\(placeId)?name=\(encodedName)&lat=\(lat)&lon=\(lon)&ownerId=\(ownerId)&ownerHandle=\(encodedOwnerHandle)"
        
        let message = "Check out this photo on Reminora!"
        print("Share message: \(message)")
        print("Share URL: \(reminoraLink)")
        
        shareData = PhotoShareData(message: message, link: reminoraLink)
        print("PhotoStackView - After assignment - shareData:", shareData?.message ?? "nil", shareData?.link ?? "nil")
    }
    
    private func coordinate(for place: Place) -> CLLocationCoordinate2D {
        if let locationData = place.value(forKey: "location") as? Data,
           let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation {
            return location.coordinate
        }
        // Default to San Francisco if no location
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }
    
    
    private func getPhotoLocation() -> CLLocationCoordinate2D? {
        guard let location = currentAsset.location else {
            return nil
        }
        return location.coordinate
    }
    
    private func initializePreferenceManager() {
        initializePreferenceManager(retryCount: 0)
    }
    
    private func initializePreferenceManager(retryCount: Int) {
        // Add a timeout after 30 retries (3 seconds)
        if retryCount > 30 {
            print("Core Data initialization timeout, proceeding anyway")
            isPreferenceManagerReady = true
            updateCurrentPreference()
            return
        }
        
        // Wait for Core Data context to be ready
        DispatchQueue.main.async {
            // Check if the viewContext is properly initialized
            if viewContext.persistentStoreCoordinator != nil {
                print("SwipePhotoView: Core Data ready after \(retryCount) retries")
                isPreferenceManagerReady = true
                updateCurrentPreference()
            } else {
                // Wait a bit longer and try again
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    initializePreferenceManager(retryCount: retryCount + 1)
                }
            }
        }
    }
    
    private func updateCurrentPreference() {
        guard isPreferenceManagerReady else { 
            print("Preference manager not ready, skipping preference update")
            return 
        }
        
        do {
            currentPreference = preferenceManager.getPreference(for: currentAsset)
            print("Updated preference for asset: \(currentPreference)")
        } catch {
            print("Error getting preference: \(error)")
            // Fallback to neutral if there's an error
            currentPreference = .neutral
        }
    }
}

struct SwipePhotoImageView: View {
    let asset: PHAsset
    @Binding var isLoading: Bool
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var loadError: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { value in
                                    lastScale = scale
                                    // Limit zoom between 1x and 4x
                                    if scale < 1 {
                                        withAnimation(.spring()) {
                                            scale = 1
                                            lastScale = 1
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    } else if scale > 4 {
                                        withAnimation(.spring()) {
                                            scale = 4
                                            lastScale = 4
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            // Only enable pan gesture when zoomed in
                            DragGesture()
                                .onChanged { value in
                                    // Only allow panning when zoomed in
                                    if scale > 1 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { value in
                                    // Only handle pan end when zoomed in
                                    if scale > 1 {
                                        lastOffset = offset
                                        
                                        // Bounce back if panned too far
                                        let maxOffsetX = (geometry.size.width * (scale - 1)) / 2
                                        let maxOffsetY = (geometry.size.height * (scale - 1)) / 2
                                        
                                        var newOffset = offset
                                        if abs(offset.width) > maxOffsetX {
                                            newOffset.width = offset.width > 0 ? maxOffsetX : -maxOffsetX
                                        }
                                        if abs(offset.height) > maxOffsetY {
                                            newOffset.height = offset.height > 0 ? maxOffsetY : -maxOffsetY
                                        }
                                        
                                        if newOffset != offset {
                                            withAnimation(.spring()) {
                                                offset = newOffset
                                                lastOffset = newOffset
                                            }
                                        }
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            // Double tap to zoom
                            withAnimation(.spring()) {
                                if scale > 1 {
                                    scale = 1
                                    lastScale = 1
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2
                                    lastScale = 2
                                }
                            }
                        }
                } else if loadError {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.white)
                        Text("Failed to load image")
                            .foregroundColor(.white)
                            .font(.caption)
                        Button("Retry") {
                            loadError = false
                            loadImage()
                        }
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .clipped()
        .onAppear {
            if image == nil && !loadError {
                loadImage()
            }
        }
    }
    
    private func loadImage() {
        isLoading = true
        loadError = false
        
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        
        let targetSize = CGSize(width: UIScreen.main.bounds.width * UIScreen.main.scale,
                               height: UIScreen.main.bounds.height * UIScreen.main.scale)
        
        print("Loading image for asset: \(asset.localIdentifier)")
        
        // Request image with error handling
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { loadedImage, info in
            DispatchQueue.main.async {
                
                if let loadedImage = loadedImage {
                    image = loadedImage
                    isLoading = false
                    loadError = false
                    print("Successfully loaded image for asset: \(asset.localIdentifier)")
                    
                    // Check if this is a degraded image and request high quality
                    if let info = info,
                       let degraded = info[PHImageResultIsDegradedKey] as? Bool,
                       degraded {
                        print("Loading high quality version for asset: \(asset.localIdentifier)")
                        
                        let hqOptions = PHImageRequestOptions()
                        hqOptions.isSynchronous = false
                        hqOptions.deliveryMode = .highQualityFormat
                        hqOptions.resizeMode = .exact
                        hqOptions.isNetworkAccessAllowed = true
                        
                        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: hqOptions) { hqImage, hqInfo in
                            DispatchQueue.main.async {
                                if let hqImage = hqImage {
                                    image = hqImage
                                    print("High quality image loaded for asset: \(asset.localIdentifier)")
                                }
                            }
                        }
                    }
                } else {
                    // Handle loading failure
                    isLoading = false
                    loadError = true
                    
                    // Check for specific error information
                    if let info = info {
                        if let error = info[PHImageErrorKey] as? Error {
                            print("Image loading error for asset \(asset.localIdentifier): \(error)")
                        }
                        if let cancelled = info[PHImageCancelledKey] as? Bool, cancelled {
                            print("Image loading cancelled for asset: \(asset.localIdentifier)")
                        }
                        if let inCloud = info[PHImageResultIsInCloudKey] as? Bool, inCloud {
                            print("Image is in iCloud for asset: \(asset.localIdentifier)")
                        }
                    }
                    
                    print("Failed to load image for asset: \(asset.localIdentifier)")
                }
            }
        }
    }
}

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct AddPinFromPhotoView: View {
    let asset: PHAsset
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var image: UIImage?
    @State private var caption: String = ""
    @State private var isSaving = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Photo preview
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 300)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 300)
                        .cornerRadius(12)
                        .overlay(
                            ProgressView()
                        )
                }
                
                // Caption input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Caption")
                        .font(.headline)
                    
                    TextField("What's happening here?", text: $caption, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                // Location info with map
                if let location = asset.location {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                        
                        // Coordinates
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text(String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospaced()
                        }
                        
                        // Mini map
                        Map(coordinateRegion: .constant(MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )), annotationItems: [MapPin(coordinate: location.coordinate)]) { pin in
                            MapMarker(coordinate: pin.coordinate, tint: .red)
                        }
                        .frame(height: 150)
                        .cornerRadius(8)
                        .disabled(true) // Make map non-interactive
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "location.slash")
                                .foregroundColor(.orange)
                            Text("No location data available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Add Pin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onDismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    savePinFromPhoto()
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        
        imageManager.requestImage(for: asset, targetSize: CGSize(width: 400, height: 400), contentMode: .aspectFill, options: options) { loadedImage, _ in
            DispatchQueue.main.async {
                image = loadedImage
            }
        }
    }
    
    private func savePinFromPhoto() {
        isSaving = true
        
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        imageManager.requestImage(for: asset, targetSize: CGSize(width: 1024, height: 1024), contentMode: .aspectFit, options: options) { image, _ in
            guard let image = image,
                  let imageData = image.jpegData(compressionQuality: 0.8) else {
                DispatchQueue.main.async {
                    isSaving = false
                }
                return
            }
            
            DispatchQueue.main.async {
                let newPlace = Place(context: viewContext)
                newPlace.imageData = imageData
                newPlace.dateAdded = asset.creationDate ?? Date()
                newPlace.post = caption.isEmpty ? "Added from Photos" : caption
                
                if let location = asset.location {
                    let locationData = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false)
                    newPlace.location = locationData
                }
                
                do {
                    try viewContext.save()
                    isSaving = false
                    onDismiss()
                } catch {
                    print("Failed to save pin: \(error)")
                    isSaving = false
                }
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

#Preview {
    PhotoStackView()
}
