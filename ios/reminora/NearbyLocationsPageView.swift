import SwiftUI
import MapKit
import CoreData

struct NearbyLocationsPageView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    let searchLocation: CLLocationCoordinate2D
    let locationName: String
    
    @State private var nearbyPlaces: [NearbyLocation] = []
    @State private var isLoading = true
    @State private var selectedCategory = "All"
    @State private var showingShareSheet = false
    @State private var shareText = ""
    @State private var showingListPicker = false
    @State private var selectedPlace: NearbyLocation?
    
    private let categories = ["All", "Restaurant", "Cafe", "Shopping", "Gas Station", "Bank", "Hospital", "Hotel", "Tourist Attraction"]
    
    var filteredPlaces: [NearbyLocation] {
        if selectedCategory == "All" {
            return nearbyPlaces
        }
        return nearbyPlaces.filter { $0.category.contains(selectedCategory.lowercased()) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with location info
                HStack {
                    VStack(alignment: .leading) {
                        Text("Near \(locationName)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("\(nearbyPlaces.count) places found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(Color(UIColor.systemBackground))
                
                // Map view showing current pin location
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: searchLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )), annotationItems: [MapAnnotationItem(coordinate: searchLocation)]) { annotation in
                    MapAnnotation(coordinate: annotation.coordinate) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 20, height: 20)
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 20, height: 20)
                        }
                    }
                }
                .frame(height: 200)
                
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            Button(action: {
                                selectedCategory = category
                            }) {
                                Text(category)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedCategory == category ? .white : .primary)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)
                .background(Color(UIColor.systemBackground))
                
                // Places list
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Finding nearby places...")
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredPlaces, id: \.id) { place in
                                NearbyLocationCard(
                                    place: place,
                                    onMapTap: {
                                        openInNativeMap(place)
                                    },
                                    onShareTap: {
                                        sharePlace(place)
                                    },
                                    onSaveTap: {
                                        savePlace(place)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(text: shareText)
        }
        .sheet(isPresented: $showingListPicker) {
            if let selectedPlace = selectedPlace {
                ListPickerView(place: selectedPlace, isPresented: $showingListPicker)
            }
        }
        .task {
            await loadNearbyPlaces()
        }
    }
    
    private func loadNearbyPlaces() async {
        await MainActor.run {
            isLoading = true
        }
        
        let searchTerms = [
            "restaurant food dining",
            "cafe coffee shop", 
            "store shop market retail",
            "gas station fuel",
            "bank atm",
            "hospital medical clinic",
            "hotel lodging accommodation",
            "tourist attraction landmark",
            "park recreation",
            "gym fitness",
            "pharmacy drugstore",
            "movie theater cinema",
            "library",
            "post office",
            "school university"
        ]
        
        var allPlaces: [NearbyLocation] = []
        
        for searchTerm in searchTerms {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchTerm
            request.region = MKCoordinateRegion(
                center: searchLocation,
                latitudinalMeters: 5000,
                longitudinalMeters: 5000
            )
            
            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                
                let places = response.mapItems.prefix(5).compactMap { item -> NearbyLocation? in
                    guard let location = item.placemark.location else { return nil }
                    
                    let distance = location.distance(from: CLLocation(latitude: searchLocation.latitude, longitude: searchLocation.longitude))
                    
                    return NearbyLocation(
                        id: item.placemark.name ?? UUID().uuidString,
                        name: item.placemark.name ?? "Unknown",
                        address: formatAddress(from: item.placemark),
                        coordinate: item.placemark.coordinate,
                        distance: distance,
                        category: searchTerm,
                        phoneNumber: item.phoneNumber,
                        url: item.url
                    )
                }
                
                allPlaces.append(contentsOf: places)
            } catch {
                print("Search failed for \(searchTerm): \(error)")
            }
        }
        
        // Remove duplicates and sort by distance
        let uniquePlaces = Array(Set(allPlaces)).sorted { $0.distance < $1.distance }
        
        await MainActor.run {
            self.nearbyPlaces = uniquePlaces
            self.isLoading = false
        }
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        return components.joined(separator: " ")
    }
    
    private func sharePlace(_ place: NearbyLocation) {
        // Create a reminora link for the place
        let placeId = place.id
        let encodedName = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let lat = place.coordinate.latitude
        let lon = place.coordinate.longitude
        
        // Add owner information from auth service
        let authService = AuthenticationService.shared
        let ownerId = authService.currentAccount?.id ?? ""
        let ownerHandle = authService.currentAccount?.handle ?? ""
        let encodedOwnerHandle = ownerHandle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let reminoraLink = "reminora://place/\(placeId)?name=\(encodedName)&lat=\(lat)&lon=\(lon)&ownerId=\(ownerId)&ownerHandle=\(encodedOwnerHandle)"
        
        shareText = "Check out \(place.name) on Reminora!\n\n\(place.address)\nDistance: \(String(format: "%.1f", place.distance / 1000)) km\n\n\(reminoraLink)"
        showingShareSheet = true
    }
    
    private func savePlace(_ place: NearbyLocation) {
        selectedPlace = place
        showingListPicker = true
    }
    
    private func openInNativeMap(_ place: NearbyLocation) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        mapItem.name = place.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

struct NearbyLocationCard: View {
    let place: NearbyLocation
    let onMapTap: () -> Void
    let onShareTap: () -> Void
    let onSaveTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(place.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(String(format: "%.1f", place.distance / 1000)) km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Action buttons
            HStack {
                Spacer()
                
                Button(action: onMapTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "map")
                        Text("Map")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: onShareTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: onSaveTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Save")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}


struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    let url: String?
    
    init(text: String, url: String? = nil) {
        self.text = text
        self.url = url
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        print("ShareSheet - text: '\(text)'")
        print("ShareSheet - url: '\(url ?? "nil")'")
        
        var activityItems: [Any] = []
        
        // For SMS/Messages, combine text and URL into a single message
        if let url = url, !url.isEmpty {
            let combinedMessage = "\(text)\n\n\(url)"
            print("ShareSheet - combined message: '\(combinedMessage)'")
            activityItems.append(combinedMessage)
        } else {
            print("ShareSheet - using text only: '\(text)'")
            activityItems.append(text)
        }
        
        print("ShareSheet - activityItems count: \(activityItems.count)")
        
        let activityViewController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct NearbyLocation: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let distance: Double
    let category: String
    let phoneNumber: String?
    let url: URL?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(address)
    }
}

struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

extension NearbyLocation {
    static func == (lhs: NearbyLocation, rhs: NearbyLocation) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.address == rhs.address
    }
}

// Make CLLocationCoordinate2D hashable for our use case
extension CLLocationCoordinate2D: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
    
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
