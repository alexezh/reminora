import SwiftUI
import Photos
import PhotosUI
import UIKit
import CoreData

struct PhotoStackView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var photoAssets: [PHAsset] = []
    @State private var filteredPhotoStacks: [PhotoStack] = []
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var showingFullPhoto = false
    @State private var selectedAsset: PHAsset?
    @State private var selectedStack: PhotoStack?
    @State private var showingStackDetail = false
    @State private var selectedStackIndex = 0
    @State private var currentFilter: PhotoFilterType = .notDisliked
    @State private var isCoreDataReady = false
    
    private var preferenceManager: PhotoPreferenceManager {
        PhotoPreferenceManager(viewContext: viewContext)
    }
    
    // Time interval for grouping photos into stacks (in minutes)
    private let stackingInterval: TimeInterval = 10 * 60 // 10 minutes
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
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
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(filteredPhotoStacks, id: \.id) { stack in
                                PhotoStackCell(
                                    stack: stack,
                                    onTap: {
                                        if stack.assets.count > 1 {
                                            selectedStack = stack
                                            selectedStackIndex = 0
                                            showingStackDetail = true
                                        } else {
                                            selectedAsset = stack.assets.first
                                            showingFullPhoto = true
                                        }
                                    }
                                )
                                .aspectRatio(1, contentMode: .fit)
                            }
                        }
                        .padding(.horizontal, 1)
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
        }
        .sheet(isPresented: $showingFullPhoto) {
            if let selectedAsset = selectedAsset {
                PhotoDetailView(asset: selectedAsset) {
                    showingFullPhoto = false
                    // Refresh filter in case preferences changed
                    applyFilter()
                }
            }
        }
        .sheet(isPresented: $showingStackDetail) {
            if let selectedStack = selectedStack {
                SwipePhotoView(
                    stack: selectedStack,
                    initialIndex: selectedStackIndex,
                    onDismiss: {
                        showingStackDetail = false
                        // Refresh filter to remove disliked photos from view
                        applyFilter()
                    }
                )
            }
        }
    }
    
    private func requestPhotoAccess() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        if authorizationStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    authorizationStatus = status
                    if status == .authorized || status == .limited && isCoreDataReady {
                        loadPhotoAssets()
                    }
                }
            }
        }
    }
    
    private func initializeCoreData() {
        // Check if Core Data is ready
        if viewContext.persistentStoreCoordinator != nil {
            isCoreDataReady = true
            // If photo access is already authorized, load assets now
            if authorizationStatus == .authorized || authorizationStatus == .limited {
                loadPhotoAssets()
            }
        } else {
            // Wait for Core Data to be ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                initializeCoreData()
            }
        }
    }
    
    private func loadPhotoAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1000 // Load recent photos
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        DispatchQueue.main.async {
            photoAssets = assets
            applyFilter()
        }
    }
    
    private func applyFilter() {
        guard isCoreDataReady else { return }
        let filteredAssets = preferenceManager.getFilteredAssets(from: photoAssets, filter: currentFilter)
        createPhotoStacks(from: filteredAssets)
    }
    
    private func createPhotoStacks(from assets: [PHAsset]) {
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
    
    @State private var image: UIImage?
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            
            // Stack indicator
            if stack.isStack {
                VStack {
                    HStack {
                        Spacer()
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
                    Spacer()
                }
            }
        }
        .onTapGesture {
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
    @State private var showingShareSheet = false
    @State private var shareText = ""
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
                // Top toolbar
                HStack {
                    Button("Close") {
                        onDismiss()
                    }
                    .foregroundColor(.white)
                    .padding(.leading)
                    
                    Spacer()
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        Button(action: thumbsDown) {
                            Image(systemName: currentPreference == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                .font(.title2)
                                .foregroundColor(currentPreference == .dislike ? .red : .white)
                        }
                        
                        Button(action: thumbsUp) {
                            Image(systemName: currentPreference == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.title2)
                                .foregroundColor(currentPreference == .like ? .green : .white)
                        }
                        
                        Button(action: sharePhoto) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        
                        Button("Pin") {
                            showingAddPin = true
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .padding(.trailing)
                }
                .padding(.top, 50)
                .padding(.bottom, 20)
                
                // Photo display using TabView for smooth swiping
                if !stack.assets.isEmpty {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(stack.assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                            SwipePhotoImageView(asset: asset, isLoading: $isLoading)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.7)
                } else {
                    // Fallback for empty stack
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxHeight: UIScreen.main.bounds.height * 0.7)
                }
                
                // Navigation dots for stacks
                if stack.assets.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<stack.assets.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 50)
                }
                }
            }
        }
        .offset(y: dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow vertical downward drags
                    if value.translation.height > 0 {
                        dragOffset = CGSize(width: 0, height: value.translation.height)
                    }
                }
                .onEnded { value in
                    // If dragged down more than 150 points, dismiss
                    if value.translation.height > 150 {
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
            isLoading = true
            // Ensure the current index is valid
            if currentIndex >= stack.assets.count {
                currentIndex = 0
            }
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
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(text: shareText)
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
        
        let reminoraLink = "https://reminora.app/place/\(placeId)?name=\(encodedName)&lat=\(lat)&lon=\(lon)"
        
        let shareMessage = "Check out this photo on Reminora!\n\n\(reminoraLink)"
        print("Share message: \(shareMessage)")
        
        shareText = shareMessage
        showingShareSheet = true
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
        // Wait for Core Data context to be ready
        DispatchQueue.main.async {
            // Check if the viewContext is properly initialized
            if viewContext.persistentStoreCoordinator != nil {
                isPreferenceManagerReady = true
                updateCurrentPreference()
            } else {
                // Wait a bit longer and try again
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    initializePreferenceManager()
                }
            }
        }
    }
    
    private func updateCurrentPreference() {
        guard isPreferenceManagerReady else { return }
        currentPreference = preferenceManager.getPreference(for: currentAsset)
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
                
                // Location info
                if let location = asset.location {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text(String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospaced()
                        }
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

#Preview {
    PhotoStackView()
}