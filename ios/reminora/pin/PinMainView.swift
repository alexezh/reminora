import CoreData
import MapKit
import SwiftUI


/**

 */
struct PinMainView: View {
  @Environment(\.managedObjectContext) private var viewContext
  @Environment(\.toolbarManager) private var toolbarManager
  @StateObject private var locationManager = LocationManager()
  @StateObject private var authService = AuthenticationService.shared
  @StateObject private var cloudSyncService = CloudSyncService.shared
  @StateObject private var pinFilterService = PinFilterService.shared

  @FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \PinData.dateAdded, ascending: true)],
    animation: .default)
  private var items: FetchedResults<PinData>

  @State private var searchText: String = ""
  @State private var isSearching: Bool = false
  @State private var isSyncingFollows = false
  @State private var lastSyncTime: Date? = nil
  @State private var selectedPlace: PinData?
  @State private var selectedUser: (String, String)?
  @State private var selectedLocationPlace: PinData?
  @State private var showingPinDetail = false
  @State private var showingUserProfile = false
  @State private var showingNearbyLocations = false
  @State private var showingActionMenu = false
  @State private var showingOpenInvite = false
  @State private var showingAddPin = false
  
  // Sort options
  enum SortOption: String, CaseIterable {
    case recent = "recent"
    case distance = "distance"
    
    var displayName: String {
      switch self {
      case .recent: return "Recent"
      case .distance: return "Distance"
      }
    }
  }
  
  @State private var selectedSortOption: SortOption = .recent
  
  private let sortPreferenceKey = "PinMainView.sortOption"

  var filteredItems: [PinData] {
    var allItems = Array(items)
    
    // Apply sorting based on selected option
    switch selectedSortOption {
    case .recent:
      allItems = allItems.sorted { a, b in
        (a.dateAdded ?? Date.distantPast) > (b.dateAdded ?? Date.distantPast)
      }
    case .distance:
      // Sort by distance from current location
      if let userLocation = locationManager.lastLocation {
        allItems = allItems.sorted { a, b in
          let distanceA = distanceFromUserLocation(place: a, userLocation: userLocation)
          let distanceB = distanceFromUserLocation(place: b, userLocation: userLocation)
          return distanceA < distanceB
        }
      } else {
        // Fallback to recent if no location available
        allItems = allItems.sorted { a, b in
          (a.dateAdded ?? Date.distantPast) > (b.dateAdded ?? Date.distantPast)
        }
      }
    }
    
    // Trim whitespace from search text for more responsive filtering
    let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if !trimmedSearchText.isEmpty {
      // Use PinFilterService for fuzzy search
      let filtered = pinFilterService.filterPins(allItems, searchText: trimmedSearchText)
      return pinFilterService.sortByRelevance(filtered, searchText: trimmedSearchText)
    } else {
      // Return items with applied sort
      return allItems
    }
  }
  
  // Helper function to calculate distance from user location
  private func distanceFromUserLocation(place: PinData, userLocation: CLLocation) -> CLLocationDistance {
    guard let locationData = place.value(forKey: "coordinates") as? Data,
          let placeLocation = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation else {
      return CLLocationDistance.greatestFiniteMagnitude // Place at end if no location
    }
    return userLocation.distance(from: placeLocation)
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        NavigationView {
        VStack(spacing: 0) {
          // Fixed header with title and buttons
          HStack {
            Text("Pins")
              .font(.largeTitle)
              .fontWeight(.bold)
            
            Spacer()
            
            // Search button
            Button(action: {
              withAnimation(.easeInOut(duration: 0.3)) {
                isSearching.toggle()
                if !isSearching {
                  searchText = ""
                }
              }
            }) {
              Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                .font(.title2)
                .foregroundColor(.blue)
            }
          }
          .padding(.horizontal, 16)
          .padding(.top, 8) // Top safe area padding
          .padding(.bottom, 8)
          
          // Search bar (when active)
          if isSearching {
            HStack {
              Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .padding(.leading, 8)

              TextField("Search by location or title...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 8)
                .onChange(of: searchText) { _ in
                  // Ensure immediate UI update for search results
                  DispatchQueue.main.async {
                    // This forces a view update cycle
                  }
                }

              if !searchText.isEmpty {
                Button("Clear") {
                  searchText = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.trailing, 8)
              }
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.opacity)
          }
          
          // Main card list
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(filteredItems, id: \.objectID) { place in
                PinCardView(
                  place: place,
                  cardHeight: geometry.size.height * 0.27, // Slightly larger to accommodate shadow
                  onPhotoTap: {
                    selectedPlace = place
                    showingPinDetail = true
                  },
                  onTitleTap: {
                    selectedPlace = place
                    showingPinDetail = true
                  },
                  onMapTap: {
                    selectedLocationPlace = place
                    showingNearbyLocations = true
                  },
                  onUserTap: { userId, userName in
                    selectedUser = (userId, userName)
                    showingUserProfile = true
                  }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
              }
            }
            .padding(.top, 16)
            .padding(.bottom, 120) // Extra space for custom toolbar + safe area
          }
          .refreshable {
            await performBackgroundSync()
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
        
        // Hidden NavigationLinks for programmatic navigation
        if let selectedPlace = selectedPlace {
          NavigationLink(
            destination: PinDetailView(
              place: selectedPlace,
              allPlaces: Array(items),
              onBack: {
                showingPinDetail = false
                self.selectedPlace = nil
              }
            ),
            isActive: $showingPinDetail
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
            isActive: $showingUserProfile
          ) {
            EmptyView()
          }
          .hidden()
        }
        
        if let selectedLocationPlace = selectedLocationPlace {
          NavigationLink(
            destination: NearbyLocationsView(
              searchLocation: getLocationFromPlace(selectedLocationPlace)?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
              locationName: selectedLocationPlace.post ?? "this location"
            ),
            isActive: $showingNearbyLocations
          ) {
            EmptyView()
          }
          .hidden()
        }
      }
    }
    .onAppear {
      loadSortPreference()
      syncFollowingUsersIfNeeded()
    }
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
      // App returned from background - sync if needed
      syncFollowingUsersIfNeeded()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AddPin"))) { _ in
      print("🔧 PinMainView received AddPin notification")
      showingAddPin = true
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AddOpenInvite"))) { _ in
      print("🔧 PinMainView received AddOpenInvite notification")
      showingOpenInvite = true
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleSort"))) { _ in
      print("🔧 PinMainView received ToggleSort notification")
      // Toggle between Recent and Distance sorting
      selectedSortOption = selectedSortOption == .recent ? .distance : .recent
      saveSortPreference()
    }
    .sheet(isPresented: $showingOpenInvite) {
      OpenInviteView()
    }
    .sheet(isPresented: $showingAddPin) {
      MapView()
    }
  }

  
  // MARK: - Sort Preferences
  
  private func loadSortPreference() {
    if let savedSort = UserDefaults.standard.string(forKey: sortPreferenceKey),
       let sortOption = SortOption(rawValue: savedSort) {
      selectedSortOption = sortOption
    }
  }
  
  private func saveSortPreference() {
    UserDefaults.standard.set(selectedSortOption.rawValue, forKey: sortPreferenceKey)
  }
  
  // MARK: - Following Users Sync
  
  private func syncFollowingUsersIfNeeded() {
    // Check if we should sync based on time since last sync
    let shouldSync = shouldPerformSync()
    
    if shouldSync {
      Task {
        await performBackgroundSync()
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
  
  private func performBackgroundSync() async {
    // Perform sync operations entirely in background to avoid UI blocking
    await Task.detached {
      await self.syncFollowingUsers()
    }.value
  }
  
  private func syncFollowingUsers() async {
    guard authService.currentAccount != nil else {
      print("🔄 PinMainView: Cannot sync - not authenticated")
      return
    }
    
    // Update UI state on main actor with minimal work
    await MainActor.run {
      isSyncingFollows = true
    }
    
    print("🔄 PinMainView: Starting sync of following users")
    
    do {
      // Get list of users being followed from local Core Data (background operation)
      let followedUsers = await getFollowedUsers()
      print("🔄 PinMainView: Found \(followedUsers.count) followed users")
      
      // Sync pins for each followed user (background operation)
      await withTaskGroup(of: Void.self) { group in
        for followedUser in followedUsers {
          group.addTask {
            do {
              if let userId = followedUser.userId {
                let _ = try await self.cloudSyncService.syncUserPins(userId: userId, limit: 20)
                print("✅ PinMainView: Successfully synced pins for user: \(followedUser.name ?? "unknown")")
              }
            } catch {
              print("❌ PinMainView: Failed to sync user \(followedUser.name ?? "unknown"): \(error)")
            }
          }
        }
      }
      
      // Update UI state on completion
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
  
  private func getFollowedUsers() async -> [RListData] {
    // Perform Core Data operations on background queue to avoid UI blocking
    return await withCheckedContinuation { continuation in
      Task.detached {
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        backgroundContext.perform {
          let fetchRequest: NSFetchRequest<RListData> = RListData.fetchRequest()
          fetchRequest.predicate = NSPredicate(format: "userId != nil AND userId != ''")
          fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
          
          do {
            let users = try backgroundContext.fetch(fetchRequest)
            print("📱 PinMainView: Found \(users.count) followed users in local database")
            continuation.resume(returning: users)
          } catch {
            print("❌ PinMainView: Failed to fetch followed users: \(error)")
            continuation.resume(returning: [])
          }
        }
      }
    }
  }
  
  private func getLocationFromPlace(_ place: PinData) -> CLLocation? {
    if let locationData = place.value(forKey: "coordinates") as? Data,
       let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation {
      return location
    }
    return nil
  }
  
  // MARK: - Toolbar Setup
  
  private func setupToolbar() {
    let toolbarButtons = [
      // Navigation buttons
      ToolbarButtonConfig(
        id: "photos",
        title: "Photos",
        systemImage: "photo",
        action: { 
          NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: "Photo")
        },
        color: .blue
      ),
      ToolbarButtonConfig(
        id: "map",
        title: "Map",
        systemImage: "map",
        action: { 
          NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: "Map")
        },
        color: .green
      ),
      // Action buttons
      ToolbarButtonConfig(
        id: "add",
        title: "Add Pin",
        systemImage: "plus",
        action: { showingAddPin = true },
        color: .orange
      ),
      ToolbarButtonConfig(
        id: "lists",
        title: "Lists",
        systemImage: "list.bullet.circle",
        action: { 
          NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: "Lists")
        },
        color: .purple
      )
    ]
    
    toolbarManager.setCustomToolbar(buttons: toolbarButtons)
  }

}



