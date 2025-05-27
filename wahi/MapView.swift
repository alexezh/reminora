import SwiftUI
import MapKit

struct MapView: View {
    @Binding var region: MKCoordinateRegion
    var filteredItems: [Place]
    var selectedPlace: Binding<Place?>
    var showSheet: Binding<Bool>
    var coordinate: (Place) -> CLLocationCoordinate2D
    var locationManager: LocationManager

    var body: some View {
        ZStack {
            // Map with user location
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: filteredItems) { item in
                MapAnnotation(coordinate: coordinate(item)) {
                    Button(action: {
                        selectedPlace.wrappedValue = item
                        showSheet.wrappedValue = true
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
        }
    }
}