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
