import CoreData
import MapKit
import SwiftUI


/**

 */
struct PinMainView: View {
  @Environment(\.managedObjectContext) private var viewContext
  @StateObject private var locationManager = LocationManager()
  @StateObject private var authService = AuthenticationService.shared
  @StateObject private var cloudSyncService = CloudSyncService.shared

  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Place.dateAdded, ascending: true)],
    animation: .default)
  private var items: FetchedResults<Place>

  @State private var searchText: String = ""
  @State private var isSearching: Bool = false
  @State private var isSyncingFollows = false
  @State private var lastSyncTime: Date? = nil
  @State private var selectedPlace: Place?
  @State private var selectedUser: (String, String)?
  @State private var showingActionMenu = false

  var filteredItems: [Place] {
    if !searchText.isEmpty {
      // Text search in place names/posts
      return items.filter { item in
        (item.post?.localizedCaseInsensitiveContains(searchText) ?? false)
          || (item.url?.localizedCaseInsensitiveContains(searchText) ?? false)
      }
    } else {
      // Return items sorted by date added (most recent first)
      return Array(items).sorted { a, b in
        (a.dateAdded ?? Date.distantPast) > (b.dateAdded ?? Date.distantPast)
      }
    }
  }


  var body: some View {
    GeometryReader { geometry in
      NavigationView {
        VStack(spacing: 0) {
          // Fixed header with title and action button
          HStack {
            Text("Pins")
              .font(.largeTitle)
              .fontWeight(.bold)
            
            Spacer()
            
            Menu {
              Button("Add Pin from Photo") {
                // TODO: Navigate to photo library
              }
              Button("Add Pin from Location") {
                // TODO: Navigate to location picker
              }
              Button("Search") {
                if searchText.isEmpty {
                  searchText = " " // Trigger search bar
                }
              }
            } label: {
              Image(systemName: "plus")
                .font(.title2)
            }
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 8)
          
          // Main card list
          ScrollView {
            LazyVStack(spacing: 16) {
              ForEach(filteredItems, id: \.objectID) { place in
                PinCardView(
                  place: place,
                  cardHeight: geometry.size.height * 0.25, // 1/4 screen height
                  onTitleTap: {
                    selectedPlace = place
                  },
                  onUserTap: { userId, userName in
                    selectedUser = (userId, userName)
                  }
                )
                .padding(.horizontal, 16)
              }
            }
            .padding(.top, 16)
            .padding(.bottom, 100) // Space for bottom content
          }
          .refreshable {
            await syncFollowingUsers()
          }
          
          // Search bar overlay when expanded
          if !searchText.isEmpty {
            VStack {
              HStack {
                Image(systemName: "magnifyingglass")
                  .foregroundColor(.secondary)
                  .padding(.leading, 8)

                TextField("Search places...", text: $searchText)
                  .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Clear") {
                  searchText = ""
                  isSearching = false
                }
                .foregroundColor(.blue)
                .padding(.trailing, 8)
              }
              .padding(.horizontal, 16)
              .padding(.top, 8)
              .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
              .padding(.horizontal, 16)
              
              Spacer()
            }
            .zIndex(1)
          }
          
          // Sync indicator
          if isSyncingFollows {
            VStack {
              HStack {
                Spacer()
                HStack(spacing: 8) {
                  ProgressView()
                    .scaleEffect(0.8)
                  Text("Syncing follows...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(.trailing, 16)
              }
              Spacer()
            }
          }
        }
      }
    }
    .background(
      Group {
        // Hidden NavigationLinks for programmatic navigation
        if let selectedPlace = selectedPlace {
          NavigationLink(
            destination: PinDetailView(
              place: selectedPlace,
              allPlaces: Array(items),
              onBack: {
                // Navigation will handle going back
              }
            ),
            isActive: .constant(true)
          ) {
            EmptyView()
          }
          .hidden()
        }
        
        if let selectedUser = selectedUser {
          NavigationLink(
            destination: UserProfileView(
              userId: selectedUser.0,
              userName: selectedUser.1,
              userHandle: nil
            ),
            isActive: .constant(true)
          ) {
            EmptyView()
          }
          .hidden()
        }
      }
    )
    .onAppear {
      syncFollowingUsersIfNeeded()
    }
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
      // Clear navigation state when returning to this view
      selectedPlace = nil
      selectedUser = nil
    }
  }

  
  // MARK: - Following Users Sync
  
  private func syncFollowingUsersIfNeeded() {
    // Check if we should sync based on time since last sync
    let shouldSync = shouldPerformSync()
    
    if shouldSync {
      Task {
        await syncFollowingUsers()
      }
    }
  }
  
  private func shouldPerformSync() -> Bool {
    // Only sync if authenticated
    guard authService.currentAccount != nil else {
      print("🔄 PinMainView: Skipping sync - not authenticated")
      return false
    }
    
    // Sync if no previous sync or if last sync was more than 5 minutes ago
    if let lastSync = lastSyncTime {
      let fiveMinutesAgo = Date().addingTimeInterval(-300) // 5 minutes
      let shouldSync = lastSync < fiveMinutesAgo
      print("🔄 PinMainView: Last sync: \(lastSync), should sync: \(shouldSync)")
      return shouldSync
    }
    
    print("🔄 PinMainView: No previous sync, initiating first sync")
    return true
  }
  
  private func syncFollowingUsers() async {
    guard authService.currentAccount != nil else {
      print("🔄 PinMainView: Cannot sync - not authenticated")
      return
    }
    
    await MainActor.run {
      isSyncingFollows = true
    }
    
    print("🔄 PinMainView: Starting sync of following users")
    
    do {
      // Get list of users being followed from local Core Data
      let followedUsers = await getFollowedUsers()
      print("🔄 PinMainView: Found \(followedUsers.count) followed users")
      
      // Sync pins for each followed user
      for followedUser in followedUsers {
        do {
          print("🔄 PinMainView: Syncing pins for user: \(followedUser.name ?? "unknown") (ID: \(followedUser.userId ?? "unknown"))")
          
          if let userId = followedUser.userId {
            let _ = try await cloudSyncService.syncUserPins(userId: userId, limit: 20)
            print("✅ PinMainView: Successfully synced pins for user: \(followedUser.name ?? "unknown")")
          }
        } catch {
          print("❌ PinMainView: Failed to sync user \(followedUser.name ?? "unknown"): \(error)")
        }
      }
      
      await MainActor.run {
        isSyncingFollows = false
        lastSyncTime = Date()
      }
      
      print("✅ PinMainView: Completed sync of following users")
      
    } catch {
      print("❌ PinMainView: Failed to sync following users: \(error)")
      await MainActor.run {
        isSyncingFollows = false
      }
    }
  }
  
  private func getFollowedUsers() async -> [UserList] {
    return await MainActor.run {
      let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "userId != nil AND userId != ''")
      fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
      
      do {
        let users = try viewContext.fetch(fetchRequest)
        print("📱 PinMainView: Found \(users.count) followed users in local database")
        return users
      } catch {
        print("❌ PinMainView: Failed to fetch followed users: \(error)")
        return []
      }
    }
  }

}

