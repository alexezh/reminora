import CoreData
import MapKit
import SwiftUI

func convertRegionToRect(from region: MKCoordinateRegion) -> MKMapRect {
  let center = MKMapPoint(region.center)

  let span = region.span
  let deltaLat = span.latitudeDelta
  let deltaLon = span.longitudeDelta

  let topLeftCoord = CLLocationCoordinate2D(
    latitude: region.center.latitude + (deltaLat / 2),
    longitude: region.center.longitude - (deltaLon / 2)
  )

  let bottomRightCoord = CLLocationCoordinate2D(
    latitude: region.center.latitude - (deltaLat / 2),
    longitude: region.center.longitude + (deltaLon / 2)
  )

  let topLeftPoint = MKMapPoint(topLeftCoord)
  let bottomRightPoint = MKMapPoint(bottomRightCoord)

  let origin = MKMapPoint(
    x: min(topLeftPoint.x, bottomRightPoint.x),
    y: min(topLeftPoint.y, bottomRightPoint.y))
  let size = MKMapSize(
    width: abs(topLeftPoint.x - bottomRightPoint.x),
    height: abs(topLeftPoint.y - bottomRightPoint.y))

  return MKMapRect(origin: origin, size: size)
}

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
  @State private var region = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
  )

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

  // Helper to calculate distance between two coordinates (in meters)
  private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)
    -> CLLocationDistance
  {
    let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
    let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
    return loc1.distance(from: loc2)
  }

  var body: some View {
    ZStack {
      // Search bar overlay when expanded
      if !searchText.isEmpty {
        VStack {
          HStack {
            Image(systemName: "magnifyingglass")
              .foregroundColor(.secondary)
              .padding(.leading, 8)

            TextField("Search places...", text: $searchText)
              .textFieldStyle(RoundedBorderTextFieldStyle())
              .onSubmit {
                performGeoSearch()
              }

            Button("Clear") {
              searchText = ""
              isSearching = false
            }
            .foregroundColor(.blue)
            .padding(.trailing, 8)
          }
          .padding(.horizontal, 16)
          .padding(.top, 60)
          .background(Color(.systemBackground))
          .zIndex(1)

          Spacer()
        }
      }

      // Main content using MomentBrowserView
      ZStack {
        PinBrowserView(
          places: filteredItems,
          title: "",
          showToolbar: true
        )
        
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
            .padding(.top, 60) // Below status bar
            Spacer()
          }
        }
      }
    }
    .onReceive(locationManager.$lastLocation) { location in
      guard let location = location else { return }
      DispatchQueue.main.async {
        print("updating location")
        withAnimation(.easeInOut(duration: 1.0)) {
          region = MKCoordinateRegion(
            center: location.coordinate,
            span: region.span
          )
        }
      }
    }
    .onAppear {
      syncFollowingUsersIfNeeded()
    }
    .refreshable {
      await syncFollowingUsers()
    }
  }

  // Helper to get coordinate from Place
  private func coordinate(item: Place) -> CLLocationCoordinate2D {
    if let locationData = item.value(forKey: "location") as? Data,
      let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData)
        as? CLLocation
    {
      return location.coordinate
    }
    // Default to San Francisco if no location
    return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
  }

  private func performGeoSearch() {
    guard !searchText.isEmpty else { return }

    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = searchText
    request.region = region

    let search = MKLocalSearch(request: request)
    search.start { response, error in
      DispatchQueue.main.async {
        if let error = error {
          print("Search error: \(error)")
          return
        }

        if let response = response, let firstItem = response.mapItems.first {
          let coordinate = firstItem.placemark.coordinate
          let newRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
          )

          // Set search state
          isSearching = true

          withAnimation(.easeInOut(duration: 1.0)) {
            region = newRegion
          }

          print("Geo search completed. Moved to: \(coordinate)")
        }
      }
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
