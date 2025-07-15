import CoreData
import MapKit
import Photos
import PhotosUI
import SwiftUI

struct PhotoLibraryView: View {
  @Binding var isPresented: Bool
  @State private var assets: [PHAsset] = []
  @State private var selectedAsset: PHAsset? = nil

  var body: some View {
    NavigationView {
      Group {
        if let selectedAsset = selectedAsset {
          FullPhotoView(asset: selectedAsset) {
            self.selectedAsset = nil
            self.isPresented = false
          }
        } else {
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
                    .onTapGesture {
                      selectedAsset = asset
                    }
                }
              }
              .padding(2)
            }
          }
        }
      }
      .navigationTitle(selectedAsset == nil ? "Photo Library" : "")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          if selectedAsset == nil {
            Button("Close") {
              isPresented = false
            }
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
  let isSelected: Bool?
  let onTap: (() -> Void)?
  @State private var image: UIImage? = nil

  // Convenience initializer for PhotoLibraryView (backward compatibility)
  init(asset: PHAsset) {
    self.asset = asset
    self.isSelected = nil
    self.onTap = nil
  }
  
  // Full initializer for SwipePhotoView
  init(asset: PHAsset, isSelected: Bool, onTap: @escaping () -> Void) {
    self.asset = asset
    self.isSelected = isSelected
    self.onTap = onTap
  }

  var body: some View {
    Group {
      if let image = image {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .conditionalModifier(isSelected != nil) { view in
            // SwipePhotoView style: fixed size with corner radius and selection border
            view
              .frame(width: 50, height: 50)
              .clipped()
              .cornerRadius(8)
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke((isSelected == true) ? Color.white : Color.clear, lineWidth: 2)
              )
              .scaleEffect((isSelected == true) ? 1.1 : 1.0)
              .animation(.easeInOut(duration: 0.2), value: isSelected)
          }
      } else {
        if isSelected != nil {
          // SwipePhotoView style loading state
          Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 50, height: 50)
            .cornerRadius(8)
            .overlay(
              ProgressView()
                .scaleEffect(0.7)
            )
        } else {
          // PhotoLibraryView style loading state
          Color.gray.opacity(0.2)
            .overlay(
              ProgressView()
            )
        }
      }
    }
    .onTapGesture {
      onTap?()
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
    
    // Use different sizes based on context
    let size = if isSelected != nil {
      CGSize(width: 150, height: 150)  // Small thumbnails for SwipePhotoView
    } else {
      CGSize(width: 300, height: 300)  // Larger thumbnails for PhotoLibraryView
    }

    manager.requestImage(
      for: asset,
      targetSize: size,
      contentMode: .aspectFill,
      options: options
    ) { img, _ in
      if let img = img {
        DispatchQueue.main.async {
          self.image = img
        }
      }
    }
  }
}

// Helper extension for conditional modifiers
extension View {
  @ViewBuilder
  func conditionalModifier<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
    if condition {
      transform(self)
    } else {
      self
    }
  }
}
