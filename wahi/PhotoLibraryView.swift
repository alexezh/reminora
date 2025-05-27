import CoreData
import MapKit
import Photos
import PhotosUI
import SwiftUI

// New view for displaying all photos from the user's photo library
struct PhotoLibraryView: View {
    @Binding var isPresented: Bool
    @State private var assets: [PHAsset] = []

    var body: some View {
        NavigationView {
            ScrollView {
                if assets.isEmpty {
                    ProgressView("Loading photos...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Display photos in a grid
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3), spacing: 2) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            PhotoThumbnailView(asset: asset)
                                .aspectRatio(1, contentMode: .fill)
                        }
                    }
                    .padding(2)
                }
            }
            .navigationTitle("Photo Library")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                fetchPhotos()
            }
        }
    }

    private func fetchPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var fetched: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            fetched.append(asset)
        }
        assets = fetched
    }
}

struct PhotoThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.2)
                    .overlay(
                        ProgressView()
                    )
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.resizeMode = .exact
        let size = CGSize(width: 300, height: 300) // Square target size

        manager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill, // Crop to fill the square
            options: options
        ) { img, _ in
            if let img = img {
                self.image = img
            }
        }
    }
}
