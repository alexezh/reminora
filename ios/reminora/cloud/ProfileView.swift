import SwiftUI
import CoreData
import CoreLocation

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var cloudSync = CloudSyncService.shared
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingFollowing = false
    @State private var showingComments = false
    @State private var isSigningOut = false
    @State private var showingDebugDialog = false
    @State private var debugURL = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    if case .authenticated(let account, _) = authService.authState {
                        VStack(spacing: 16) {
                            // Avatar
                            AsyncImage(url: URL(string: account.avatar_url ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            
                            // Name and Handle
                            VStack(spacing: 4) {
                                Text(account.display_name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                if let handle = account.handle {
                                    Text("@\(handle)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Stats Section
                    HStack(spacing: 30) {
                        VStack {
                            Text("0")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Photos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        
                        Button(action: { showingFollowing = true }) {
                            VStack {
                                Text("0")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Following")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    
                    // Sync Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cloud Sync")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack {
                            Image(systemName: cloudSync.isSyncing ? "icloud.and.arrow.up" : "icloud.and.arrow.down")
                                .foregroundColor(cloudSync.isSyncing ? .blue : .green)
                            
                            VStack(alignment: .leading) {
                                Text(cloudSync.isSyncing ? "Syncing..." : "Synced")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if let lastSync = cloudSync.lastSyncTime {
                                    Text("Last sync: \(lastSync, formatter: dateFormatter)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Never synced")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if !cloudSync.isSyncing {
                                Button("Sync Now") {
                                    Task {
                                        await cloudSync.syncToCloud()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Settings Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Settings")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 1) {
                            SettingsRow(
                                icon: "person.2",
                                title: "Manage Following",
                                action: { showingFollowing = true }
                            )
                            
                            SettingsRow(
                                icon: "bell",
                                title: "Notifications",
                                action: { /* Open notifications settings */ }
                            )
                            
                            SettingsRow(
                                icon: "lock",
                                title: "Privacy",
                                action: { /* Open privacy settings */ }
                            )
                            
                            SettingsRow(
                                icon: "questionmark.circle",
                                title: "Help & Support",
                                action: { /* Open help */ }
                            )
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Sign Out
                    Button(action: signOut) {
                        HStack {
                            if isSigningOut {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.right.square")
                                Text("Sign Out")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSigningOut)
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Debug Link") {
                        showingDebugDialog = true
                    }
                    .foregroundColor(.red)
                }
            }
            .refreshable {
                await cloudSync.syncToCloud()
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
        .sheet(isPresented: $showingFollowing) {
            FollowingView()
        }
    }
    
    private func signOut() {
        isSigningOut = true
        Task {
            await authService.signOut()
            await MainActor.run {
                isSigningOut = false
            }
        }
    }
    
    // MARK: - Debug Link Functions
    
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
        print("🔗 Note: This is the DEBUG mechanism - for actual app deep links, see reminoraApp.swift")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("❌ Failed to parse URL components")
            return
        }
        
        // Special handling for Core Data URIs in the path
        let pathString = components.path
        print("🔍 Full path: \(pathString)")
        
        let placeId: String
        
        if pathString.hasPrefix("/place/x-coredata:") {
            // Extract the Core Data URI from the path
            let coreDataURI = String(pathString.dropFirst("/place/".count))
            placeId = coreDataURI
            print("🔍 Using Core Data URI as placeId: \(placeId)")
            print("⚠️ Warning: Core Data URIs may not resolve correctly in debug mode")
            print("⚠️ Recommendation: Use actual app deep link handling instead")
        } else if pathString.hasPrefix("/x-coredata:") {
            // Handle case where URL is missing the "place" part
            let coreDataURI = String(pathString.dropFirst(1)) // Remove leading "/"
            placeId = coreDataURI
            print("🔍 Using Core Data URI without place prefix as placeId: \(placeId)")
            print("⚠️ Warning: Core Data URIs may not resolve correctly in debug mode")
        } else {
            // Normal path parsing
            let pathComponents = pathString.components(separatedBy: "/").filter { !$0.isEmpty }
            
            guard pathComponents.count >= 2,
                  pathComponents[0] == "place" else {
                print("❌ Invalid path format. Expected: /place/{id}")
                print("🔍 Path components: \(pathComponents)")
                return
            }
            
            placeId = pathComponents[1]
        }
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
        
        // Check if place already exists (by cloudId or similar content)
        let fetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
        
        // First try to find by cloudId
        if !placeId.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "cloudId == %@", placeId)
        } else {
            // Fallback: check for similar content
            fetchRequest.predicate = NSPredicate(format: "post == %@", placeName)
        }
        
        do {
            let existingPlaces = try context.fetch(fetchRequest)
            
            if let existingPlace = existingPlaces.first {
                print("ℹ️ Place already exists: \(existingPlace.post ?? "No name")")
                print("ℹ️ Navigating to existing place instead of creating duplicate")
                
                // Navigate to the existing place
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToSharedPlace"),
                    object: existingPlace
                )
                return
            }
        } catch {
            print("❌ Failed to check for existing places: \(error)")
            // Continue with creation despite the error
        }
        
        // Create new place
        do {
            let place = Place(context: context)
            place.post = placeName
            place.dateAdded = Date()
            place.cloudId = placeId
            place.isPrivate = false  // Default to public
            
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
            
            // Fetch photo from cloud/original source asynchronously
            Task {
                await fetchPhotoForSharedPlace(place: place, originalPlaceId: placeId)
            }
            
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
    
    private func fetchPhotoForSharedPlace(place: Place, originalPlaceId: String) async {
        print("🔍 Fetching photo for shared place from: \(originalPlaceId)")
        
        let context = viewContext
        
        // If it's a Core Data URI, try to find the original place in the database
        if originalPlaceId.hasPrefix("x-coredata:") {
            await fetchFromLocalCoreData(place: place, coreDataURI: originalPlaceId, context: context)
        } else {
            // For regular IDs, try to fetch from cloud
            await fetchFromCloud(place: place, cloudId: originalPlaceId, context: context)
        }
    }
    
    private func fetchFromLocalCoreData(place: Place, coreDataURI: String, context: NSManagedObjectContext) async {
        print("🔍 Attempting to resolve Core Data URI: \(coreDataURI)")
        
        do {
            // Validate URI format first
            guard coreDataURI.hasPrefix("x-coredata://") else {
                print("❌ Invalid Core Data URI format: \(coreDataURI)")
                await fallbackToCloudFetch(place: place, context: context)
                return
            }
            
            // Try to create URL from Core Data URI
            guard let url = URL(string: coreDataURI) else {
                print("❌ Failed to create URL from Core Data URI: \(coreDataURI)")
                await fallbackToCloudFetch(place: place, context: context)
                return
            }
            
            // Check if persistent store coordinator is available
            guard let coordinator = context.persistentStoreCoordinator else {
                print("❌ Persistent store coordinator is nil")
                await fallbackToCloudFetch(place: place, context: context)
                return
            }
            
            // Try to create managed object ID
            guard let objectID = coordinator.managedObjectID(forURIRepresentation: url) else {
                print("❌ Failed to create object ID from Core Data URI: \(coreDataURI)")
                print("🔍 This might happen if the original place was deleted or is in a different Core Data store")
                await fallbackToCloudFetch(place: place, context: context)
                return
            }
            
            print("✅ Successfully created object ID: \(objectID)")
            
            // Try to fetch the original place
            let originalPlace = try context.existingObject(with: objectID) as? Place
            
            await MainActor.run {
                if let originalPlace = originalPlace {
                    print("✅ Found original place: \(originalPlace.post ?? "No title")")
                    
                    if let imageData = originalPlace.imageData {
                        place.imageData = imageData
                        do {
                            try context.save()
                            print("✅ Successfully copied image from original place")
                        } catch {
                            print("❌ Failed to save image data: \(error)")
                        }
                    } else {
                        print("⚠️ Original place has no image data")
                    }
                } else {
                    print("❌ Original place not found or is not a Place entity")
                    Task {
                        await fallbackToCloudFetch(place: place, context: context)
                    }
                }
            }
        } catch {
            print("❌ Failed to fetch from Core Data: \(error)")
            print("🔍 Error details: \(error.localizedDescription)")
            await fallbackToCloudFetch(place: place, context: context)
        }
    }
    
    private func fallbackToCloudFetch(place: Place, context: NSManagedObjectContext) async {
        print("🔄 Falling back to alternative fetch method for shared place")
        
        // Try to find a place with matching coordinates and name
        await MainActor.run {
            guard let placeName = place.post,
                  let locationData = place.value(forKey: "location") as? Data,
                  let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation else {
                print("❌ Cannot extract location data for fallback search")
                return
            }
            
            let fetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "post == %@", placeName)
            
            do {
                let similarPlaces = try context.fetch(fetchRequest)
                
                // Find a place with similar location (within 100 meters)
                for similarPlace in similarPlaces {
                    if let similarLocationData = similarPlace.value(forKey: "location") as? Data,
                       let similarLocation = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(similarLocationData) as? CLLocation {
                        
                        let distance = location.distance(from: similarLocation)
                        if distance < 100 && similarPlace.imageData != nil { // Within 100 meters
                            place.imageData = similarPlace.imageData
                            try? context.save()
                            print("✅ Found similar place and copied image data (distance: \(Int(distance))m)")
                            return
                        }
                    }
                }
                
                print("⚠️ No similar places found with image data")
            } catch {
                print("❌ Failed to search for similar places: \(error)")
            }
        }
    }
    
    private func fetchFromCloud(place: Place, cloudId: String, context: NSManagedObjectContext) async {
        // This would be implemented to fetch from cloud storage
        // For now, we'll just log that we would fetch from cloud
        print("🔍 Would fetch photo from cloud for cloudId: \(cloudId)")
        
        // TODO: Implement cloud photo fetching
        // This could involve:
        // 1. Making API call to get photo URL
        // 2. Downloading image data
        // 3. Storing in place.imageData
        
        // Example implementation structure:
        /*
        do {
            let photoURL = try await APIService.shared.getPhotoURL(cloudId: cloudId)
            let imageData = try await downloadImage(from: photoURL)
            
            await MainActor.run {
                place.imageData = imageData
                try? context.save()
                print("✅ Successfully fetched and saved image from cloud")
            }
        } catch {
            print("❌ Failed to fetch from cloud: \(error)")
        }
        */
    }
    
    private func downloadImage(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.blue)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}


struct FollowingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var following: [UserProfile] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            List(following) { user in
                HStack {
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text(user.display_name)
                            .fontWeight(.medium)
                        Text("@\(user.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Unfollow") {
                        unfollowUser(user)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadFollowing()
            }
            .overlay {
                if isLoading {
                    ProgressView()
                } else if following.isEmpty {
                    Text("Not following anyone yet")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func loadFollowing() {
        Task {
            do {
                let result = try await APIService.shared.getFollowing()
                await MainActor.run {
                    self.following = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Failed to load following: \(error)")
            }
        }
    }
    
    private func unfollowUser(_ user: UserProfile) {
        Task {
            do {
                try await APIService.shared.unfollowUser(userId: user.id)
                await MainActor.run {
                    following.removeAll { $0.id == user.id }
                }
            } catch {
                print("Failed to unfollow user: \(error)")
            }
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthenticationService.shared)
    }
}