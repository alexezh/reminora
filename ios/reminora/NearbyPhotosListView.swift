import CoreData
import MapKit
import SwiftUI

struct NearbyPhotosListView: View {
    let places: [Place]
    let currentLocation: CLLocationCoordinate2D
    let onPhotoSelect: (Place) -> Void
    
    // Sort places by distance from current location
    var sortedPlaces: [Place] {
        places.sorted { place1, place2 in
            let distance1 = distanceFromCurrent(place: place1)
            let distance2 = distanceFromCurrent(place: place2)
            return distance1 < distance2
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sortedPlaces, id: \.objectID) { place in
                    HStack(spacing: 12) {
                        // Photo thumbnail
                        if let imageData = place.imageData, let image = UIImage(data: imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "photo")
                                .frame(width: 60, height: 60)
                                .foregroundColor(.gray)
                                .background(Color.gray.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // Date
                            if let date = place.dateAdded {
                                Text(date, formatter: dateFormatter)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            
                            // Post content or URL
                            if let post = place.post, !post.isEmpty {
                                Text(post)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            } else if let url = place.url, !url.isEmpty {
                                Text(url)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            // Distance from current location
                            Text(distanceText(for: place))
                                .font(.caption)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        // Distance indicator
                        VStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(shortDistanceText(for: place))
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onPhotoSelect(place)
                    }
                }
            }
            .navigationTitle("Nearby Photos")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // Helper to calculate distance from current location
    private func distanceFromCurrent(place: Place) -> CLLocationDistance {
        let placeCoordinate = coordinate(for: place)
        let currentLocationCL = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        let placeLocationCL = CLLocation(latitude: placeCoordinate.latitude, longitude: placeCoordinate.longitude)
        
        return currentLocationCL.distance(from: placeLocationCL)
    }
    
    // Helper to get coordinate from Place
    private func coordinate(for place: Place) -> CLLocationCoordinate2D {
        if let locationData = place.value(forKey: "location") as? Data,
           let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation {
            return location.coordinate
        }
        // Default to San Francisco if no location
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }
    
    // Helper to format distance text
    private func distanceText(for place: Place) -> String {
        let distance = distanceFromCurrent(place: place)
        
        if distance < 1000 {
            return "\(Int(distance)) meters away"
        } else {
            return String(format: "%.1f km away", distance / 1000)
        }
    }
    
    // Helper to format short distance text
    private func shortDistanceText(for place: Place) -> String {
        let distance = distanceFromCurrent(place: place)
        
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let samplePlaces: [Place] = []
    let currentLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    
    return NearbyPhotosListView(
        places: samplePlaces,
        currentLocation: currentLocation,
        onPhotoSelect: { _ in }
    )
    .environment(\.managedObjectContext, context)
}
