import Photos
import PhotosUI
import SwiftUI
import CoreData
import CoreLocation

struct NearbyPhotosGridView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationManager = LocationManager()
    
    @State private var photoAssets: [PHAsset] = []
    @State private var selectedAsset: PHAsset?
    @State private var showingImagePicker = false
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var sortedPhotoAssets: [PHAsset] {
        guard let userLocation = locationManager.lastLocation else {
            return photoAssets
        }
        
        return photoAssets.sorted { asset1, asset2 in
            let distance1 = distanceFromCurrent(asset: asset1, currentLocation: userLocation.coordinate)
            let distance2 = distanceFromCurrent(asset: asset2, currentLocation: userLocation.coordinate)
            return distance1 < distance2
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if authorizationStatus == .authorized || authorizationStatus == .limited {
                    if locationManager.lastLocation != nil {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(sortedPhotoAssets, id: \.localIdentifier) { asset in
                                    PhotoGridCell(
                                        asset: asset,
                                        currentLocation: locationManager.lastLocation?.coordinate,
                                        onSave: { asset in
                                            savePhotoToPlaces(asset: asset)
                                        }
                                    )
                                    .aspectRatio(1, contentMode: .fit)
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                        .navigationTitle("Nearby Photos")
                        .navigationBarTitleDisplayMode(.large)
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

#Preview {
    NearbyPhotosGridView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}