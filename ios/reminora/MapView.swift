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
  @StateObject private var locationManager = LocationManager()

  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Place.dateAdded, ascending: true)],
    animation: .default)
  private var items: FetchedResults<Place>

  @State private var searchText: String = ""
  @State private var isSearching: Bool = false
  @State private var region = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
  )

  var filteredItems: [Place] {
    if !searchText.isEmpty {
      // Text search in place names/posts
      return items.filter { item in
        (item.post?.localizedCaseInsensitiveContains(searchText) ?? false)
          || (item.url?.localizedCaseInsensitiveContains(searchText) ?? false)
      }
    } else {
      // Return items sorted by date added (most recent first)
      return Array(items).sorted { a, b in
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
      // Search bar overlay when expanded
      if !searchText.isEmpty {
        VStack {
          HStack {
            Image(systemName: "magnifyingglass")
              .foregroundColor(.secondary)
              .padding(.leading, 8)
            
            TextField("Search places...", text: $searchText)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .onSubmit {
                performGeoSearch()
              }
            
            Button("Clear") {
              searchText = ""
              isSearching = false
            }
            .foregroundColor(.blue)
            .padding(.trailing, 8)
          }
          .padding(.horizontal, 16)
          .padding(.top, 60)
          .background(Color(.systemBackground))
          .zIndex(1)
          
          Spacer()
        }
      }
      
      // Main content using PlaceBrowserView
      PlaceBrowserView(
        places: filteredItems,
        title: "",
        showToolbar: true
      )
    }
    .onReceive(locationManager.$lastLocation) { location in
      guard let location = location else { return }
      DispatchQueue.main.async {
        print("updating location")
        withAnimation(.easeInOut(duration: 1.0)) {
          region = MKCoordinateRegion(
            center: location.coordinate,
            span: region.span
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
          
          // Set search state
          isSearching = true
          
          withAnimation(.easeInOut(duration: 1.0)) {
            region = newRegion
          }
          
          print("Geo search completed. Moved to: \(coordinate)")
        }
      }
    }
  }

}
