import CoreData
import MapKit
import SwiftUI

func convertRegionToRect(from region: MKCoordinateRegion) -> MKMapRect {
    let center = MKMapPoint(region.center)

    let span = region.span
    let deltaLat = span.latitudeDelta
    let deltaLon = span.longitudeDelta

    let topLeftCoord = CLLocationCoordinate2D(
        latitude: region.center.latitude + (deltaLat / 2),
        longitude: region.center.longitude - (deltaLon / 2)
    )

    let bottomRightCoord = CLLocationCoordinate2D(
        latitude: region.center.latitude - (deltaLat / 2),
        longitude: region.center.longitude + (deltaLon / 2)
    )

    let topLeftPoint = MKMapPoint(topLeftCoord)
    let bottomRightPoint = MKMapPoint(bottomRightCoord)

    let origin = MKMapPoint(x: min(topLeftPoint.x, bottomRightPoint.x),
                            y: min(topLeftPoint.y, bottomRightPoint.y))
    let size = MKMapSize(width: abs(topLeftPoint.x - bottomRightPoint.x),
                         height: abs(topLeftPoint.y - bottomRightPoint.y))

    return MKMapRect(origin: origin, size: size)
}

struct MapView: View {
  @Environment(\.managedObjectContext) private var viewContext

  @State private var region = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
  )
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Place.dateAdded, ascending: true)],
    animation: .default)
  private var items: FetchedResults<Place>

  @State private var searchText: String = ""
  @State private var selectedPlace: Place?

  @State var showSheet: Bool = false
  @StateObject private var locationManager = LocationManager()

  let minHeight: CGFloat = 50
  let maxHeight: CGFloat = 400

  @State private var sheetHeight: CGFloat = 150
  @GestureState private var dragOffset: CGFloat = 0
  @State private var shouldSortByDistance: Bool = false
  @State private var showCenterButton: Bool = false
  @State private var showPlaceDetail: Bool = false
  @State private var lastTappedPlace: Place?
  @State private var lastTapTime: Date = Date()

  var filteredItems: [Place] {
    let center = region.center
    let places: [Place]
    if searchText.isEmpty {
      places = Array(items)
    } else {
      places = items.filter { item in
        (item.post?.localizedCaseInsensitiveContains(searchText) ?? false)
          || (item.url?.localizedCaseInsensitiveContains(searchText) ?? false)
      }
    }
    // Sort by distance from map center only when explicitly requested
    if shouldSortByDistance {
      return places.sorted { a, b in
        let aCoord = coordinate(item: a)
        let bCoord = coordinate(item: b)
        let aDist = distance(from: center, to: aCoord)
        let bDist = distance(from: center, to: bCoord)
        return aDist < bDist
      }
    } else {
      // Return items sorted by date added (most recent first)
      return places.sorted { a, b in
        (a.dateAdded ?? Date.distantPast) > (b.dateAdded ?? Date.distantPast)
      }
    }
  }

  // Helper to calculate distance between two coordinates (in meters)
  private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)
    -> CLLocationDistance
  {
    let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
    let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
    return loc1.distance(from: loc2)
  }

  var body: some View {

    ZStack {
      // Map with user location
      Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: filteredItems) {
        item in
        MapAnnotation(coordinate: coordinate(item: item)) {
          Button(action: {
            selectedPlace = item
            showSheet = true
          }) {
            Image(systemName: "mappin.circle.fill")
              .font(.title)
              .foregroundColor(.red)
          }
        }
      }
      
      // Center button overlay
      if showCenterButton {
        VStack {
          HStack {
            Spacer()
            Button(action: {
              shouldSortByDistance = true
              showCenterButton = false
            }) {
              Text("Center")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .clipShape(Capsule())
                .shadow(radius: 4)
            }
            .padding(.trailing, 16)
            .padding(.top, 60)
          }
          Spacer()
        }
      }

      // Sliding pane
      GeometryReader { geometry in
        let safeAreaBottom = geometry.safeAreaInsets.bottom

        ScrollViewReader { proxy in
          VStack {
            Capsule()
              .fill(Color.secondary)
              .frame(width: 40, height: 6)
              .padding(.top, 8)
            Spacer()
            PlaceListView(
              items: filteredItems,
              selectedPlace: selectedPlace,
              onSelect: { item in
                let now = Date()
                let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
                
                // Check if this is a second tap on the same item within 2 seconds
                if let lastPlace = lastTappedPlace, 
                   lastPlace.objectID == item.objectID, 
                   timeSinceLastTap < 2.0 {
                    // Double tap detected - show detail view
                    showPlaceDetail = true
                } else {
                    // First tap or different item - navigate map
                    selectedPlace = item
                    showSheet = false
                    showCenterButton = true
                    shouldSortByDistance = false // Reset sorting when selecting photo
                    
                    // Get coordinate of selected place
                    let coord = coordinate(item: item)
                    
                    // Always animate to the selected photo location with appropriate zoom
                    let newRegion = MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(
                            latitudeDelta: 0.01, // Zoom in closer to show detail
                            longitudeDelta: 0.01
                        )
                    )
                    withAnimation(.easeInOut(duration: 1.0)) {
                        region = newRegion
                    }
                }
                
                // Update last tapped info
                lastTappedPlace = item
                lastTapTime = now
              },
              onDelete: deleteItems
            )
          }
          .frame(
            width: geometry.size.width,
            height: maxHeight,
            alignment: .top
          )
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(Color(.systemBackground))
              .shadow(radius: 5)
          )
          .offset(
            y: geometry.size.height - sheetHeight - 100 + dragOffset
          )
          .gesture(
            DragGesture()
              .updating($dragOffset) { value, state, _ in
                state = value.translation.height
              }
              .onEnded { value in
                let newHeight = sheetHeight - value.translation.height
                sheetHeight = min(maxHeight, max(newHeight, minHeight))
              }
          )
          // Scroll to selectedPlace when it changes
          .onChange(of: selectedPlace) { place in
            if let place = place {
              withAnimation {
                proxy.scrollTo(place.objectID, anchor: .center)
              }
            }
          }
        }
      }
    }
    .sheet(isPresented: $showPlaceDetail) {
      if let selectedPlace = selectedPlace {
        NavigationView {
          PlaceDetailView(
            place: selectedPlace,
            allPlaces: Array(items),
            onBack: {
              showPlaceDetail = false
            }
          )
        }
      }
    }
    .ignoresSafeArea()
    .onAppear {
      // if let first = filteredItems.first {
      //     region.center = coordinate(for: first)
      // }

      // Center on user location if available and no places
      // if let userLoc = locationManager.lastLocation {
      //   region.center = userLoc.coordinate
      // }
    }
    .onReceive(locationManager.$lastLocation) { location in
      guard let location = location else { return }
      DispatchQueue.main.async {
        print("updating location")
        withAnimation(.easeInOut(duration: 1.0)) {
          region = MKCoordinateRegion(
            center: location.coordinate,
            span: region.span  // or any span you want to preserve
          )
        }
      }
    }
  }

  // Helper to get coordinate from Place
  private func coordinate(item: Place) -> CLLocationCoordinate2D {
    if let locationData = item.value(forKey: "location") as? Data,
      let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData)
        as? CLLocation
    {
      return location.coordinate
    }
    // Default to San Francisco if no location
    return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
  }

  private func addItem() {
    withAnimation {
      let newItem = Place(context: viewContext)
      newItem.dateAdded = Date()
      newItem.url = nil  // Or set a default image URL if desired

      do {
        try viewContext.save()
      } catch {
        let nsError = error as NSError
        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
      }
    }
  }

  private func deleteItems(offsets: IndexSet) {
    withAnimation {
      offsets.map { items[$0] }.forEach(viewContext.delete)

      do {
        try viewContext.save()
      } catch {
        let nsError = error as NSError
        fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
      }
    }
  }

}
