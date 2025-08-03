import SwiftUI
import MapKit
import CoreData
import UIKit
import Foundation

struct MapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.toolbarManager) private var toolbarManager
    @StateObject private var actionRouter = ActionRouter.shared
    
    @State private var searchText = ""
    @State private var nearbyPlaces: [LocationInfo] = []
    @State private var isLoading = false
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var selectedCategory = "All"
    @State private var searchSuggestions: [String] = []
    @State private var showingSuggestions = false
    @State private var mapRegion = MKCoordinateRegion()
    @State private var selectedCardLocation: LocationInfo?
    @State private var navigatingToLocation: LocationInfo?
    @State private var showingSaveDialog = false
    @State private var showingActionSheet = false
    @State private var saveDialogCity = ""
    @State private var saveDialogSearchString = ""
    @StateObject private var locationManager = LocationManager()
    
    private let locationPreferenceService = LocationPreferenceService.shared
    
    // MARK: - Location Memory & Search Cache
    
    private var lastMapRegionKey: String { "MapView.lastMapRegion" }
    private var lastSearchResultsKey: String { "MapView.lastSearchResults" }
    private var lastSearchStringKey: String { "MapView.lastSearchString" }
    
    private func saveMapRegion() {
        let regionData = [
            "latitude": mapRegion.center.latitude,
            "longitude": mapRegion.center.longitude,
            "latitudeDelta": mapRegion.span.latitudeDelta,
            "longitudeDelta": mapRegion.span.longitudeDelta
        ]
        UserDefaults.standard.set(regionData, forKey: lastMapRegionKey)
    }
    
    private func loadLastMapRegion() {
        guard let regionData = UserDefaults.standard.dictionary(forKey: lastMapRegionKey) as? [String: Double],
              let latitude = regionData["latitude"],
              let longitude = regionData["longitude"],
              let latitudeDelta = regionData["latitudeDelta"],
              let longitudeDelta = regionData["longitudeDelta"] else {
            return
        }
        
        mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
        print("📍 MapView: Restored last map region: \(latitude), \(longitude)")
    }
    
    private func saveSearchCache() {
        // Save search results as JSON
        do {
            let data = try JSONEncoder().encode(nearbyPlaces)
            UserDefaults.standard.set(data, forKey: lastSearchResultsKey)
            print("📍 MapView: Saved \(nearbyPlaces.count) search results to cache")
        } catch {
            print("📍 MapView: Failed to save search results: \(error)")
        }
        
        // Save search string
        UserDefaults.standard.set(searchText, forKey: lastSearchStringKey)
        print("📍 MapView: Saved search string: '\(searchText)'")
    }
    
    private func loadSearchCache() {
        // Load search string
        if let savedSearchText = UserDefaults.standard.string(forKey: lastSearchStringKey) {
            searchText = savedSearchText
            print("📍 MapView: Restored search string: '\(savedSearchText)'")
        }
        
        // Load search results
        guard let data = UserDefaults.standard.data(forKey: lastSearchResultsKey) else {
            print("📍 MapView: No cached search results found")
            return
        }
        
        do {
            let cachedResults = try JSONDecoder().decode([LocationInfo].self, from: data)
            nearbyPlaces = cachedResults
            print("📍 MapView: Restored \(cachedResults.count) search results from cache")
        } catch {
            print("📍 MapView: Failed to load cached search results: \(error)")
        }
    }
    
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
    
    var filteredPlaces: [LocationInfo] {
        var filtered = nearbyPlaces
        print("🔍 filteredPlaces: nearbyPlaces count = \(nearbyPlaces.count)")
        
        // Filter by category (skip category filtering for search results)
        if selectedCategory != "All" && !filtered.allSatisfy({ $0.category == "search" }) {
            filtered = filtered.filter { $0.category?.contains(selectedCategory.lowercased()) ?? false }
            print("🔍 After category filter (\(selectedCategory)): \(filtered.count) places")
        }
        
        // Filter by search text (only when search text is provided and we're not showing search results)
        if !searchText.isEmpty && !filtered.allSatisfy({ $0.category == "search" }) {
            filtered = filtered.filter { place in
                place.name.localizedCaseInsensitiveContains(searchText) ||
                (place.address?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (place.category?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            print("🔍 After search text filter (\(searchText)): \(filtered.count) places")
        }
        
        // Debug: Print categories of first few places
        if !filtered.isEmpty {
            let sampleCategories = filtered.prefix(3).map { "\($0.name): \($0.category)" }
            print("🔍 Sample categories: \(sampleCategories)")
        }
        
        // Always filter out rejected locations
        let beforeRejectFilter = filtered.count
        filtered = filtered.filter { !isLocationRejected($0) }
        print("🔍 After reject filter: \(filtered.count) places (removed \(beforeRejectFilter - filtered.count))")
        
        print("🔍 Final filtered places count: \(filtered.count)")
        
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
            // Header with title
            HStack {
                Text("Map")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color(UIColor.systemBackground))
            
            // Always visible search bar
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
                    Button(action: {
                        searchText = ""
                        showingSuggestions = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .padding(.trailing, 8)
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // Map view - 1/4 of screen
            GeometryReader { geometry in
                if let userLocation = userLocation {
                    Map(coordinateRegion: $mapRegion, annotationItems: filteredPlaces.prefix(20).map { location in
                        MapAnnotationItem(coordinate: location.coordinate, location: location)
                    }) { annotation in
                        MapAnnotation(coordinate: annotation.coordinate) {
                            let isSelected = selectedCardLocation?.id == annotation.location?.id
                            
                            if isSelected {
                                // Pin icon for selected location
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .background(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 24, height: 24)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    .onTapGesture {
                                        if let location = annotation.location {
                                            actionRouter.execute(.addPinFromLocation(location))
                                        }
                                    }
                            } else {
                                // Circle for unselected locations
                                ZStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 16, height: 16)
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                        .frame(width: 16, height: 16)
                                }
                                .onTapGesture {
                                    if let location = annotation.location {
                                        actionRouter.execute(.addPinFromLocation(location))
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: mapRegion.center.latitude) { _ in
                        saveMapRegion()
                    }
                    .onChange(of: mapRegion.center.longitude) { _ in
                        saveMapRegion()
                    }
                    .onChange(of: mapRegion.span.latitudeDelta) { _ in
                        saveMapRegion()
                    }
                    .onChange(of: mapRegion.span.longitudeDelta) { _ in
                        saveMapRegion()
                    }
                    .onAppear {
                        // Try to load last map region first
                        loadLastMapRegion()
                        
                        // If no saved region, use user location
                        if mapRegion.center.latitude == 0 && mapRegion.center.longitude == 0 {
                            mapRegion = MKCoordinateRegion(
                                center: userLocation,
                                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                            )
                        }
                    }
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
            
            // Filter controls
            MapFilterView(
                selectedCategory: $selectedCategory,
                categories: categories
            )
            
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
                                isSelected: selectedCardLocation?.id == place.id,
                                onShareTap: { sharePlace(place) },
                                onPinTap: { 
                                    actionRouter.execute(.addPinFromLocation(place))
                                },
                                onLocationTap: { 
                                    selectedCardLocation = place
                                    showLocationOnMap(place) 
                                },
                                onNavigateTap: { sharePlace(place) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .padding(.bottom, LayoutConstants.totalToolbarHeight)
        .onAppear {
            setupToolbar()
            // Load last saved map region and search cache
            loadLastMapRegion()
            loadSearchCache()
            
            // Request location permission and get user location
            print("📍 MapView appeared")
            print("📍 Location authorization status: \(CLLocationManager.locationServicesEnabled() ? "enabled" : "disabled")")
            print("📍 Location authorization: \(locationManager.manager.authorizationStatus)")
            if let location = locationManager.lastLocation {
                userLocation = location.coordinate
                print("📍 User location available: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                // Only load new places if no cached results
                if nearbyPlaces.isEmpty {
                    loadNearbyPlaces()
                }
            } else {
                print("⚠️ No user location available")
            }
        }
        .onChange(of: locationManager.lastLocation) { _, newLocation in
            if let location = newLocation {
                userLocation = location.coordinate
                // Initialize map region to current location
                if mapRegion.center.latitude == 0 && mapRegion.center.longitude == 0 {
                    mapRegion = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                }
                if nearbyPlaces.isEmpty {
                    loadNearbyPlaces()
                }
            }
        }
        .sheet(isPresented: $showingSaveDialog) {
            NavigationView {
                SaveSearchDialog(
                    city: $saveDialogCity,
                    searchString: $saveDialogSearchString,
                    onSave: { city, searchString in
                        saveSearchAsPlaces(city: city, searchString: searchString)
                        showingSaveDialog = false
                    },
                    onCancel: {
                        showingSaveDialog = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingActionSheet) {
            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.vertical, 12)
                
                // Action buttons
                VStack(spacing: 0) {
                    PinActionButton(
                        icon: "square.and.arrow.down",
                        title: "Save Search",
                        action: {
                            showingActionSheet = false
                            showSaveDialog()
                        }
                    )
                    .disabled(nearbyPlaces.isEmpty)
                    .opacity(nearbyPlaces.isEmpty ? 0.5 : 1.0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34) // Safe area padding
            }
            .background(Color(.systemBackground))
            .presentationDetents([.medium])
        }
    }
    
    // MARK: - Location Management
    
    private func isLocationFavorited(_ location: LocationInfo) -> Bool {
        return locationPreferenceService.isLocationFavorited(location, context: viewContext)
    }
    
    private func isLocationRejected(_ location: LocationInfo) -> Bool {
        return locationPreferenceService.isLocationRejected(location, context: viewContext)
    }
    
    private func toggleFavorite(_ location: LocationInfo) {
        _ = locationPreferenceService.toggleFavorite(location, context: viewContext)
    }
    
    private func toggleReject(_ location: LocationInfo) {
        let wasRejected = locationPreferenceService.isLocationRejected(location, context: viewContext)
        _ = locationPreferenceService.toggleReject(location, context: viewContext)
        
        // If location was just rejected (dismissed), provide feedback
        if !wasRejected {
            print("📍 Location dismissed: \(location.name)")
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
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
    
    // MARK: - Save Dialog
    
    private func showSaveDialog() {
        // Get city from first location if available
        if let firstLocation = nearbyPlaces.first {
            // Try to extract city from address
            if let address = firstLocation.address {
                let addressComponents = address.components(separatedBy: ", ")
                if addressComponents.count >= 2 {
                    saveDialogCity = addressComponents[addressComponents.count - 2] // Second to last component is usually city
                } else {
                    saveDialogCity = firstLocation.name
                }
            } else {
                saveDialogCity = firstLocation.name
            }
        } else {
            saveDialogCity = ""
        }
        
        saveDialogSearchString = searchText
        showingSaveDialog = true
    }
    
    // MARK: - Search and Loading
    
    private func loadNearbyPlaces() async {
        guard let userLocation = userLocation else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        var allPlaces: [LocationInfo] = []
        
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
                
                let places = response.mapItems.prefix(10).compactMap { item -> LocationInfo? in
                    guard let location = item.placemark.location else { return nil }
                    
                    let distance = location.distance(from: CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude))
                    
                    return LocationInfo(
                        id: item.placemark.name ?? UUID().uuidString,
                        name: item.placemark.name ?? "Unknown",
                        address: formatAddress(from: item.placemark),
                        latitude: item.placemark.coordinate.latitude,
                        longitude: item.placemark.coordinate.longitude,
                        category: searchTerm,
                        phoneNumber: item.phoneNumber,
                        distance: distance,
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
            // Save search results to cache
            self.saveSearchCache()
        }
    }
    
    private func loadNearbyPlaces() {
        guard let userLocation = userLocation else { return }
        
        Task {
            await loadNearbyPlaces()
        }
    }
    
    private func searchLocations(query: String) {
        guard let userLocation = userLocation else { 
            print("❌ No user location available for search")
            return 
        }
        
        print("🔍 Searching for: '\(query)' near \(userLocation.latitude), \(userLocation.longitude)")
        isLoading = true
        
        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(
                center: userLocation,
                latitudinalMeters: 50000, // 50km radius for search
                longitudinalMeters: 50000
            )
            
            // Add specific search for restaurants in Redmond
            if query.lowercased().contains("restaurant") && query.lowercased().contains("redmond") {
                request.naturalLanguageQuery = "restaurant Redmond WA"
                print("🍽️ Enhanced search for restaurants in Redmond")
            }
            
            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                
                print("📍 Found \(response.mapItems.count) map items")
                
                let places = response.mapItems.compactMap { item -> LocationInfo? in
                    guard let location = item.placemark.location else { 
                        print("❌ Item has no location: \(item.placemark.name ?? "Unknown")")
                        return nil 
                    }
                    
                    let distance = location.distance(from: CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude))
                    
                    let place = LocationInfo(
                        id: item.placemark.name ?? UUID().uuidString,
                        name: item.placemark.name ?? "Unknown",
                        address: formatAddress(from: item.placemark),
                        latitude: item.placemark.coordinate.latitude,
                        longitude: item.placemark.coordinate.longitude,
                        category: "search",
                        phoneNumber: item.phoneNumber,
                        distance: distance,
                        url: item.url
                    )
                    
                    print("✅ Added: \(place.name) at \(place.distance/1000)km")
                    return place
                }
                
                print("🎯 Final results: \(places.count) places")
                
                await MainActor.run {
                    self.nearbyPlaces = places.sorted { $0.distance < $1.distance }
                    self.isLoading = false
                    // Save search results and query to cache
                    self.saveSearchCache()
                    
                    // Automatically navigate to first search result
                    if !places.isEmpty {
                        self.showLocationOnMap(places[0])
                    }
                    
                    if places.isEmpty {
                        print("⚠️ No results found for '\(query)' - trying broader search")
                        // Try a broader search without location restriction
                        Task {
                            await self.performBroaderSearch(query: query)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("❌ Search failed for '\(query)': \(error)")
                print("Error details: \(error.localizedDescription)")
            }
        }
    }
    
    private func performBroaderSearch(query: String) async {
        print("🌍 Performing broader search for: '\(query)'")
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        // Don't set a region - search globally
        
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            print("📍 Broader search found \(response.mapItems.count) map items")
            
            let places = response.mapItems.compactMap { item -> LocationInfo? in
                guard let location = item.placemark.location else { return nil }
                
                // Calculate distance from user location if available
                let distance: Double
                if let userLocation = userLocation {
                    distance = location.distance(from: CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude))
                } else {
                    distance = 0 // No user location available
                }
                
                let place = LocationInfo(
                    id: item.placemark.name ?? UUID().uuidString,
                    name: item.placemark.name ?? "Unknown",
                    address: formatAddress(from: item.placemark),
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude,
                    category: "search",
                    phoneNumber: item.phoneNumber,
                    distance: distance,
                    url: item.url
                )
                
                print("✅ Broader search added: \(place.name) at \(place.distance/1000)km")
                return place
            }
            
            await MainActor.run {
                if !places.isEmpty {
                    self.nearbyPlaces = places.sorted { $0.distance < $1.distance }
                    print("🎯 Broader search results: \(places.count) places")
                    
                    // Automatically navigate to first search result
                    self.showLocationOnMap(places[0])
                } else {
                    print("❌ Even broader search found no results for '\(query)'")
                }
            }
        } catch {
            print("❌ Broader search failed for '\(query)': \(error)")
        }
    }
    
    // MARK: - Actions
    
    private func showLocationOnMap(_ location: LocationInfo) {
        withAnimation(.easeInOut(duration: 0.5)) {
            mapRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    private func navigateToLocation(_ location: LocationInfo) {
        // Open navigation in external maps app
        let coordinate = location.coordinate
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = location.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
    
    private func sharePlace(_ place: LocationInfo) {
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
    
    private func pinPlace(_ place: LocationInfo) {
        // Create a new PinData object from the location
        let newPlace = PinData(context: viewContext)
        newPlace.dateAdded = Date()
        newPlace.post = place.name
        newPlace.url = place.address
        newPlace.isPrivate = false
        
        // Store location coordinates
        let clLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
        if let locationData = try? NSKeyedArchiver.archivedData(withRootObject: clLocation, requiringSecureCoding: false) {
            newPlace.setValue(locationData, forKey: "coordinates")
        }
        
        // Store location info as JSON
        let locationInfo = place
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
    
    private func saveSearchAsPlaces(city: String, searchString: String) {
        print("📍 Saving search as places: City='\(city)', Search='\(searchString)'")
        
        guard let userId = AuthenticationService.shared.currentAccount?.id, !userId.isEmpty else {
            print("❌ No user ID available for saving search")
            return
        }
        
        Task {
            do {
                // Create the list name combining city and search string
                let listName = if !searchString.isEmpty {
                    "\(city) - \(searchString)"
                } else {
                    city
                }
                
                // Create a new RListData
                let newList = RListData(context: viewContext)
                newList.id = UUID().uuidString
                newList.name = listName
                newList.createdAt = Date()
                newList.userId = userId
                // TODO: Add searchString property to Core Data model
                // newList.searchString = searchString.isEmpty ? nil : searchString
                
                print("📍 Created new list: '\(listName)' with \(filteredPlaces.count) locations")
                
                // First, save the new list to get a valid context
                try viewContext.save()
                
                // Create PinData for each location and add to list
                var createdPins: [PinData] = []
                for location in filteredPlaces {
                    // Create a PinData entry for this location
                    let pinData = PinData(context: viewContext)
                    pinData.post = location.name
                    pinData.url = "location://\(location.id)|\(location.address ?? "Unknown address")\nDistance: \(String(format: "%.1f", location.distance / 1000)) km"
                    pinData.dateAdded = Date()
                    pinData.isPrivate = false
                    
                    // Store location coordinates
                    let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                    if let locationData = try? NSKeyedArchiver.archivedData(withRootObject: clLocation, requiringSecureCoding: false) {
                        pinData.coordinates = locationData
                    }
                    
                    createdPins.append(pinData)
                }
                
                // Save the pins to get valid object IDs
                try viewContext.save()
                
                // Now create list items with valid object IDs
                for pinData in createdPins {
                    let listItem = RListItemData(context: viewContext)
                    listItem.id = UUID().uuidString
                    listItem.listId = newList.id
                    listItem.placeId = pinData.objectID.uriRepresentation().absoluteString
                    listItem.addedAt = Date()
                }
                
                // Final save with all list items
                try viewContext.save()
                print("✅ Successfully saved \(filteredPlaces.count) locations to list '\(listName)'")
                
                // Send notification to refresh any list views
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("RListDatasChanged"), object: nil)
                }
                
            } catch {
                print("❌ Failed to save search as places: \(error)")
            }
        }
    }
    
    // MARK: - Toolbar Setup
    
    private func setupToolbar() {
        let toolbarButtons = [
            ToolbarButtonConfig(
                id: "actions",
                title: "Actions",
                systemImage: "ellipsis.circle",
                action: { showingActionSheet = true },
                color: .blue,
                isFAB: true
            )
        ]
        
        toolbarManager.setCustomToolbar(buttons: toolbarButtons)
    }
}



struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let location: LocationInfo?
    
    init(coordinate: CLLocationCoordinate2D, location: LocationInfo? = nil) {
        self.coordinate = coordinate
        self.location = location
    }
}




