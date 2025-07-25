import SwiftUI
import MapKit
import CoreData

struct NearbyLocationsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    let searchLocation: CLLocationCoordinate2D
    let locationName: String
    let isSelectMode: Bool
    @Binding var selectedLocations: [LocationInfo]
    
    init(searchLocation: CLLocationCoordinate2D, locationName: String, isSelectMode: Bool = false, selectedLocations: Binding<[LocationInfo]> = .constant([])) {
        self.searchLocation = searchLocation
        self.locationName = locationName
        self.isSelectMode = isSelectMode
        self._selectedLocations = selectedLocations
    }
    
    @State private var nearbyPlaces: [NearbyLocation] = []
    @State private var isLoading = true
    @State private var selectedCategory = "All"
    @State private var showingShareSheet = false
    @State private var shareText = ""
    @State private var showingListPicker = false
    @State private var showingAddPin = false
    @State private var selectedPlace: NearbyLocation?
    @State private var selectedPlaceIds: Set<String> = []
    
    private let categories = ["All", "Restaurant", "Cafe", "Shopping", "Gas Station", "Bank", "Hospital", "Hotel", "Tourist Attraction"]
    
    var filteredPlaces: [NearbyLocation] {
        let filtered = if selectedCategory == "All" {
            nearbyPlaces
        } else {
            nearbyPlaces.filter { $0.category.contains(selectedCategory.lowercased()) }
        }
        print("🗺️ NearbyLocations - filteredPlaces: \(filtered.count) places for category '\(selectedCategory)'")
        return filtered
    }
    
    var body: some View {
        VStack(spacing: 0) {
                // Header with location info
                HStack {
                    // Back button (left)
                    Button("Back") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    VStack(alignment: .center) {
                        Text(isSelectMode ? "Select Locations" : "Near \(locationName)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        if !isSelectMode {
                            Text("\(nearbyPlaces.count) places found")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(selectedPlaceIds.count) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Save button (right) - only in select mode
                    if isSelectMode {
                        Button("Save") {
                            saveSelectedLocations()
                        }
                        .foregroundColor(.blue)
                        .disabled(selectedPlaceIds.isEmpty)
                    } else {
                        // Placeholder to keep centering
                        Button("Close") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(.blue)
                    }
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
                
                // Category filter dropdown
                VStack(spacing: 0) {
                    HStack {
                        Text("Category:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Menu {
                            ForEach(categories, id: \.self) { category in
                                Button(action: {
                                    selectedCategory = category
                                }) {
                                    HStack {
                                        Text(category)
                                        if selectedCategory == category {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(selectedCategory)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
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
                                if isSelectMode {
                                    SelectableLocationCard(
                                        place: place,
                                        isSelected: selectedPlaceIds.contains(place.id),
                                        onToggleSelection: {
                                            togglePlaceSelection(place)
                                        }
                                    )
                                } else {
                                    NearbyLocationCard(
                                        place: place,
                                        onMapTap: {
                                            openInNativeMap(place)
                                        },
                                        onShareTap: {
                                            sharePlace(place)
                                        },
                                        onSaveTap: {
                                            pinPlace(place)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(text: shareText)
        }
        .sheet(isPresented: $showingAddPin) {
            if let selectedPlace = selectedPlace {
                NavigationView {
                    AddPinFromLocationView(
                        location: selectedPlace,
                        onDismiss: {
                            showingAddPin = false
                        }
                    )
                }
            }
        }
        .task {
            print("🗺️ NearbyLocations - View appeared, loading places...")
            await loadNearbyPlaces()
        }
        .onAppear {
            print("🗺️ NearbyLocations - onAppear called with searchLocation: \(searchLocation), locationName: \(locationName), isSelectMode: \(isSelectMode)")
        }
    }
    
    private func loadNearbyPlaces() async {
        print("🗺️ NearbyLocations - Starting to load places for location: \(searchLocation)")
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
            print("🗺️ NearbyLocations - Searching for: \(searchTerm)")
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
                print("🗺️ NearbyLocations - Found \(response.mapItems.count) items for \(searchTerm)")
                
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
        print("🗺️ NearbyLocations - Total unique places found: \(uniquePlaces.count)")
        
        await MainActor.run {
            self.nearbyPlaces = uniquePlaces
            self.isLoading = false
            print("🗺️ NearbyLocations - Updated nearbyPlaces with \(uniquePlaces.count) places, isLoading: \(isLoading)")
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
        // Create platform map URL
        let encodedName = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let lat = place.coordinate.latitude
        let lon = place.coordinate.longitude
        
        // Create Apple Maps URL (works on iOS, falls back to web on other platforms)
        let mapURL = "https://maps.apple.com/?q=\(encodedName)&ll=\(lat),\(lon)&t=m"
        
        shareText = "Check out \(place.name)!\n\n\(place.address)\nDistance: \(String(format: "%.1f", place.distance / 1000)) km away\n\n\(mapURL)"
        
        // Add location to shared list
        addLocationToSharedList(place)
        
        showingShareSheet = true
    }
    
    private func pinPlace(_ place: NearbyLocation) {
        selectedPlace = place
        showingAddPin = true
    }
    
    private func openInNativeMap(_ place: NearbyLocation) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        mapItem.name = place.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    private func togglePlaceSelection(_ place: NearbyLocation) {
        if selectedPlaceIds.contains(place.id) {
            selectedPlaceIds.remove(place.id)
        } else {
            selectedPlaceIds.insert(place.id)
        }
    }
    
    private func saveSelectedLocations() {
        let selected = filteredPlaces.filter { selectedPlaceIds.contains($0.id) }
        let locationInfos = selected.map { LocationInfo(from: $0) }
        selectedLocations.append(contentsOf: locationInfos)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func addLocationToSharedList(_ location: NearbyLocation) {
        let context = viewContext
        
        // Check if "Shared" list exists
        let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "Shared")
        
        do {
            let existingLists = try context.fetch(fetchRequest)
            let sharedList: UserList
            
            if let existing = existingLists.first {
                sharedList = existing
            } else {
                // Create "Shared" list
                sharedList = UserList(context: context)
                sharedList.id = UUID().uuidString
                sharedList.name = "Shared"
                sharedList.createdAt = Date()
                sharedList.userId = AuthenticationService.shared.currentAccount?.id ?? ""
            }
            
            // Create a location entry as a Place object with special identifier
            let locationPlace = Place(context: context)
            locationPlace.post = location.name
            locationPlace.url = "location://\(location.id)" // Special marker for locations
            locationPlace.dateAdded = Date()
            locationPlace.cloudId = "location_\(location.id)"
            locationPlace.isPrivate = false  // Default to public
            
            // Store location coordinates
            let clLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            if let locationData = try? NSKeyedArchiver.archivedData(withRootObject: clLocation, requiringSecureCoding: false) {
                locationPlace.setValue(locationData, forKey: "coordinates")
            }
            
            // Store additional location info in the description field
            let locationInfo = "\(location.address)\nDistance: \(String(format: "%.1f", location.distance / 1000)) km"
            // We can store this in the URL field along with the location:// marker
            locationPlace.url = "location://\(location.id)|\(locationInfo)"
            
            // Check if location is already in the list
            let itemFetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
            itemFetchRequest.predicate = NSPredicate(format: "listId == %@ AND placeId == %@", 
                                                   sharedList.id ?? "", 
                                                   locationPlace.objectID.uriRepresentation().absoluteString)
            
            let existingItems = try context.fetch(itemFetchRequest)
            
            if existingItems.isEmpty {
                // Save the place first to get its object ID
                try context.save()
                
                // Add location to shared list
                let item = ListItem(context: context)
                item.id = UUID().uuidString
                item.listId = sharedList.id
                item.placeId = locationPlace.objectID.uriRepresentation().absoluteString
                item.addedAt = Date()
                
                try context.save()
                print("✅ Added location '\(location.name)' to Shared list")
            } else {
                print("ℹ️ Location '\(location.name)' already in Shared list")
            }
            
        } catch {
            print("❌ Failed to add location to shared list: \(error)")
        }
    }
}

struct SelectableLocationCard: View {
    let place: NearbyLocation
    let isSelected: Bool
    let onToggleSelection: () -> Void
    
    var body: some View {
        Button(action: onToggleSelection) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.name)
                                .font(.headline)
                                .lineLimit(2)
                                .foregroundColor(.primary)
                            
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
                    
                    Spacer()
                    
                    // Selection indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .gray)
                }
            }
            .padding(16)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
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
                        Image(systemName: "mappin.and.ellipse")
                        Text("Pin")
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

struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct AddPinFromLocationView: View {
    let location: NearbyLocation
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var caption: String = ""
    @State private var isSaving = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Location preview with map
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(.headline)
                    
                    // Location name and address
                    VStack(alignment: .leading, spacing: 4) {
                        Text(location.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(location.address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text(String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospaced()
                        }
                        .padding(.top, 2)
                    }
                    .padding(.bottom, 8)
                    
                    // Mini map
                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )), annotationItems: [MapAnnotationItem(coordinate: location.coordinate)]) { pin in
                        MapAnnotation(coordinate: pin.coordinate) {
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
                    .cornerRadius(12)
                    .disabled(true) // Make map non-interactive
                }
                
                // Caption input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Caption")
                        .font(.headline)
                    
                    TextField("What's special about this place?", text: $caption, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Add Pin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onDismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    savePinFromLocation()
                }
                .disabled(isSaving)
            }
        }
    }
    
    private func savePinFromLocation() {
        isSaving = true
        
        let newPlace = Place(context: viewContext)
        newPlace.dateAdded = Date()
        newPlace.post = caption.isEmpty ? location.name : caption
        newPlace.url = location.address
        
        // Store location
        let clLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        if let locationData = try? NSKeyedArchiver.archivedData(withRootObject: clLocation, requiringSecureCoding: false) {
            newPlace.setValue(locationData, forKey: "coordinates")
        }
        
        do {
            try viewContext.save()
            
            // Show success feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            isSaving = false
            onDismiss()
        } catch {
            print("Failed to save pin from location: \(error)")
            isSaving = false
        }
    }
}
