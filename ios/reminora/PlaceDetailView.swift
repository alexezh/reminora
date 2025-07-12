import CoreData
import MapKit
import SwiftUI

struct PlaceDetailView: View {
    let place: Place
    let allPlaces: [Place]
    let onBack: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var locationManager = LocationManager()
    
    @State private var region: MKCoordinateRegion
    @State private var showingListPicker = false
    @State private var showingShareSheet = false
    @State private var shareText = ""
    @State private var showingNearbyPlaces = false
    @State private var showingNearbyPhotos = false
    
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
    
    var isSharedItem: Bool {
        // Check if this place came from a shared link by looking at the URL field
        return place.url?.contains("Shared via Reminora link") == true
    }
    
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Action buttons at top
                HStack {
                    Spacer()
                    
                    Button(action: {
                        showNearbyPlaces()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "map")
                            Text("Map")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                    }
                    
                    Button(action: {
                        showNearbyPhotos()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Photos")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                    }
                    
                    Button(action: {
                        addToQuickList()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                            Text("Quick")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                    }
                    
                    Button(action: {
                        sharePlace()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                // Photo taking full width
                if let imageData = place.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
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
                
                // Photo caption and details
                VStack(alignment: .leading, spacing: 8) {
                    // Shared indicator if applicable
                    if isSharedItem {
                        HStack {
                            Image(systemName: "shared.with.you")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Shared with you")
                                .font(.caption)
                                .foregroundColor(.green)
                            Spacer()
                        }
                    }
                    
                    // Caption text (Facebook-style)
                    if let post = place.post, !post.isEmpty {
                        Text(post)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Comments section (simplified, no box)
                SimpleCommentsView(targetPhotoId: place.objectID.uriRepresentation().absoluteString)
                    .padding(.top, 8)
                
                // Date below comments
                if let date = place.dateAdded {
                    Text(date, formatter: itemFormatter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Map at the bottom
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
                .padding(.top, 16)
            }
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
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(text: shareText)
        }
        .sheet(isPresented: $showingNearbyPlaces) {
            NavigationView {
                PlaceBrowserView(
                    places: nearbyPlaces,
                    title: "Nearby Places",
                    showToolbar: false
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingNearbyPlaces = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingNearbyPhotos) {
            NavigationView {
                NearbyPhotosGridView(centerLocation: Self.coordinate(item: place))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingNearbyPhotos = false
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Actions
    
    private func showNearbyPlaces() {
        showingNearbyPlaces = true
    }
    
    private func showNearbyPhotos() {
        showingNearbyPhotos = true
    }
    
    private func addToQuickList() {
        guard let currentUser = authService.currentAccount else { return }
        
        // Find or create Quick list
        let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@ AND userId == %@", "Quick", currentUser.id)
        
        do {
            let quickLists = try viewContext.fetch(fetchRequest)
            let quickList: UserList
            
            if let existingList = quickLists.first {
                quickList = existingList
            } else {
                // Create Quick list
                quickList = UserList(context: viewContext)
                quickList.id = UUID().uuidString
                quickList.name = "Quick"
                quickList.createdAt = Date()
                quickList.userId = currentUser.id
            }
            
            // Add item to Quick list
            let listItem = ListItem(context: viewContext)
            listItem.id = UUID().uuidString
            listItem.placeId = place.objectID.uriRepresentation().absoluteString
            listItem.addedAt = Date()
            listItem.listId = quickList.id ?? ""
            
            try viewContext.save()
            
            // Show success feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            print("Added place to Quick list: \(place.post ?? "Unknown")")
            
        } catch {
            print("Failed to add place to Quick list: \(error)")
        }
    }
    
    private func sharePlace() {
        let coord = Self.coordinate(item: place)
        let placeId = place.objectID.uriRepresentation().absoluteString
        let encodedName = (place.post ?? "Unknown Place").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let lat = coord.latitude
        let lon = coord.longitude
        
        let reminoraLink = "https://reminora.app/place/\(placeId)?name=\(encodedName)&lat=\(lat)&lon=\(lon)"
        
        shareText = "Check out \(place.post ?? "this place") on Reminora!\n\n\(reminoraLink)"
        showingShareSheet = true
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

