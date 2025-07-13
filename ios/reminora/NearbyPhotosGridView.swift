import Photos
import PhotosUI
import SwiftUI
import CoreData
import CoreLocation
import MapKit

enum DistanceRange: String, CaseIterable, Hashable {
    case twoHundredMeters = "200m"
    case fiveHundredMeters = "500m"
    case oneKilometer = "1km"
    case twoKilometers = "2km"
    case fiveKilometers = "5km"
    case tenKilometers = "10km"
    
    var distanceInMeters: Double {
        switch self {
        case .twoHundredMeters: return 200
        case .fiveHundredMeters: return 500
        case .oneKilometer: return 1000
        case .twoKilometers: return 2000
        case .fiveKilometers: return 5000
        case .tenKilometers: return 10000
        }
    }
    
    var meters: Double {
        return distanceInMeters
    }
}

struct NearbyPhotosGridView: View {
    let centerLocation: CLLocationCoordinate2D?
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationManager = LocationManager()
    
    @State private var photoAssets: [PHAsset] = []
    @State private var nearbyPlaces: [Place] = []
    @State private var selectedAsset: PHAsset?
    @State private var showingImagePicker = false
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var selectedRange: DistanceRange = .fiveHundredMeters
    @State private var showingZoomedPhoto = false
    @State private var zoomedPhotoIndex: Int = 0
    @State private var showNearbyPlaces = false
    
