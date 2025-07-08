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
  @State private var nearbyPlaces: [MKMapItem] = []
  @State private var isLoadingPlaces = false

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      ScrollView {
        VStack(spacing: 0) {
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
          
          VStack(spacing: 0) {
            HStack {
              TextField("Add a caption...", text: $caption, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding([.horizontal, .bottom], 16)
                .focused($isTextFieldFocused)
                .toolbar {
                  ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                      isTextFieldFocused = false
                    }
                  }
                }
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
            .padding(.horizontal, 16)
            .allowsHitTesting(false)
            
            // List of nearby places
            VStack(alignment: .leading, spacing: 0) {
              Text("Nearby Places")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
              
              LazyVStack(spacing: 6) {
                if isLoadingPlaces {
                  HStack {
                    ProgressView()
                      .scaleEffect(0.8)
                    Text("Loading nearby places...")
                      .font(.caption)
                      .foregroundColor(.white.opacity(0.7))
                  }
                  .padding(.horizontal, 16)
                  .padding(.vertical, 8)
                } else {
                  ForEach(nearbyPlaces.prefix(20), id: \.self) { mapItem in
                    HStack(spacing: 10) {
                      Image(systemName: iconForPlaceType(mapItem.pointOfInterestCategory))
                        .frame(width: 30, height: 30)
                        .foregroundColor(.blue)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                      
                      VStack(alignment: .leading, spacing: 1) {
                        Text(mapItem.name ?? "Unknown Place")
                          .font(.caption)
                          .fontWeight(.medium)
                          .foregroundColor(.white)
                          .lineLimit(1)
                        
                        if let category = mapItem.pointOfInterestCategory {
                          Text(categoryDisplayName(category))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        }
                      }
                      
                      Spacer()
                      
                      if let coordinate = mapItem.placemark.location?.coordinate,
                         let photoCoord = photoLocation {
                        Text("\(Int(distance(from: photoCoord, to: coordinate)))m")
                          .font(.caption2)
                          .foregroundColor(.white.opacity(0.7))
                      }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 3)
                  }
                }
              }
            }
            .padding(.bottom, 16)
            }
          }
        }
      }
      .padding(.bottom, keyboardHeight)
      .animation(.easeOut(duration: 0.25), value: keyboardHeight)
    }
    .onAppear {
      loadFullImage()
      loadPhotoLocation()
      searchNearbyPlaces()
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
          onBack()
        }) {
          Text("Cancel")
        }
      }
      
      ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: {
          if let image = image {
            saveImageDataToCoreData(image: image, caption: caption)
          }
          onBack()
        }) {
          Text("Done")
            .fontWeight(.semibold)
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

  private func searchNearbyPlaces() {
    guard let coordinate = photoLocation else { return }
    
    isLoadingPlaces = true
    
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = "restaurant cafe store gas station hotel"
    request.region = MKCoordinateRegion(
      center: coordinate,
      latitudinalMeters: 500, // 500m radius for more specific results
      longitudinalMeters: 500
    )
    request.resultTypes = [.pointOfInterest]
    
    let search = MKLocalSearch(request: request)
    search.start { response, error in
      DispatchQueue.main.async {
        isLoadingPlaces = false
        if let response = response {
          // Filter out generic results and sort by distance
          let filteredPlaces = response.mapItems.filter { item in
            guard let name = item.name,
                  !name.lowercased().contains("points of interest"),
                  !name.lowercased().contains("afewpointsofinterest") else {
              return false
            }
            return true
          }.sorted { item1, item2 in
            let dist1 = item1.placemark.location?.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) ?? Double.infinity
            let dist2 = item2.placemark.location?.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) ?? Double.infinity
            return dist1 < dist2
          }
          nearbyPlaces = Array(filteredPlaces.prefix(20))
        }
      }
    }
  }
  
  private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
    let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
    let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
    return loc1.distance(from: loc2)
  }
  
  private func iconForPlaceType(_ category: MKPointOfInterestCategory?) -> String {
    guard let category = category else { return "mappin" }
    
    switch category {
    case .restaurant: return "fork.knife"
    case .cafe: return "cup.and.saucer"
    case .hotel: return "bed.double"
    case .gasStation: return "fuelpump"
    case .store: return "bag"
    case .hospital: return "cross.fill"
    case .school: return "graduationcap"
    case .museum: return "building.columns"
    case .library: return "books.vertical"
    case .park: return "tree"
    case .beach: return "beach.umbrella"
    case .amusementPark: return "ferriswheel"
    case .theater: return "theaters"
    case .movieTheater: return "tv"
    case .bank: return "building.2"
    case .atm: return "dollarsign.circle"
    case .pharmacy: return "cross.case"
    case .airport: return "airplane"
    case .publicTransport: return "bus"
    case .parking: return "parkingsign"
    default: return "mappin"
    }
  }
  
  private func categoryDisplayName(_ category: MKPointOfInterestCategory) -> String {
    switch category {
    case .restaurant: return "Restaurant"
    case .cafe: return "Cafe"
    case .hotel: return "Hotel"
    case .gasStation: return "Gas Station"
    case .store: return "Store"
    case .hospital: return "Hospital"
    case .school: return "School"
    case .museum: return "Museum"
    case .library: return "Library"
    case .park: return "Park"
    case .beach: return "Beach"
    case .amusementPark: return "Amusement Park"
    case .theater: return "Theater"
    case .movieTheater: return "Movie Theater"
    case .bank: return "Bank"
    case .atm: return "ATM"
    case .pharmacy: return "Pharmacy"
    case .airport: return "Airport"
    case .publicTransport: return "Public Transport"
    case .parking: return "Parking"
    default: return "Point of Interest"
    }
  }

  private func saveImageDataToCoreData(
    image: UIImage, caption: String) {
    guard let data = image.jpegData(compressionQuality: 0.9) else { return }
    
    // Use the location from the photo asset if available
    let location = asset.location
    
    PersistenceController.shared.saveImageDataToCoreData(
      imageData: data,
      location: location,
      contentText: caption.isEmpty ? nil : caption
    )
  }
}

// Helper to use CLLocationCoordinate2D as annotation item
extension CLLocationCoordinate2D: Identifiable {
  public var id: String { "\(latitude),\(longitude)" }
}
