import CoreData
import MapKit
import SwiftUI

struct PlaceDetailView: View {
    let place: Place
    let allPlaces: [Place]
    let onBack: () -> Void
    
    @State private var region: MKCoordinateRegion
    @State private var mapPlaces: [MKMapItem] = []
    @State private var isLoadingPlaces = false
    
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
    
    func searchNearbyPlaces() {
        isLoadingPlaces = true
        let coordinate = Self.coordinate(item: place)
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "restaurant cafe store gas station hotel"
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 500, // 500m radius for more specific results
            longitudinalMeters: 500
        )
        request.resultTypes = [.pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        search.start { [self] response, error in
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
                    mapPlaces = Array(filteredPlaces.prefix(20))
                }
            }
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
            
            // List of nearby places below map
            VStack(alignment: .leading, spacing: 0) {
                Text("Nearby Places")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if isLoadingPlaces {
                            HStack {
                                ProgressView()
                                Text("Loading nearby places...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        } else {
                            ForEach(mapPlaces, id: \.self) { mapItem in
                                HStack(spacing: 12) {
                                    // Icon for place type
                                    Image(systemName: iconForPlaceType(mapItem.pointOfInterestCategory))
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.blue)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mapItem.name ?? "Unknown Place")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        
                                        if let category = mapItem.pointOfInterestCategory {
                                            Text(categoryDisplayName(category))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if let address = mapItem.placemark.thoroughfare {
                                            Text(address)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if let coordinate = mapItem.placemark.location?.coordinate {
                                        Text("\(Int(Self.distance(from: Self.coordinate(item: place), to: coordinate)))m")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            
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
        .onAppear {
            searchNearbyPlaces()
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
    
    func iconForPlaceType(_ category: MKPointOfInterestCategory?) -> String {
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
    
    func categoryDisplayName(_ category: MKPointOfInterestCategory) -> String {
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