    init(centerLocation: CLLocationCoordinate2D? = nil) {
        self.centerLocation = centerLocation
    }
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var sortedPhotoAssets: [PHAsset] {
        // Use provided center location, or fall back to user's current location
        let referenceLocation: CLLocationCoordinate2D
        if let centerLocation = centerLocation {
            referenceLocation = centerLocation
        } else if let userLocation = locationManager.lastLocation {
            referenceLocation = userLocation.coordinate
        } else {
            return photoAssets
        }
        
        // Filter by distance first, then sort
        let filteredAssets = photoAssets.filter { asset in
            let distance = distanceFromCurrent(asset: asset, currentLocation: referenceLocation)
            return distance <= selectedRange.distanceInMeters
        }
        
        return filteredAssets.sorted { asset1, asset2 in
            let distance1 = distanceFromCurrent(asset: asset1, currentLocation: referenceLocation)
            let distance2 = distanceFromCurrent(asset: asset2, currentLocation: referenceLocation)
            return distance1 < distance2
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if authorizationStatus == .authorized || authorizationStatus == .limited {
                    if centerLocation != nil || locationManager.lastLocation != nil {
                        VStack(spacing: 0) {
                            // Location info and range selector
                            VStack(spacing: 8) {
                                // Show current search center coordinates
                                if let center = centerLocation ?? locationManager.lastLocation?.coordinate {
                                    HStack {
                                        Text("Searching from:")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.4f, %.4f", center.latitude, center.longitude))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .monospaced()
                                        Spacer()
                                    }
                                }
                                
                                // Range selector
                                HStack {
                                    Text("Range:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Distance Range", selection: $selectedRange) {
                                        ForEach(DistanceRange.allCases, id: \.self) { range in
                                            Text(range.rawValue).tag(range)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .font(.caption)
                                    
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                            .background(Color(.systemBackground))
                            
                            ScrollView {
                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(Array(sortedPhotoAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                        PhotoGridCell(
                                            asset: asset,
                                            currentLocation: centerLocation ?? locationManager.lastLocation?.coordinate,
                                            onSave: { asset in
                                                savePhotoToPlaces(asset: asset)
                                            },
                                            onTap: {
                                                zoomedPhotoIndex = index
                                                showingZoomedPhoto = true
                                            }
                                        )
                                        .aspectRatio(1, contentMode: .fit)
                                    }
                                }
                                .padding(.horizontal, 1)
                            }
                        }
                        .navigationTitle("Nearby Photos")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Places") {
                                    showNearbyPlaces = true
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "location.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Location Required")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Please allow location access to see nearby photos")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Photo Access Required")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Please allow access to your photo library to see nearby photos")
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
        }
        .onAppear {
            requestPhotoAccess()
            if authorizationStatus == .authorized || authorizationStatus == .limited {
                loadPhotoAssets()
            }
            loadNearbyPlaces()
        }
        .onChange(of: selectedRange) { _ in
            loadNearbyPlaces()
        }
        .sheet(isPresented: $showNearbyPlaces) {
            NavigationView {
                NearbyPlacesList(places: nearbyPlaces, centerLocation: centerLocation)
                    .navigationTitle("Nearby Places")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showNearbyPlaces = false
                            }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showingZoomedPhoto) {
            if !sortedPhotoAssets.isEmpty && zoomedPhotoIndex < sortedPhotoAssets.count {
                PhotoZoomView(
                    assets: sortedPhotoAssets,
                    initialIndex: zoomedPhotoIndex,
                    onDismiss: {
                        showingZoomedPhoto = false
                    }
                )
            }
        }
    }
    
    private func loadNearbyPlaces() {
        guard let center = centerLocation ?? locationManager.lastLocation?.coordinate else {
            return
        }
        
        let request: NSFetchRequest<Place> = Place.fetchRequest()
        request.predicate = NSPredicate(value: true) // Fetch all places for now
        
        do {
            let allPlaces = try viewContext.fetch(request)
            nearbyPlaces = allPlaces.compactMap { place -> Place? in
                guard let location = place.location,
                      let data = location as? Data,
                      let clLocation = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CLLocation.self, from: data) else {
                    return nil
                }
                
                let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
                    .distance(from: clLocation)
                
                return distance <= selectedRange.distanceInMeters ? place : nil
            }.sorted { place1, place2 in
                guard let loc1Data = place1.location as? Data,
                      let loc2Data = place2.location as? Data,
                      let clLoc1 = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CLLocation.self, from: loc1Data),
                      let clLoc2 = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CLLocation.self, from: loc2Data) else {
                    return false
                }
                
                let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
                let dist1 = centerLocation.distance(from: clLoc1)
                let dist2 = centerLocation.distance(from: clLoc2)
                return dist1 < dist2
            }
        } catch {
            print("Error fetching nearby places: \(error)")
            nearbyPlaces = []
        }
    }
    
    private func requestPhotoAccess() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        if authorizationStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    authorizationStatus = status
                    if status == .authorized || status == .limited {
                        loadPhotoAssets()
                    }
                }
            }
        }
    }
    
    private func loadPhotoAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 500 // Limit to recent photos for performance
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            // Only include photos with location data
            if asset.location != nil {
                assets.append(asset)
            }
        }
        
        DispatchQueue.main.async {
            photoAssets = assets
        }
    }
    
    private func distanceFromCurrent(asset: PHAsset, currentLocation: CLLocationCoordinate2D) -> CLLocationDistance {
        guard let assetLocation = asset.location else {
            return CLLocationDistance.greatestFiniteMagnitude
        }
        
        let currentLocationCL = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        return currentLocationCL.distance(from: assetLocation)
    }
    
    private func savePhotoToPlaces(asset: PHAsset) {
        // Cache the photo location
        cachePhotoLocation(asset: asset)
        
        // Create a new Place with the photo
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        imageManager.requestImage(for: asset, targetSize: CGSize(width: 1024, height: 1024), contentMode: .aspectFit, options: options) { image, _ in
            guard let image = image,
                  let imageData = image.jpegData(compressionQuality: 0.8) else {
                return
            }
            
            DispatchQueue.main.async {
                let newPlace = Place(context: viewContext)
                newPlace.imageData = imageData
                newPlace.dateAdded = asset.creationDate ?? Date()
                
                if let location = asset.location {
                    let locationData = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false)
                    newPlace.location = locationData
                }
                
                newPlace.post = "Added from photo library"
                
                do {
                    try viewContext.save()
                    print("Photo saved to places successfully")
                } catch {
                    print("Failed to save photo to places: \(error)")
                }
            }
        }
    }
    
    private func cachePhotoLocation(asset: PHAsset) {
        guard let location = asset.location else { return }
        
        // Check if we already have this photo cached
        let fetchRequest: NSFetchRequest<PhotoLocationCache> = PhotoLocationCache.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "photoId == %@", asset.localIdentifier)
        
        do {
            let existingCache = try viewContext.fetch(fetchRequest)
            let cache: PhotoLocationCache
            
            if let existing = existingCache.first {
                cache = existing
            } else {
                cache = PhotoLocationCache(context: viewContext)
                cache.photoId = asset.localIdentifier
            }
            
            cache.location = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false)
            cache.lastUpdated = Date()
            
            try viewContext.save()
        } catch {
            print("Failed to cache photo location: \(error)")
        }
    }
}

