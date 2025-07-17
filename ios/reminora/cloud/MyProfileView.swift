import SwiftUI
import CoreData
import MapKit
import CoreLocation

struct MyProfileView: View {
    let userId: String
    let userName: String
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authService = AuthenticationService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var userPins: [UserPin] = []
    @State private var isLoading = true
    @State private var isFollowing = false
    @State private var isCheckingFollowStatus = true
    @State private var selectedPin: UserPin?
    @State private var showingPinDetail = false
    @State private var showingDebugDialog = false
    @State private var debugURL = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with user info and follow button
                VStack(spacing: 16) {
                    // User avatar placeholder
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(String(userName.prefix(1)).uppercased())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        )
                    
                    // User name
                    Text("@\(userName)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Stats
                    HStack(spacing: 24) {
                        VStack {
                            Text("\(userPins.count)")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Pins")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("0") // TODO: Get from backend
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Followers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("0") // TODO: Get from backend
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Following")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Follow button
                    if isCheckingFollowStatus {
                        ProgressView()
                            .frame(height: 36)
                    } else if !isCurrentUser {
                        Button(action: toggleFollow) {
                            HStack {
                                if isFollowing {
                                    Image(systemName: "checkmark")
                                    Text("Following")
                                } else {
                                    Image(systemName: "plus")
                                    Text("Follow")
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isFollowing ? .primary : .white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                            .cornerRadius(20)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Pins list
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading pins...")
                        Spacer()
                    }
                } else if userPins.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No pins shared")
                            .font(.title3)
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        Text("This user hasn't shared any pins yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(userPins, id: \.id) { pin in
                                UserPinCard(pin: pin) {
                                    selectedPin = pin
                                    showingPinDetail = true
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                if isCurrentUser {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Debug Open Link") {
                            showingDebugDialog = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingPinDetail) {
            if let pin = selectedPin {
                MyPinDetailView(pin: pin) {
                    showingPinDetail = false
                    selectedPin = nil
                }
            }
        }
        .onAppear {
            loadUserPins()
            checkFollowStatus()
        }
        .alert("Debug Open Link", isPresented: $showingDebugDialog) {
            TextField("Enter URL", text: $debugURL)
            Button("OK") {
                processDebugURL()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a deep link URL to test (e.g., reminora://place/123?name=Test&lat=37.7749&lon=-122.4194)")
        }
    }
    
    private var isCurrentUser: Bool {
        return userId == authService.currentAccount?.id
    }
    
    private func loadUserPins() {
        Task {
            do {
                print("🔍 Loading pins for user: \(userName) (ID: \(userId))")
                let pins = try await APIService.shared.getUserPins(userId: userId)
                
                await MainActor.run {
                    self.userPins = pins
                    self.isLoading = false
                    print("🔍 ✅ Loaded \(pins.count) pins for user: \(userName)")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("🔍 ❌ Failed to load pins for user \(userName): \(error)")
                }
            }
        }
    }
    
    private func checkFollowStatus() {
        guard let currentUser = authService.currentAccount, !isCurrentUser else {
            isCheckingFollowStatus = false
            return
        }
        
        // Check local Core Data first
        let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let existingFollows = try viewContext.fetch(fetchRequest)
            isFollowing = !existingFollows.isEmpty
            isCheckingFollowStatus = false
            print("🔍 Follow status for \(userName): \(isFollowing)")
        } catch {
            print("🔍 ❌ Failed to check follow status: \(error)")
            isCheckingFollowStatus = false
        }
    }
    
    private func toggleFollow() {
        guard let currentUser = authService.currentAccount else { return }
        
        Task {
            do {
                if isFollowing {
                    // Unfollow
                    try await APIService.shared.unfollowUser(userId: userId)
                    
                    // Remove from local Core Data
                    let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
                    
                    let existingFollows = try viewContext.fetch(fetchRequest)
                    for follow in existingFollows {
                        viewContext.delete(follow)
                    }
                    try viewContext.save()
                    
                    await MainActor.run {
                        self.isFollowing = false
                        print("🔍 ✅ Unfollowed user: \(userName)")
                    }
                } else {
                    // Follow
                    try await APIService.shared.followUser(userId: userId)
                    
                    // Add to local Core Data
                    let follow = UserList(context: viewContext)
                    follow.id = UUID().uuidString
                    follow.userId = userId
                    follow.name = userName
                    follow.createdAt = Date()
                    
                    try viewContext.save()
                    
                    await MainActor.run {
                        self.isFollowing = true
                        print("🔍 ✅ Followed user: \(userName)")
                    }
                }
            } catch {
                print("🔍 ❌ Failed to toggle follow for \(userName): \(error)")
            }
        }
    }
    
    private func processDebugURL() {
        guard let url = URL(string: debugURL) else {
            print("❌ Invalid URL format")
            return
        }
        
        print("🔗 Debug processing URL: \(url)")
        
        // Process the URL using the same logic as the main app
        processReminoraDeepLink(url: url)
        
        // Clear the debug URL
        debugURL = ""
    }
    
    private func processReminoraDeepLink(url: URL) {
        print("🔗 Processing Reminora deep link: \(url)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("❌ Failed to parse URL components")
            return
        }
        
        let pathComponents = components.path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        guard pathComponents.count >= 2,
              pathComponents[0] == "place" else {
            print("❌ Invalid path format. Expected: /place/{id}")
            return
        }
        
        let placeId = pathComponents[1]
        let queryItems = components.queryItems ?? []
        
        var name: String?
        var latitude: Double?
        var longitude: Double?
        var ownerId: String?
        var ownerHandle: String?
        
        for item in queryItems {
            switch item.name {
            case "name":
                name = item.value
            case "lat":
                if let value = item.value {
                    latitude = Double(value)
                }
            case "lon":
                if let value = item.value {
                    longitude = Double(value)
                }
            case "ownerId":
                ownerId = item.value
            case "ownerHandle":
                ownerHandle = item.value
            default:
                break
            }
        }
        
        guard let placeName = name,
              let lat = latitude,
              let lon = longitude else {
            print("❌ Missing required parameters: name, lat, lon")
            return
        }
        
        print("✅ Creating shared place: \(placeName) at (\(lat), \(lon))")
        
        // Create the shared place in Core Data
        let context = viewContext
        
        // Check if place already exists
        let fetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "cloudId == %@", placeId)
        
        do {
            let existingPlaces = try context.fetch(fetchRequest)
            
            if let existingPlace = existingPlaces.first {
                print("ℹ️ Place already exists: \(existingPlace.post ?? "No name")")
                return
            }
            
            // Create new place
            let place = Place(context: context)
            place.post = placeName
            place.dateAdded = Date()
            place.cloudId = placeId
            
            // Set location
            let location = CLLocation(latitude: lat, longitude: lon)
            let locationData = try NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false)
            place.setValue(locationData, forKey: "location")
            
            // Add owner info to URL field
            if let ownerId = ownerId, let ownerHandle = ownerHandle {
                place.url = "Shared by @\(ownerHandle) (ID: \(ownerId))"
            }
            
            try context.save()
            print("✅ Successfully created shared place")
            
            // Add to shared list
            addToSharedList(place: place)
            
            // Post notification to navigate to the place
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToSharedPlace"),
                object: place
            )
            
        } catch {
            print("❌ Failed to create shared place: \(error)")
        }
    }
    
    private func addToSharedList(place: Place) {
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
                // Note: UserList doesn't have isSystem property
            }
            
            // Check if place is already in the list
            let itemFetchRequest: NSFetchRequest<ListItem> = ListItem.fetchRequest()
            itemFetchRequest.predicate = NSPredicate(format: "listId == %@ AND placeId == %@", sharedList.id ?? "", place.cloudId ?? "")
            
            let existingItems = try context.fetch(itemFetchRequest)
            
            if existingItems.isEmpty {
                // Add place to shared list
                let item = ListItem(context: context)
                item.id = UUID().uuidString
                item.listId = sharedList.id
                item.placeId = place.cloudId
                item.addedAt = Date()
                
                try context.save()
                print("✅ Added place to Shared list")
            } else {
                print("ℹ️ Place already in Shared list")
            }
            
        } catch {
            print("❌ Failed to add to shared list: \(error)")
        }
    }
}

struct UserPinCard: View {
    let pin: UserPin
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Pin image placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pin.name)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    if let description = pin.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(String(format: "%.4f, %.4f", pin.latitude, pin.longitude))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct UserPin {
    let id: String
    let name: String
    let description: String?
    let latitude: Double
    let longitude: Double
    let imageUrl: String?
    let createdAt: Date
    let isPublic: Bool
}

#Preview {
    MyProfileView(userId: "test123", userName: "johndoe")
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
