import CoreData
import MapKit
import SwiftUI

struct PlaceAddress: Codable, Identifiable {
    let id = UUID()
    let coordinates: PlaceCoordinates
    let country: String?
    let city: String?
    let phone: String?
    let website: String?
    let fullAddress: String?
    
    enum CodingKeys: String, CodingKey {
        case coordinates, country, city, phone, website, fullAddress
    }
}

struct PlaceCoordinates: Codable {
    let latitude: Double
    let longitude: Double
}

/// show list of places on the map
struct PinDetailView: View {
    let place: Place
    let allPlaces: [Place]
    let onBack: () -> Void

    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var locationManager = LocationManager()

    @State private var region: MKCoordinateRegion
    @State private var showingListPicker = false
    @State private var shareData: PinShareData?
    @State private var showingNearbyPhotos = false
    @State private var showingNearbyPlaces = false
    @State private var showingActionMenu = false

    init(place: Place, allPlaces: [Place], onBack: @escaping () -> Void) {
        self.place = place
        self.allPlaces = allPlaces
        self.onBack = onBack

        // Initialize region centered on the selected place
        let coord = PinDetailView.coordinate(item: place)
        self._region = State(
            initialValue: MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
    }

    var nearbyPlaces: [Place] {
        let selectedCoord = Self.coordinate(item: place)
        return allPlaces.filter { item in
            let coord = Self.coordinate(item: item)
            let distance = Self.distance(from: selectedCoord, to: coord)
            return distance <= 1000 && item.objectID != place.objectID  // Within 1km, excluding selected
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
    
    var placeAddresses: [PlaceAddress] {
        guard let locationsJSON = place.locations,
              !locationsJSON.isEmpty,
              let data = locationsJSON.data(using: .utf8) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([PlaceAddress].self, from: data)
        } catch {
            print("Failed to decode place addresses: \(error)")
            return []
        }
    }
    
    // Get the owner information from the ListItem that contains this place
    private var sharedByInfo: (userId: String, userName: String)? {
        // Fetch the ListItem that contains this place
        let fetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "placeId == %@", place.objectID.uriRepresentation().absoluteString)
        
        do {
            let items = try viewContext.fetch(fetchRequest)
            if let item = items.first,
               let userId = item.sharedByUserId,
               let userName = item.sharedByUserName,
               !userId.isEmpty && !userName.isEmpty {
                return (userId: userId, userName: userName)
            }
        } catch {
            print("Failed to fetch ListItem for shared info: \(error)")
        }
        
        return nil
    }

    var body: some View {
        ZStack {
            // Full-screen background
            Color(.systemBackground)
                .ignoresSafeArea(.all, edges: .all)
            
            ScrollView {
                VStack(spacing: 0) {
                    
                    // Title below navigation area
                    VStack(alignment: .leading, spacing: 8) {
                        if let post = place.post, !post.isEmpty {
                            Text(post)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 80) // Reduced space for navigation buttons

                    // Comments section
                    SimpleCommentsView(targetPhotoId: place.objectID.uriRepresentation().absoluteString)
                        .padding(.top, 16)

                    // Private/Public indicator and Share button on same line
                    HStack {
                        // Private/Public indicator and shared indicator
                        HStack(spacing: 4) {
                            Image(systemName: place.isPrivate ? "lock.fill" : "globe")
                                .font(.caption)
                                .foregroundColor(place.isPrivate ? .orange : .green)
                            Text(place.isPrivate ? "Private" : "Public")
                                .font(.caption)
                                .foregroundColor(place.isPrivate ? .orange : .green)
                            
                            // Shared indicator with follow button if applicable
                            if isSharedItem {
                                HStack(spacing: 4) {
                                    Image(systemName: "shared.with.you")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    
                                    if let shareInfo = sharedByInfo {
                                        Text("by @\(shareInfo.userName)")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        
                                        Button("Follow") {
                                            followUser(userId: shareInfo.userId, userName: shareInfo.userName)
                                        }
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                    } else {
                                        Text("Shared")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Share button on the right
                        Button(action: {
                            sharePlace()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(20)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    // Addresses section
                    if !placeAddresses.isEmpty {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Locations")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            ForEach(placeAddresses) { address in
                                AddressCardView(address: address)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                    }

                    // Photo
                    if let imageData = place.imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 400)
                            .clipped()
                            .padding(.top, 20)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 300)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                            )
                            .padding(.top, 20)
                    }

                    // Date below photo
                    if let date = place.dateAdded {
                        Text(date, formatter: itemFormatter)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Map at the bottom
                    Map(coordinateRegion: $region, annotationItems: [place] + nearbyPlaces) { item in
                        MapAnnotation(coordinate: Self.coordinate(item: item)) {
                            Button(action: {
                                // Could navigate to this place if desired
                            }) {
                                Image(
                                    systemName: item.objectID == place.objectID
                                        ? "mappin.circle.fill" : "mappin.circle"
                                )
                                .font(.title2)
                                .foregroundColor(item.objectID == place.objectID ? .red : .blue)
                            }
                        }
                    }
                    .frame(height: 250)
                    .allowsHitTesting(false)
                    .padding(.top, 20)
                    .padding(.bottom, 40) // Bottom safe area
                }
            }
            
            // Floating navigation overlay (similar to SwipePhotoView)
            VStack {
                HStack {
                    // Back button
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }
                    
                    Spacer()
                    
                    // Action button
                    Button(action: {
                        showingActionMenu = true
                    }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10) // Minimal top spacing - closer to top
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $shareData) { data in
            let _ = print("PinDetailView ShareSheet - text: '\(data.message)', url: '\(data.link)'")
            ShareSheet(text: data.message, url: data.link)
        }
        .sheet(isPresented: $showingNearbyPhotos) {
            NavigationView {
                NearbyPhotosGridView(centerLocation: Self.coordinate(item: place), onDismiss: {
                    showingNearbyPhotos = false
                })
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showingNearbyPlaces) {
            NearbyLocationsPageView(
                searchLocation: Self.coordinate(item: place),
                locationName: place.post ?? "this location"
            )
        }
        .actionSheet(isPresented: $showingActionMenu) {
            ActionSheet(
                title: Text("Actions"),
                buttons: [
                    .default(Text("View on Map")) {
                        showNearbyPlaces()
                    },
                    .default(Text("Nearby Photos")) {
                        showNearbyPhotos()
                    },
                    .default(Text("Add to Quick List")) {
                        addToQuickList()
                    },
                    .cancel()
                ]
            )
        }
    }

    // MARK: - Actions

    private func followUser(userId: String, userName: String) {
        print("🔗 Follow button tapped for user: \(userName) (ID: \(userId))")
        
        guard let currentUser = authService.currentAccount else {
            print("🔗 ❌ No current user found")
            return
        }
        
        // Check if already following
        let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let existingFollows = try viewContext.fetch(fetchRequest)
            if !existingFollows.isEmpty {
                print("🔗 ℹ️ Already following user: \(userName)")
                return
            }
            
            // Create new follow relationship
            let follow = UserList(context: viewContext)
            follow.id = UUID().uuidString
            follow.userId = userId
            follow.name = userName
            follow.createdAt = Date()
            
            try viewContext.save()
            print("🔗 ✅ Successfully followed user: \(userName)")
            
            // Show success feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
        } catch {
            print("🔗 ❌ Failed to follow user: \(error)")
        }
    }

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
        fetchRequest.predicate = NSPredicate(
            format: "name == %@ AND userId == %@", "Quick", currentUser.id)

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

        // Add owner information from auth service
        let ownerId = authService.currentAccount?.id ?? ""
        let ownerHandle = authService.currentAccount?.handle ?? ""
        let encodedOwnerHandle = ownerHandle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let reminoraLink = "reminora://place/\(placeId)?name=\(encodedName)&lat=\(lat)&lon=\(lon)&ownerId=\(ownerId)&ownerHandle=\(encodedOwnerHandle)"

        let message = "Check out \(place.post ?? "this place") on Reminora!"
        
        shareData = PinShareData(message: message, link: reminoraLink)
        print("PinDetailView - After assignment - shareData:", shareData?.message ?? "nil", shareData?.link ?? "nil")
    }

    // Helper methods
    static func coordinate(item: Place) -> CLLocationCoordinate2D {
        if let locationData = item.value(forKey: "location") as? Data,
            let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData)
                as? CLLocation
        {
            return location.coordinate
        }
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }

    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)
        -> CLLocationDistance
    {
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

struct PinShareData: Identifiable {
    let id = UUID()
    let message: String
    let link: String
}

struct AddressCardView: View {
    let address: PlaceAddress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Full address or city/country
            if let fullAddress = address.fullAddress, !fullAddress.isEmpty {
                Text(fullAddress)
                    .font(.body)
                    .foregroundColor(.primary)
            } else if let city = address.city, let country = address.country {
                Text("\(city), \(country)")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            // Additional info in a horizontal layout
            HStack(spacing: 16) {
                // Phone
                if let phone = address.phone, !phone.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(phone)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .onTapGesture {
                        if let url = URL(string: "tel:\(phone)") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                
                // Website
                if let website = address.website, !website.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Website")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .onTapGesture {
                        if let url = URL(string: website) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                
                Spacer()
                
                // Coordinates
                Text(String(format: "%.4f, %.4f", address.coordinates.latitude, address.coordinates.longitude))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