// MARK: - PinCardView Component

struct PinCardView: View {
  let place: Place
  let cardHeight: CGFloat
  let onTitleTap: () -> Void
  let onUserTap: (String, String) -> Void
  
  @State private var showingMap = false
  
  var body: some View {
    HStack(spacing: 0) {
      // Left side - Content
      VStack(alignment: .leading, spacing: 8) {
        // Title (tappable)
        Button(action: onTitleTap) {
          Text(place.post ?? "Untitled Pin")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
        
        // Location
        if let locationName = getLocationName() {
          HStack(spacing: 4) {
            Image(systemName: "location.fill")
              .font(.caption)
              .foregroundColor(.blue)
            Text(locationName)
              .font(.subheadline)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }
        
        // User info (tappable)
        Button(action: {
          let userId = place.value(forKey: "originalUserId") as? String ?? ""
          let userName = place.value(forKey: "originalDisplayName") as? String ?? "You"
          if !userId.isEmpty {
            onUserTap(userId, userName)
          }
        }) {
          HStack(spacing: 8) {
            Image(systemName: "person.circle.fill")
              .font(.caption)
              .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
              if let originalDisplayName = place.value(forKey: "originalDisplayName") as? String {
                Text(originalDisplayName)
                  .font(.caption)
                  .fontWeight(.medium)
                  .foregroundColor(.primary)
              } else {
                Text("You")
                  .font(.caption)
                  .fontWeight(.medium)
                  .foregroundColor(.primary)
              }
              
              if let dateAdded = place.dateAdded {
                Text(formatDate(dateAdded))
                  .font(.caption2)
                  .foregroundColor(.secondary)
              }
            }
          }
        }
        .buttonStyle(PlainButtonStyle())
        
        Spacer()
      }
      .padding(.leading, 16)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      
      // Right side - Image/Map with toggle
      ZStack {
        if showingMap {
          // Map view
          if let coordinate = getCoordinate() {
            Map(coordinateRegion: .constant(MKCoordinateRegion(
              center: coordinate,
              span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )), annotationItems: [MapAnnotationItem(coordinate: coordinate)]) { annotation in
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
            // No location placeholder
            Rectangle()
              .fill(Color.gray.opacity(0.2))
              .overlay(
                VStack(spacing: 4) {
                  Image(systemName: "location.slash")
                    .font(.title2)
                    .foregroundColor(.gray)
                  Text("No Location")
                    .font(.caption2)
                    .foregroundColor(.gray)
                }
              )
          }
        } else {
          // Image view - scale to fit properly
          if let imageData = place.imageData,
             let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: cardHeight * 1.2, height: cardHeight)
              .clipped()
          } else {
            // Placeholder image
            Rectangle()
              .fill(Color.blue.opacity(0.2))
              .frame(width: cardHeight * 1.2, height: cardHeight)
              .overlay(
                Image(systemName: "photo")
                  .font(.title2)
                  .foregroundColor(.blue)
              )
          }
        }
        
        // Toggle button - positioned relative to card area
        VStack {
          HStack {
            Spacer()
            Button(action: {
              withAnimation(.easeInOut(duration: 0.3)) {
                showingMap.toggle()
              }
            }) {
              Image(systemName: showingMap ? "photo" : "map")
                .font(.title3)
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.6), in: Circle())
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
          }
          Spacer()
        }
      }
      .frame(width: cardHeight * 1.2, height: cardHeight)
      .background(Color.gray.opacity(0.1))
      .cornerRadius(12)
    }
    .frame(height: cardHeight)
    .background(Color(.systemBackground))
    .cornerRadius(16)
    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
  }
  
  private func getLocationName() -> String? {
    // Try to get location name from URL field or reverse geocoding
    if let url = place.url, !url.isEmpty {
      return url
    }
    
    // Fallback to coordinates
    if let coordinate = getCoordinate() {
      return String(format: "%.3f, %.3f", coordinate.latitude, coordinate.longitude)
    }
    
    return nil
  }
  
  private func getCoordinate() -> CLLocationCoordinate2D? {
    if let locationData = place.value(forKey: "location") as? Data,
       let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation {
      return location.coordinate
    }
    return nil
  }
  
  private func formatDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

