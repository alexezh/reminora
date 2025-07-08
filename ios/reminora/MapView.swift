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
  let oneThirdHeight: CGFloat = UIScreen.main.bounds.height * 0.33
  let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.8

  @State private var sheetHeight: CGFloat = UIScreen.main.bounds.height * 0.33
  @GestureState private var dragOffset: CGFloat = 0
  @State private var shouldSortByDistance: Bool = false
  @State private var showCenterButton: Bool = false
  @State private var showPlaceDetail: Bool = false
  @State private var lastTappedPlace: Place?
  @State private var lastTapTime: Date = Date()
  @State private var shouldScrollToSelected: Bool = true
  @State private var isSearching: Bool = false

  var filteredItems: [Place] {
    let center = region.center
    let places: [Place]
    
    // If we're in search mode (after a geo search), show all places
    // If we have search text but haven't performed geo search, filter by text
    if isSearching || (!searchText.isEmpty && !isSearching) {
      // After geo search, show all places sorted by distance from search location
      places = Array(items)
    } else if !searchText.isEmpty {
      // Text search in place names/posts
      places = items.filter { item in
        (item.post?.localizedCaseInsensitiveContains(searchText) ?? false)
          || (item.url?.localizedCaseInsensitiveContains(searchText) ?? false)
      }
    } else {
      places = Array(items)
    }
    
    // Sort by distance from map center when explicitly requested OR after geo search
    if shouldSortByDistance || isSearching {
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
              shouldScrollToSelected = true // Allow scrolling when using center button
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
          VStack(spacing: 0) {
            // Drag handle
            Capsule()
              .fill(Color.secondary)
              .frame(width: 40, height: 6)
              .padding(.top, 8)
              .padding(.bottom, 8)
            
            // Search bar - only show when pane is at max height
            if sheetHeight >= maxHeight - 50 {
              HStack {
                Image(systemName: "magnifyingglass")
                  .foregroundColor(.secondary)
                  .padding(.leading, 8)
                
                TextField("Search places...", text: $searchText)
                  .textFieldStyle(RoundedBorderTextFieldStyle())
                  .onSubmit {
                    performGeoSearch()
                  }
                
                if !searchText.isEmpty {
                  Button("Clear") {
                    searchText = ""
                    isSearching = false
                    shouldSortByDistance = false
                  }
                  .foregroundColor(.blue)
                  .padding(.trailing, 8)
                }
              }
              .padding(.horizontal, 16)
              .padding(.bottom, 12)
              .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Places list
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
                    shouldScrollToSelected = false // Prevent auto-scroll when selecting from list
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
              onDelete: deleteItems,
              mapCenter: region.center
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
                let currentHeight = sheetHeight
                let translation = value.translation.height
                
                print("Drag ended: currentHeight=\(currentHeight), translation=\(translation)")
                print("Heights: min=\(minHeight), oneThird=\(oneThirdHeight), max=\(maxHeight)")
                
                withAnimation(.easeInOut(duration: 0.3)) {
                  // Snap to specific heights based on gesture direction and current position
                  if translation < -50 { // Swiping up (negative translation)
                    if currentHeight <= oneThirdHeight + 50 {
                      sheetHeight = maxHeight  // Expand to full
                      print("Expanding to max height: \(maxHeight)")
                    } else {
                      sheetHeight = maxHeight  // Already expanded, stay at max
                    }
                  } else if translation > 50 { // Swiping down (positive translation)
                    if currentHeight >= maxHeight - 50 {
                      sheetHeight = oneThirdHeight  // Collapse from full to default
                      print("Collapsing to oneThird: \(oneThirdHeight)")
                    } else if currentHeight >= oneThirdHeight - 50 {
                      sheetHeight = minHeight  // Collapse from default to min
                      print("Collapsing to min: \(minHeight)")
                    }
                  } else {
                    // Small gesture - snap to nearest height
                    let targetHeight = currentHeight - translation
                    let heights = [minHeight, oneThirdHeight, maxHeight]
                    let nearestHeight = heights.min { abs($0 - targetHeight) < abs($1 - targetHeight) } ?? oneThirdHeight
                    sheetHeight = nearestHeight
                    print("Snapping to nearest: \(nearestHeight)")
                  }
                }
              }
          )
          // Scroll to selectedPlace when it changes (only when not from list selection)
          .onChange(of: selectedPlace) { place in
            if let place = place, shouldScrollToSelected {
              withAnimation {
                proxy.scrollTo(place.objectID, anchor: .center)
              }
            }
            // Reset the flag for next time
            shouldScrollToSelected = true
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
  
  private func performGeoSearch() {
    guard !searchText.isEmpty else { return }
    
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = searchText
    request.region = region
    
    let search = MKLocalSearch(request: request)
    search.start { response, error in
      DispatchQueue.main.async {
        if let error = error {
          print("Search error: \(error)")
          return
        }
        
        if let response = response, let firstItem = response.mapItems.first {
          let coordinate = firstItem.placemark.coordinate
          let newRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
          )
          
          // Set search state to show all places sorted by distance from search location
          isSearching = true
          shouldSortByDistance = true
          
          withAnimation(.easeInOut(duration: 1.0)) {
            region = newRegion
          }
          
          print("Geo search completed. Moved to: \(coordinate)")
          print("Will show \(items.count) places sorted by distance from search location")
        }
      }
    }
  }

}
