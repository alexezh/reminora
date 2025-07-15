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
    @State private var showingQuickList = false
    
    private var preferenceManager: PhotoPreferenceManager {
        PhotoPreferenceManager(viewContext: viewContext)
    }
    
    private var quickListView: some View {
        QuickListService.createQuickListView(
            context: viewContext,
            userId: AuthenticationService.shared.currentAccount?.id ?? "",
            onPhotoTap: { asset in
                // Create a stack with just this photo and show it
                let stack = PhotoStack(assets: [asset])
                selectedStackIndex = 0
                showingQuickList = false
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedStack = stack
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
                            ForEach([PhotoFilterType.notDisliked, .favorites, .dislikes, .all], id: \.self) { filter in
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
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    selectedStack = stack
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
        .fullScreenCover(item: Binding<PhotoStack?>(
            get: { selectedStack },
            set: { _ in selectedStack = nil }
        )) { stack in
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
        }
        .sheet(isPresented: $showingQuickList) {
            quickListView
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
        .onTapGesture {
            print("PhotoStackCell onTapGesture triggered")
            onTap()
        }
        .onAppear {
            loadThumbnail()
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
        isInQuickList = QuickListService.shared.isPhotoInQuickList(stack.primaryAsset, context: viewContext, userId: userId)
    }
    
    private func toggleQuickList() {
        guard shouldShowQuickListButton else { return }
        
        let userId = AuthenticationService.shared.currentAccount?.id ?? ""
        let wasInList = isInQuickList
        
        let success = QuickListService.shared.togglePhotoInQuickList(stack.primaryAsset, context: viewContext, userId: userId)
        
        if success {
            isInQuickList = !wasInList
            
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
