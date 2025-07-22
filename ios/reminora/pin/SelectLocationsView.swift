import SwiftUI
import MapKit
import CoreData

struct SelectLocationsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    let initialAddresses: [PlaceAddress]
    let onSave: ([PlaceAddress]) -> Void
    
    @State private var nearbyPlaces: [NearbyLocation] = []
    @State private var selectedAddresses: [PlaceAddress] = []
    @State private var isLoading = true
    @State private var selectedCategory = "All"
    @State private var searchLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    
    private let categories = ["All", "Restaurant", "Cafe", "Shopping", "Gas Station", "Bank", "Hospital", "Hotel", "Tourist Attraction"]
    
    var filteredPlaces: [NearbyLocation] {
        let filtered = if selectedCategory == "All" {
            nearbyPlaces
        } else {
            nearbyPlaces.filter { $0.category.contains(selectedCategory.lowercased()) }
        }
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with selection info
                HStack {
                    VStack(alignment: .leading) {
                        Text("Select Locations")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("\(selectedAddresses.count) locations selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(Color(UIColor.systemBackground))
                
                // Map view showing search location
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
                
                // Selected addresses section
                if !selectedAddresses.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Selected Locations")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Button("Clear All") {
                                selectedAddresses.removeAll()
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedAddresses, id: \.id) { address in
                                    SelectedAddressChip(
                                        address: address,
                                        onRemove: {
                                            selectedAddresses.removeAll { $0.id == address.id }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                }
                
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
                                SelectableLocationCard(
                                    place: place,
                                    isSelected: isPlaceSelected(place),
                                    onTap: {
                                        togglePlaceSelection(place)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(false)
            .navigationTitle("Select Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(selectedAddresses)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedAddresses.isEmpty)
                }
            }
        }
        .task {
            await loadNearbyPlaces()
        }
        .onAppear {
            // Initialize with existing addresses
            selectedAddresses = initialAddresses
        }
    }
    
    private func isPlaceSelected(_ place: NearbyLocation) -> Bool {
        return selectedAddresses.contains { address in
            abs(address.coordinates.latitude - place.coordinate.latitude) < 0.0001 &&
            abs(address.coordinates.longitude - place.coordinate.longitude) < 0.0001
        }
    }
    
    private func togglePlaceSelection(_ place: NearbyLocation) {
        let placeAddress = PlaceAddress(
            coordinates: PlaceCoordinates(
                latitude: place.coordinate.latitude,
                longitude: place.coordinate.longitude
            ),
            country: extractCountry(from: place.address),
            city: extractCity(from: place.address),
            phone: place.phoneNumber,
            website: place.url?.absoluteString,
            fullAddress: place.address
        )
        
        if isPlaceSelected(place) {
            // Remove from selection
            selectedAddresses.removeAll { address in
                abs(address.coordinates.latitude - place.coordinate.latitude) < 0.0001 &&
                abs(address.coordinates.longitude - place.coordinate.longitude) < 0.0001
            }
        } else {
            // Add to selection
            selectedAddresses.append(placeAddress)
        }
    }
    
    private func extractCountry(from address: String) -> String? {
        // Simple extraction - in a real app you might use CLGeocoder
        let components = address.components(separatedBy: ",")
        return components.last?.trimmingCharacters(in: .whitespaces)
    }
    
    private func extractCity(from address: String) -> String? {
        // Simple extraction - in a real app you might use CLGeocoder
        let components = address.components(separatedBy: ",")
        if components.count >= 2 {
            return components[components.count - 2].trimmingCharacters(in: .whitespaces)
        }
        return nil
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
}

struct SelectableLocationCard: View {
    let place: NearbyLocation
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Selection indicator and main content
                HStack(spacing: 12) {
                    // Selection indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .gray)
                    
                    // Main content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.headline)
                            .foregroundColor(.primary)
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
                    
                    Spacer()
                }
                
                // Additional info if available
                if let phoneNumber = place.phoneNumber, !phoneNumber.isEmpty {
                    HStack {
                        Image(systemName: "phone.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(phoneNumber)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(UIColor.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SelectedAddressChip: View {
    let address: PlaceAddress
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                if let fullAddress = address.fullAddress, !fullAddress.isEmpty {
                    Text(fullAddress)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                } else if let city = address.city {
                    Text(city)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                Text(String(format: "%.4f, %.4f", address.coordinates.latitude, address.coordinates.longitude))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospaced()
            }
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue, lineWidth: 1)
        )
        .cornerRadius(8)
    }
}