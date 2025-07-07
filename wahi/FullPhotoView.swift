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
  @FocusState private var isTextFieldFocused: Bool
  @State private var keyboardHeight: CGFloat = 0

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      VStack(spacing: 0) {
        Spacer()
        if let image = image {
          Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: 350)
            .background(Color.black)
        } else {
          ProgressView()
            .frame(height: 350)
        }
        Spacer()
        VStack(spacing: 0) {
          HStack {
            TextField("Add a caption...", text: $caption)
              .padding(12)
              .background(Color(.systemGray6))
              .cornerRadius(8)
              .padding([.horizontal, .bottom], 16)
              .focused($isTextFieldFocused)
          }
          .background(Color.black.opacity(0.8))
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
            .padding([.horizontal, .bottom], 16)
            .allowsHitTesting(false)
          }
        }
      }
      .frame(width: 400, height: 650)  // Fixed size for the view
      .padding(.bottom, keyboardHeight)
      .animation(.easeOut(duration: 0.25), value: keyboardHeight)
    }
    .onAppear {
      loadFullImage()
      loadPhotoLocation()
      // Keyboard notifications
      NotificationCenter.default.addObserver(
        forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main
      ) { notif in
        if let frame = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
          keyboardHeight = frame.height
        }
      }
      NotificationCenter.default.addObserver(
        forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main
      ) { _ in
        keyboardHeight = 0
      }
    }
    .onDisappear {
      NotificationCenter.default.removeObserver(self)
    }
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button(action: {
          if let image = image {
            saveImageDataToCoreData(image: image, caption: caption)
          }
          onBack()
        }) {
          Label("Done", systemImage: "checkmark")
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
    }
  }

  private func saveImageDataToCoreData(
    image: UIImage, caption: String) {
    guard let data = image.jpegData(compressionQuality: 0.9) else { return }
    PersistenceController.shared.saveImageDataToCoreData(
      imageData: data,
      url: nil,
      contentText: caption
    )
  }
}

// Helper to use CLLocationCoordinate2D as annotation item
extension CLLocationCoordinate2D: Identifiable {
  public var id: String { "\(latitude),\(longitude)" }
}
