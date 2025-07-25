import SwiftUI
import MapKit
import CoreData
import UIKit

struct MapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @State private var searchText = ""
    @State private var nearbyPlaces: [NearbyLocation] = []
    @State private var isLoading = false
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var showingSearch = false
    @State private var selectedCategory = "All"
    @State private var showRejected = false
    @State private var searchSuggestions: [String] = []
    @State private var showingSuggestions = false
    @StateObject private var locationManager = LocationManager()
    
    private let searchTerms = [
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
    
    private let categories = ["All", "Restaurant", "Cafe", "Shopping", "Gas Station", "Bank", "Hospital", "Hotel", "Tourist Attraction"]
    
    var filteredPlaces: [NearbyLocation] {
        var filtered = nearbyPlaces
        
        // Filter by category
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.category.contains(selectedCategory.lowercased()) }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { place in
                place.name.localizedCaseInsensitiveContains(searchText) ||
                place.address.localizedCaseInsensitiveContains(searchText) ||
                place.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter out rejected locations unless showRejected is true
        if !showRejected {
            filtered = filtered.filter { !isLocationRejected($0) }
        }
        
        // Sort with favorites first
        return filtered.sorted { a, b in
            let aFav = isLocationFavorited(a)
            let bFav = isLocationFavorited(b)
            
            if aFav && !bFav { return true }
            if !aFav && bFav { return false }
            return a.distance < b.distance
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and search button
            HStack {
                Text("Explore Locations")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Search button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingSearch.toggle()
                        if !showingSearch {
                            searchText = ""
                        }
                    }
                }) {
                    Image(systemName: showingSearch ? "xmark" : "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color(UIColor.systemBackground))
            
            // Map view - 1/4 of screen
            GeometryReader { geometry in
                if let userLocation = userLocation {
                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                        center: userLocation,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )), annotationItems: filteredPlaces.prefix(20).map { location in
                        MapAnnotationItem(coordinate: location.coordinate)
                    }) { annotation in
                        MapAnnotation(coordinate: annotation.coordinate) {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 16, height: 16)
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                    .allowsHitTesting(false)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            VStack {
                                Image(systemName: "location.slash")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Text("Location not available")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                }
            }
            .frame(height: UIScreen.main.bounds.height * 0.25)
            
            // Search section (when active)
            if showingSearch {
                VStack(spacing: 8) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                        
                        TextField("Search locations...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.vertical, 8)
                            .onChange(of: searchText) { _, newValue in
                                if !newValue.isEmpty {
                                    updateSearchSuggestions(for: newValue)
                                    showingSuggestions = true
                                } else {
                                    showingSuggestions = false
                                }
                            }
                            .onSubmit {
                                if !searchText.isEmpty {
                                    performSearch(query: searchText)
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                                showingSuggestions = false
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.trailing, 8)
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    
                    // Search suggestions
                    if showingSuggestions && !searchSuggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(searchSuggestions, id: \.self) { suggestion in
                                Button(action: {
                                    searchText = suggestion
                                    performSearch(query: suggestion)
                                    showingSuggestions = false
                                }) {
                                    HStack {
                                        Image(systemName: "clock")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(suggestion)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if suggestion != searchSuggestions.last {
                                    Divider()
                                        .padding(.leading, 28)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    }
                    
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
                        
                        // Show rejected checkbox
                        HStack {
                            Button(action: {
                                showRejected.toggle()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: showRejected ? "checkmark.square.fill" : "square")
                                        .font(.title3)
                                        .foregroundColor(showRejected ? .blue : .gray)
                                    Text("Show rejected locations")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 8)
                }
                .background(Color(UIColor.systemBackground))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Results count
            if !nearbyPlaces.isEmpty {
                HStack {
                    Text("\(filteredPlaces.count) locations found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            
            // Locations list
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Searching locations...")
                    Spacer()
                }
            } else if nearbyPlaces.isEmpty && !searchText.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "location.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No locations found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Text("Try a different search term")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if nearbyPlaces.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Search for locations")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Text("Enter a location name or type to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPlaces, id: \.id) { place in
                            MapLocationCard(
                                place: place,
                                isFavorited: isLocationFavorited(place),
                                isRejected: isLocationRejected(place),
                                onShareTap: { sharePlace(place) },
                                onPinTap: { pinPlace(place) },
                                onFavTap: { toggleFavorite(place) },
                                onRejectTap: { toggleReject(place) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            // Request location permission and get user location
            if let location = locationManager.lastLocation {
                userLocation = location.coordinate
                loadNearbyPlaces()
            }
        }
        .onChange(of: locationManager.lastLocation) { _, newLocation in
            if let location = newLocation {
                userLocation = location.coordinate
                if nearbyPlaces.isEmpty {
                    loadNearbyPlaces()
                }
            }
        }
    }
    
    // MARK: - Location Management
    
    private func isLocationFavorited(_ location: NearbyLocation) -> Bool {
        let fetchRequest: NSFetchRequest<LocationPreference> = LocationPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "locationId == %@ AND isFavorited == true", location.id)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            return !results.isEmpty
        } catch {
            print("Error fetching location preference: \(error)")
            return false
        }
    }
    
    private func isLocationRejected(_ location: NearbyLocation) -> Bool {
        let fetchRequest: NSFetchRequest<LocationPreference> = LocationPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "locationId == %@ AND isRejected == true", location.id)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            return !results.isEmpty
        } catch {
            print("Error fetching location preference: \(error)")
            return false
        }
    }
    
    private func toggleFavorite(_ location: NearbyLocation) {
        let fetchRequest: NSFetchRequest<LocationPreference> = LocationPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "locationId == %@", location.id)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            let preference: LocationPreference
            
            if let existing = results.first {
                preference = existing
            } else {
                preference = LocationPreference(context: viewContext)
                preference.locationId = location.id
                preference.locationName = location.name
                preference.locationAddress = location.address
                preference.latitude = location.coordinate.latitude
                preference.longitude = location.coordinate.longitude
                preference.createdAt = Date()
            }
            
            preference.isFavorited.toggle()
            preference.isRejected = false // Clear reject when favoriting
            preference.updatedAt = Date()
            
            try viewContext.save()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
        } catch {
            print("Error toggling favorite: \(error)")
        }
    }
    
    private func toggleReject(_ location: NearbyLocation) {
        let fetchRequest: NSFetchRequest<LocationPreference> = LocationPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "locationId == %@", location.id)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            let preference: LocationPreference
            
            if let existing = results.first {
                preference = existing
            } else {
                preference = LocationPreference(context: viewContext)
                preference.locationId = location.id
                preference.locationName = location.name
                preference.locationAddress = location.address
                preference.latitude = location.coordinate.latitude
                preference.longitude = location.coordinate.longitude
                preference.createdAt = Date()
            }
            
            preference.isRejected.toggle()
            preference.isFavorited = false // Clear favorite when rejecting
            preference.updatedAt = Date()
            
            try viewContext.save()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
        } catch {
            print("Error toggling reject: \(error)")
        }
    }
    
    // MARK: - Search History Management
    
    private func updateSearchSuggestions(for query: String) {
        let fetchRequest: NSFetchRequest<SearchPreference> = SearchPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "query CONTAINS[c] %@", query)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "searchCount", ascending: false),
            NSSortDescriptor(key: "updatedAt", ascending: false)
        ]
        fetchRequest.fetchLimit = 10
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            searchSuggestions = results.map { $0.query ?? "" }.filter { !$0.isEmpty }
        } catch {
            print("Error fetching search suggestions: \(error)")
            searchSuggestions = []
        }
    }
    
    private func saveSearchQuery(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        let fetchRequest: NSFetchRequest<SearchPreference> = SearchPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "query == %@", trimmedQuery)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            let searchPreference: SearchPreference
            
            if let existing = results.first {
                // Update existing search
                searchPreference = existing
                searchPreference.searchCount += 1
                searchPreference.updatedAt = Date()
            } else {
                // Create new search preference
                searchPreference = SearchPreference(context: viewContext)
                searchPreference.query = trimmedQuery
                searchPreference.searchCount = 1
                searchPreference.createdAt = Date()
                searchPreference.updatedAt = Date()
            }
            
            try viewContext.save()
        } catch {
            print("Error saving search query: \(error)")
        }
    }
    
    private func performSearch(query: String) {
        saveSearchQuery(query)
        searchLocations(query: query)
        showingSuggestions = false
    }
    
    // MARK: - Search and Loading
    
    private func loadNearbyPlaces() async {
        guard let userLocation = userLocation else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        var allPlaces: [NearbyLocation] = []
        
        for searchTerm in searchTerms {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchTerm
            request.region = MKCoordinateRegion(
                center: userLocation,
                latitudinalMeters: 10000, // 10km radius
                longitudinalMeters: 10000
            )
            
            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                
                let places = response.mapItems.prefix(10).compactMap { item -> NearbyLocation? in
                    guard let location = item.placemark.location else { return nil }
                    
                    let distance = location.distance(from: CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude))
                    
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
    
    private func loadNearbyPlaces() {
        guard let userLocation = userLocation else { return }
        
        Task {
            await loadNearbyPlaces()
        }
    }
    
    private func searchLocations(query: String) {
        guard let userLocation = userLocation else { return }
        
        isLoading = true
        
        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(
                center: userLocation,
                latitudinalMeters: 50000, // 50km radius for search
                longitudinalMeters: 50000
            )
            
            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                
                let places = response.mapItems.compactMap { item -> NearbyLocation? in
                    guard let location = item.placemark.location else { return nil }
                    
                    let distance = location.distance(from: CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude))
                    
                    return NearbyLocation(
                        id: item.placemark.name ?? UUID().uuidString,
                        name: item.placemark.name ?? "Unknown",
                        address: formatAddress(from: item.placemark),
                        coordinate: item.placemark.coordinate,
                        distance: distance,
                        category: "search",
                        phoneNumber: item.phoneNumber,
                        url: item.url
                    )
                }
                
                await MainActor.run {
                    self.nearbyPlaces = places.sorted { $0.distance < $1.distance }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Search failed: \(error)")
            }
        }
    }
    
    // MARK: - Actions
    
    private func sharePlace(_ place: NearbyLocation) {
        // Create platform map URL
        let encodedName = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let lat = place.coordinate.latitude
        let lon = place.coordinate.longitude
        
        // Create Apple Maps URL (works on iOS, falls back to web on other platforms)
        let mapURL = "https://maps.apple.com/?q=\(encodedName)&ll=\(lat),\(lon)&t=m"
        
        let shareText = "Check out \(place.name)!\n\n\(place.address)\nDistance: \(String(format: "%.1f", place.distance / 1000)) km away\n\n\(mapURL)"
        
        // Present share sheet
        let activityViewController = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            var topController = rootViewController
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            topController.present(activityViewController, animated: true)
        }
    }
    
    private func pinPlace(_ place: NearbyLocation) {
        // Create a new Place object from the location
        let newPlace = Place(context: viewContext)
        newPlace.dateAdded = Date()
        newPlace.post = place.name
        newPlace.url = place.address
        newPlace.isPrivate = false
        
        // Store location coordinates
        let clLocation = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        if let locationData = try? NSKeyedArchiver.archivedData(withRootObject: clLocation, requiringSecureCoding: false) {
            newPlace.setValue(locationData, forKey: "coordinates")
        }
        
        // Store location info as JSON
        let locationInfo = LocationInfo(from: place)
        if let locationData = try? JSONEncoder().encode([locationInfo]),
           let locationJSON = String(data: locationData, encoding: .utf8) {
            newPlace.locations = locationJSON
        }
        
        do {
            try viewContext.save()
            
            // Show success feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            print("✅ Successfully created pin for location: \(place.name)")
        } catch {
            print("❌ Failed to create pin: \(error)")
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

struct MapLocationCard: View {
    let place: NearbyLocation
    let isFavorited: Bool
    let isRejected: Bool
    let onShareTap: () -> Void
    let onPinTap: () -> Void
    let onFavTap: () -> Void
    let onRejectTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main content
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(isFavorited ? .blue : .primary)
                        .fontWeight(isFavorited ? .semibold : .regular)
                    
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
                        
                        if isFavorited {
                            Spacer()
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 0) {
                Button(action: onShareTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                }
                
                Button(action: onPinTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("Pin")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                }
                
                Button(action: onFavTap) {
                    HStack(spacing: 4) {
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                        Text("Fav")
                    }
                    .font(.caption)
                    .foregroundColor(isFavorited ? .red : .blue)
                    .frame(maxWidth: .infinity)
                }
                
                Button(action: onRejectTap) {
                    HStack(spacing: 4) {
                        Image(systemName: isRejected ? "x.circle.fill" : "x.circle")
                        Text("Reject")
                    }
                    .font(.caption)
                    .foregroundColor(isRejected ? .red : .blue)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(isFavorited ? Color.blue.opacity(0.05) : Color(UIColor.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFavorited ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

