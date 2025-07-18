import CoreData
import MapKit
import Photos
import PhotosUI
import SwiftUI

struct FullPhotoView: View {
  let asset: PHAsset
  let onBack: () -> Void
  @State private var image: UIImage? = nil
  @State private var caption: String = ""
  @State private var photoLocation: CLLocationCoordinate2D?
  @State private var isPrivate: Bool = false
  @FocusState private var isTextFieldFocused: Bool

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      
      VStack(spacing: 0) {
        // Photo at top - fixed position
        if let image = image {
          Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: 300)
            .background(Color.black)
        } else {
          ProgressView()
            .frame(height: 300)
        }
        
        // Caption text field and privacy toggle
        VStack(spacing: 0) {
          HStack {
            TextField("Add a caption...", text: $caption, axis: .vertical)
              .lineLimit(5...10)
              .padding(16)
              .background(Color(.systemGray6))
              .cornerRadius(12)
              .padding([.horizontal, .bottom], 16)
              .focused($isTextFieldFocused)
          }
          
          // Private/Public toggle
          HStack {
            Toggle(isOn: $isPrivate) {
              HStack(spacing: 6) {
                Image(systemName: isPrivate ? "lock.fill" : "globe")
                  .foregroundColor(isPrivate ? .orange : .green)
                Text(isPrivate ? "Private" : "Public")
                  .foregroundColor(isPrivate ? .orange : .green)
              }
              .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            Spacer()
          }
          .background(Color.black.opacity(0.8))
        }
        
        // Scrollable content below
        ScrollView {
          VStack(spacing: 0) {
            if let coordinate = photoLocation {
              Map(
                coordinateRegion: .constant(
                  MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                  )),
                interactionModes: [],
                annotationItems: [coordinate]
              ) { coord in
                MapMarker(coordinate: coord, tint: .red)
              }
              .frame(height: 180)
              .cornerRadius(12)
              .padding(.horizontal, 16)
              .allowsHitTesting(false)
              .padding(.bottom, 16)
            }
            
            // Comments section placeholder - will be implemented when adding comments to photos
            VStack(alignment: .leading, spacing: 8) {
              Text("Comments")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
              
              Text("Comments will be available when this photo is shared.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
          }
        }
      }
    }
    .onAppear {
      loadFullImage()
      loadPhotoLocation()
    }
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button(action: {
          onBack()
        }) {
          Text("Cancel")
        }
      }
      
      ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: {
          if let image = image {
            saveImageDataToCoreData(image: image, caption: caption, isPrivate: isPrivate)
          }
          onBack()
        }) {
          Text("Done")
            .fontWeight(.semibold)
        }
      }
      
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") {
          isTextFieldFocused = false
        }
      }
    }
  }

  private func loadFullImage() {
    let manager = PHImageManager.default()
    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isSynchronous = false
    options.resizeMode = .none
    let screen = UIScreen.main.bounds
    let size = CGSize(
      width: screen.width * UIScreen.main.scale, height: screen.height * UIScreen.main.scale)

    manager.requestImage(
      for: asset,
      targetSize: size,
      contentMode: .aspectFit,
      options: options
    ) { img, _ in
      if let img = img {
        self.image = img
      }
    }
  }

  private func loadPhotoLocation() {
    if let loc = asset.location {
      photoLocation = loc.coordinate
      print("Photo location loaded: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
    } else {
      print("No location data found in photo asset")
    }
  }


  private func saveImageDataToCoreData(
    image: UIImage, caption: String, isPrivate: Bool) {
    guard let data = image.jpegData(compressionQuality: 0.9) else { return }
    
    // Use the location from the photo asset if available
    let location = asset.location
    
    PersistenceController.shared.saveImageDataToCoreData(
      imageData: data,
      location: location,
      contentText: caption.isEmpty ? nil : caption,
      isPrivate: isPrivate
    )
  }
}

// Helper to use CLLocationCoordinate2D as annotation item
extension CLLocationCoordinate2D: Identifiable {
  public var id: String { "\(latitude),\(longitude)" }
}