struct PhotoGridCell: View {
    let asset: PHAsset
    let currentLocation: CLLocationCoordinate2D?
    let onSave: (PHAsset) -> Void
    let onTap: () -> Void
    
    @State private var image: UIImage?
    @State private var showingSaveButton = false
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                    )
            }
            
            // Distance overlay
            if let currentLocation = currentLocation,
               let assetLocation = asset.location {
                VStack {
                    Spacer()
                    HStack {
                        Text(distanceText(from: currentLocation, to: assetLocation.coordinate))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        // Save button
                        Button(action: {
                            onSave(asset)
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }
            }
        }
        .onTapGesture {
            onTap()
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
        
        imageManager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFill, options: options) { loadedImage, _ in
            DispatchQueue.main.async {
                image = loadedImage
            }
        }
    }
    
    private func distanceText(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> String {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let distance = fromLocation.distance(from: toLocation)
        
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

struct PhotoZoomView: View {
    let assets: [PHAsset]
    @State private var currentIndex: Int
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var currentImage: UIImage?
    @State private var isLoadingImage = false
    @State private var showingShareSheet = false
    @State private var shareText = ""
    @State private var dragOffset: CGSize = .zero
    
    init(assets: [PHAsset], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.assets = assets
        self._currentIndex = State(initialValue: initialIndex)
        self.onDismiss = onDismiss
    }
    
    var currentAsset: PHAsset? {
        guard currentIndex >= 0 && currentIndex < assets.count else { return nil }
        return assets[currentIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack {
                Button("Done") {
                    onDismiss()
                }
                .foregroundColor(.white)
                .padding()
                
                Spacer()
                
                if let asset = currentAsset {
                    HStack(spacing: 12) {
                        Button(action: {
                            sharePhoto(asset: asset)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            openInPhotosApp(asset: asset)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "photo")
                                Text("Open")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
            .background(Color.black)
            
            // Photo area
            if let image = currentImage {
                TabView(selection: $currentIndex) {
                    ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                        ZoomableImageView(asset: asset)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onChange(of: currentIndex) { newIndex in
                    loadImageForIndex(newIndex)
                }
                .background(Color.black)
            } else {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                Spacer()
            }
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
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
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(text: shareText)
        }
        .onAppear {
            loadImageForIndex(currentIndex)
        }
    }
    
    private func loadImageForIndex(_ index: Int) {
        guard index >= 0 && index < assets.count else { return }
        let asset = assets[index]
        
        isLoadingImage = true
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        let targetSize = CGSize(width: UIScreen.main.bounds.width * UIScreen.main.scale,
                               height: UIScreen.main.bounds.height * UIScreen.main.scale)
        
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, _ in
            DispatchQueue.main.async {
                currentImage = image
                isLoadingImage = false
            }
        }
    }
    
    private func sharePhoto(asset: PHAsset) {
        // First create a Place from this photo
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        imageManager.requestImage(for: asset, targetSize: CGSize(width: 1024, height: 1024), contentMode: .aspectFit, options: options) { image, _ in
            guard let image = image,
                  let imageData = image.jpegData(compressionQuality: 0.8) else {
                return
            }
            
            DispatchQueue.main.async {
                // Create new Place
                let newPlace = Place(context: viewContext)
                newPlace.imageData = imageData
                newPlace.dateAdded = asset.creationDate ?? Date()
                
                if let location = asset.location {
                    let locationData = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false)
                    newPlace.location = locationData
                }
                
                // Add metadata about sharing
                var postText = "Shared from photo library"
                if let creationDate = asset.creationDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    postText += " • Taken: \(formatter.string(from: creationDate))"
                }
                newPlace.post = postText
                
                do {
                    try viewContext.save()
                    
                    // Now create the share URL using the new Place
                    createShareURL(for: newPlace)
                } catch {
                    print("Failed to save photo as place: \(error)")
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
        
        shareText = "Check out this photo on Reminora!\n\n\(reminoraLink)"
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
    
    private func openInPhotosApp(asset: PHAsset) {
        // Try to open the specific photo using the asset's local identifier
        let localId = asset.localIdentifier
        if let url = URL(string: "photos://asset?id=\(localId)") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
        
        // Fallback to generic Photos app opening
        if let photosUrl = URL(string: "photos-redirect://") {
            if UIApplication.shared.canOpenURL(photosUrl) {
                UIApplication.shared.open(photosUrl)
            }
        }
    }
}

struct ZoomableImageView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale *= delta
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < 1.0 {
                                        withAnimation(.spring()) {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                    } else if scale > 5.0 {
                                        withAnimation(.spring()) {
                                            scale = 5.0
                                        }
                                    }
                                },
                            
                            DragGesture()
                                .onChanged { value in
                                    let newOffset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    
                                    // Only allow panning when zoomed in
                                    if scale > 1.0 {
                                        // Calculate bounds based on scale and image size
                                        let maxOffsetX = (geometry.size.width * (scale - 1)) / 2
                                        let maxOffsetY = (geometry.size.height * (scale - 1)) / 2
                                        
                                        offset = CGSize(
                                            width: max(-maxOffsetX, min(maxOffsetX, newOffset.width)),
                                            height: max(-maxOffsetY, min(maxOffsetY, newOffset.height))
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    if scale > 1.0 {
                                        lastOffset = offset
                                    } else {
                                        // Reset position when not zoomed
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1.0 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                            }
                        }
                    }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        options.resizeMode = .exact
        
        let targetSize = CGSize(width: UIScreen.main.bounds.width * UIScreen.main.scale,
                               height: UIScreen.main.bounds.height * UIScreen.main.scale)
        
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { loadedImage, _ in
            DispatchQueue.main.async {
                image = loadedImage
            }
        }
    }
}

// MARK: - Nearby Places List

struct NearbyPlacesList: View {
    let places: [Place]
    let centerLocation: CLLocationCoordinate2D?
    
    var body: some View {
        List {
            if places.isEmpty {
                Text("No nearby places found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(places, id: \.objectID) { place in
                    NearbyPlaceRow(place: place, centerLocation: centerLocation)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct NearbyPlaceRow: View {
    let place: Place
    let centerLocation: CLLocationCoordinate2D?
    
    private var distance: String {
        guard let centerLocation = centerLocation,
              let locationData = place.location as? Data,
              let clLocation = try? NSKeyedUnarchiver.unarchivedObject(ofClass: CLLocation.self, from: locationData) else {
            return ""
        }
        
        let center = CLLocation(latitude: centerLocation.latitude, longitude: centerLocation.longitude)
        let distanceMeters = center.distance(from: clLocation)
        
        if distanceMeters < 1000 {
            return String(format: "%.0fm", distanceMeters)
        } else {
            return String(format: "%.1fkm", distanceMeters / 1000)
        }
    }
    
    var body: some View {
        HStack {
            // Thumbnail
            if let imageData = place.imageData {
                Image(uiImage: UIImage(data: imageData) ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 56, height: 56)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let post = place.post, !post.isEmpty {
                    Text(post)
                        .font(.headline)
                        .lineLimit(2)
                } else {
                    Text("Photo")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    if let dateAdded = place.dateAdded {
                        Text(dateAdded, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !distance.isEmpty {
                        Text("• \(distance)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NearbyPhotosGridView(centerLocation: nil)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}