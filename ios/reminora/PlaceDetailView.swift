import CoreData
import MapKit
import SwiftUI

struct PlaceDetailView: View {
    let place: Place
    let allPlaces: [Place]
    let onBack: () -> Void
    
    @State private var region: MKCoordinateRegion
    
    init(place: Place, allPlaces: [Place], onBack: @escaping () -> Void) {
        self.place = place
        self.allPlaces = allPlaces
        self.onBack = onBack
        
        // Initialize region centered on the selected place
        let coord = PlaceDetailView.coordinate(item: place)
        self._region = State(initialValue: MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var nearbyPlaces: [Place] {
        let selectedCoord = Self.coordinate(item: place)
        return allPlaces.filter { item in
            let coord = Self.coordinate(item: item)
            let distance = Self.distance(from: selectedCoord, to: coord)
            return distance <= 1000 && item.objectID != place.objectID // Within 1km, excluding selected
        }.sorted { a, b in
            let aCoord = Self.coordinate(item: a)
            let bCoord = Self.coordinate(item: b)
            let aDist = Self.distance(from: selectedCoord, to: aCoord)
            let bDist = Self.distance(from: selectedCoord, to: bCoord)
            return aDist < bDist
        }
    }
    
    
    var body: some View {
        VStack(spacing: 0) {
            // Photo at top
            if let imageData = place.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 300)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                    )
            }
            
            // Photo caption if available
            if let post = place.post, !post.isEmpty {
                Text(post)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Date
            if let date = place.dateAdded {
                Text(date, formatter: itemFormatter)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Map below photo
            Map(coordinateRegion: .constant(region), annotationItems: [place] + nearbyPlaces) { item in
                MapAnnotation(coordinate: Self.coordinate(item: item)) {
                    Button(action: {
                        // Could navigate to this place if desired
                    }) {
                        Image(systemName: item.objectID == place.objectID ? "mappin.circle.fill" : "mappin.circle")
                            .font(.title2)
                            .foregroundColor(item.objectID == place.objectID ? .red : .blue)
                    }
                }
            }
            .frame(height: 200)
            .allowsHitTesting(false)
            
            // Nearby places using shared component
            NearbyPlacesView(coordinate: Self.coordinate(item: place))
            
            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
    }
    
    // Helper methods
    static func coordinate(item: Place) -> CLLocationCoordinate2D {
        if let locationData = item.value(forKey: "location") as? Data,
           let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation {
            return location.coordinate
        }
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }
    
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

private let shortFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
}()