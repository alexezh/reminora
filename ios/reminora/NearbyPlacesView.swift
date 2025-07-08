import CoreData
import MapKit
import SwiftUI

struct NearbyPlacesView: View {
    let coordinate: CLLocationCoordinate2D
    @State private var nearbyPlaces: [MKMapItem] = []
    @State private var isLoadingPlaces = false
    @State private var selectedCategories: Set<MKPointOfInterestCategory> = []
    @State private var showCategoryPicker = false
    
    let availableCategories: [MKPointOfInterestCategory] = [
        .restaurant, .cafe, .store, .gasStation, .hotel, .hospital, .school,
        .museum, .library, .park, .beach, .amusementPark, .theater, .movieTheater,
        .bank, .atm, .pharmacy, .airport, .publicTransport, .parking
    ]
    
    var filteredPlaces: [MKMapItem] {
        if selectedCategories.isEmpty {
            return nearbyPlaces
        }
        let filtered = nearbyPlaces.filter { item in
            guard let category = item.pointOfInterestCategory else { 
                print("NearbyPlacesView: Place '\(item.name ?? "Unknown")' has no category")
                return false 
            }
            let matches = selectedCategories.contains(category)
            print("NearbyPlacesView: Place '\(item.name ?? "Unknown")' has category '\(categoryDisplayName(category))', matches filter: \(matches)")
            return matches
        }
        print("NearbyPlacesView: Filtering \(nearbyPlaces.count) places by \(selectedCategories.count) categories (\(selectedCategories.map { categoryDisplayName($0) }.joined(separator: ", "))), result: \(filtered.count) places")
        return filtered
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Nearby Places")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    print("NearbyPlacesView: Opening category picker, current selection: \(selectedCategories.count) categories")
                    showCategoryPicker = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(selectedCategories.isEmpty ? "Filter" : "\(selectedCategories.count)")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Fixed height scrollable list
            ScrollView {
                LazyVStack(spacing: 6) {
                    if isLoadingPlaces {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading nearby places...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    } else if filteredPlaces.isEmpty && !nearbyPlaces.isEmpty {
                        Text("No places match selected categories")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(filteredPlaces.prefix(20), id: \.self) { mapItem in
                            HStack(spacing: 10) {
                                Image(systemName: iconForPlaceType(mapItem.pointOfInterestCategory))
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.blue)
                                    .background(Color.blue.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(mapItem.name ?? "Unknown Place")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    if let category = mapItem.pointOfInterestCategory {
                                        Text(categoryDisplayName(category))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if let itemCoordinate = mapItem.placemark.location?.coordinate {
                                    Text("\(Int(distance(from: coordinate, to: itemCoordinate)))m")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
            .frame(maxHeight: 200) // Limit height so it doesn't take up whole screen
        }
        .onAppear {
            loadSavedCategories()
            searchNearbyPlaces()
        }
        .onChange(of: selectedCategories) { newCategories in
            print("NearbyPlacesView: Categories changed to \(newCategories.count) selected")
            saveCategoriesSelection()
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerView(
                availableCategories: availableCategories,
                selectedCategories: $selectedCategories
            )
        }
    }
    
    private func searchNearbyPlaces() {
        print("NearbyPlacesView: Searching for coordinate: \(coordinate.latitude), \(coordinate.longitude)")
        isLoadingPlaces = true
        
        // Perform multiple searches with different terms to get comprehensive results
        let searchTerms = [
            "restaurant food dining",
            "cafe coffee shop",
            "store shop market retail",
            "hotel accommodation lodging",
            "gas station fuel petrol",
            "hospital medical clinic",
            "bank atm financial",
            "pharmacy drugstore medicine",
            "shopping mall center",
            "park recreation",
            "school university education",
            "museum gallery culture",
            "theater cinema entertainment",
            "airport transport",
            "parking garage"
        ]
        
        var allResults: [MKMapItem] = []
        var completedSearches = 0
        let totalSearches = searchTerms.count
        
        for searchTerm in searchTerms {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchTerm
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 4000, // Increase to 4km radius for better coverage
                longitudinalMeters: 4000
            )
            request.resultTypes = [.pointOfInterest]
            
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                DispatchQueue.main.async {
                    completedSearches += 1
                    
                    if let error = error {
                        print("NearbyPlacesView: Search error for '\(searchTerm)': \(error)")
                    } else if let response = response {
                        print("NearbyPlacesView: Found \(response.mapItems.count) places for '\(searchTerm)'")
                        allResults.append(contentsOf: response.mapItems)
                    }
                    
                    // When all searches are complete, process results
                    if completedSearches == totalSearches {
                        self.processSearchResults(allResults)
                    }
                }
            }
        }
    }
    
    private func processSearchResults(_ results: [MKMapItem]) {
        print("NearbyPlacesView: Processing \(results.count) total results from all searches")
        
        // Remove duplicates and filter by distance
        var uniqueResults: [String: MKMapItem] = [:]
        var placesWithDistance: [(MKMapItem, Double)] = []
        
        for item in results {
            guard let name = item.name,
                  !name.lowercased().contains("points of interest"),
                  !name.lowercased().contains("afewpointsofinterest"),
                  let itemLocation = item.placemark.location else {
                continue
            }
            
            let dist = itemLocation.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            
            // Only include places within 5km
            if dist <= 5000 {
                // Use name + coordinate as unique key to avoid duplicates
                let key = "\(name)_\(itemLocation.coordinate.latitude)_\(itemLocation.coordinate.longitude)"
                
                // Keep the closest instance if we have duplicates
                if let existing = uniqueResults[key] {
                    if let existingLocation = existing.placemark.location {
                        let existingDist = existingLocation.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                        if dist < existingDist {
                            uniqueResults[key] = item
                        }
                    }
                } else {
                    uniqueResults[key] = item
                }
            }
        }
        
        // Convert to array with distances and sort
        for item in uniqueResults.values {
            if let itemLocation = item.placemark.location {
                let dist = itemLocation.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                placesWithDistance.append((item, dist))
                print("NearbyPlacesView: Place: \(item.name ?? "Unknown"), Distance: \(Int(dist))m")
            }
        }
        
        let sortedPlaces = placesWithDistance.sorted { $0.1 < $1.1 }.map { $0.0 }
        
        print("NearbyPlacesView: Filtered to \(sortedPlaces.count) unique nearby places")
        nearbyPlaces = Array(sortedPlaces.prefix(50)) // Increase limit to 50
        
        // Debug: Show what categories we found
        nearbyPlaces.forEach { item in
            let categoryName = item.pointOfInterestCategory.map { categoryDisplayName($0) } ?? "No Category"
            print("NearbyPlacesView: Found place '\(item.name ?? "Unknown")' with category '\(categoryName)'")
        }
        
        isLoadingPlaces = false
    }
    
    private func loadSavedCategories() {
        let savedCategoryNames = UserDefaults.standard.stringArray(forKey: "NearbyPlacesSelectedCategories") ?? []
        selectedCategories = Set(savedCategoryNames.compactMap { categoryName in
            availableCategories.first { categoryDisplayName($0) == categoryName }
        })
        print("NearbyPlacesView: Loaded \(selectedCategories.count) saved categories")
    }
    
    private func saveCategoriesSelection() {
        let categoryNames = selectedCategories.map { categoryDisplayName($0) }
        UserDefaults.standard.set(categoryNames, forKey: "NearbyPlacesSelectedCategories")
        print("NearbyPlacesView: Saved \(categoryNames.count) categories to UserDefaults")
    }
    
    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }
    
    private func iconForPlaceType(_ category: MKPointOfInterestCategory?) -> String {
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
    
    private func categoryDisplayName(_ category: MKPointOfInterestCategory) -> String {
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

struct CategoryPickerView: View {
    let availableCategories: [MKPointOfInterestCategory]
    @Binding var selectedCategories: Set<MKPointOfInterestCategory>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(availableCategories, id: \.self) { category in
                    HStack {
                        Image(systemName: iconForCategory(category))
                            .frame(width: 24, height: 24)
                            .foregroundColor(.blue)
                        
                        Text(displayName(for: category))
                        
                        Spacer()
                        
                        if selectedCategories.contains(category) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedCategories.contains(category) {
                            selectedCategories.remove(category)
                            print("CategoryPicker: Removed \(displayName(for: category)), now have \(selectedCategories.count) categories")
                        } else {
                            selectedCategories.insert(category)
                            print("CategoryPicker: Added \(displayName(for: category)), now have \(selectedCategories.count) categories")
                        }
                    }
                }
            }
            .navigationTitle("Filter Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        selectedCategories.removeAll()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func iconForCategory(_ category: MKPointOfInterestCategory) -> String {
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
    
    private func displayName(for category: MKPointOfInterestCategory) -> String {
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