import CoreData
import MapKit
import SwiftUI

struct MapView: View {
  @Environment(\.managedObjectContext) private var viewContext

  @Binding var region: MKCoordinateRegion
  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Place.dateAdded, ascending: true)],
    animation: .default)
  private var items: FetchedResults<Place>

  @State private var searchText: String = ""
  @State private var selectedPlace: Place?

  @State var showSheet: Bool = false
  var locationManager: LocationManager

  let minHeight: CGFloat = 50
  let maxHeight: CGFloat = 400

  @State private var sheetHeight: CGFloat = 50
  @GestureState private var dragOffset: CGFloat = 0

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
    // Sort by distance from map center
    return places.sorted { a, b in
      let aCoord = coordinate(item: a)
      let bCoord = coordinate(item: b)
      let aDist = distance(from: center, to: aCoord)
      let bDist = distance(from: center, to: bCoord)
      return aDist < bDist
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
      .ignoresSafeArea()
      .onAppear {
        // Center on user location if available and no places
        if let userLoc = locationManager.lastLocation {
          region.center = userLoc.coordinate
        }
      }

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
        .ignoresSafeArea()
        .onAppear {
          // if let first = filteredItems.first {
          //     region.center = coordinate(for: first)
          // }

          // Center on user location if available and no places
          if let userLoc = locationManager.lastLocation {
            region.center = userLoc.coordinate
          }
        }

        // Sliding pane
        GeometryReader { geometry in
          let safeAreaBottom = geometry.safeAreaInsets.bottom

          VStack {
            Capsule()
              .fill(Color.secondary)
              .frame(width: 40, height: 6)
              .padding(.top, 8)
            Spacer()
            // Move the list to a separate control
            PlaceListView(
              items: filteredItems,
              onSelect: { item in
                selectedPlace = item
                showSheet = false
                let coord = coordinate(item: item)
                region.center = coord
              },
              onDelete: deleteItems
            )
          }
          .frame(
            width: geometry.size.width,
            // safe area is approximation, make actual size bigger
            height: maxHeight + safeAreaBottom,
            alignment: .top
          )
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(Color(.systemBackground))
              .shadow(radius: 5)
          )
          .offset(
            y: geometry.size.height - sheetHeight - safeAreaBottom + dragOffset
          )
          .gesture(
            DragGesture()
              .updating($dragOffset) { value, state, _ in
                state = value.translation.height
              }
              .onEnded { value in
                let newHeight = sheetHeight - value.translation.height
                // zero offset is position at minHeight
                // we want to limit offset to maxHeight - minHeight
                sheetHeight = min(maxHeight, max(newHeight, minHeight))
              }
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
