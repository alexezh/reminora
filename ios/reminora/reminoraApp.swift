//
//  reminoraApp.swift
//  reminora
//
//  Created by alexezh on 5/26/25.
//

import SwiftUI
import GoogleSignIn
import CoreData
import CoreLocation

@main
struct reminoraApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authService = AuthenticationService.shared

    init() {
        configureGoogleSignIn()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch authService.authState {
                case .loading:
                    SplashView()
                case .unauthenticated, .error:
                    LoginView()
                case .needsHandle:
                    LoginView() // HandleSetupView will be presented as sheet
                case .authenticated:
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                }
            }
            .environmentObject(authService)
            .onOpenURL { url in
                print("🔗 onOpenURL called with: \(url)")
                print("🔗 URL scheme: \(url.scheme ?? "nil")")
                print("🔗 URL host: \(url.host ?? "nil")")
                print("🔗 URL path: \(url.path)")
                print("🔗 URL query: \(url.query ?? "nil")")
                
                // Handle Google Sign-In URLs
                if url.scheme == "com.googleusercontent.apps" {
                    print("🔗 Handling Google Sign-In URL")
                    GIDSignIn.sharedInstance.handle(url)
                }
                // Handle Reminora deep links
                else if url.scheme == "reminora" {
                    print("🔗 Handling Reminora deep link")
                    handleReminoraLink(url)
                } else {
                    print("🔗 Unhandled URL scheme: \(url.scheme ?? "nil")")
                }
            }
        }
    }
    
    private func configureGoogleSignIn() {
        // Configure Google Sign-In when GoogleService-Info.plist is available
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("GoogleService-Info.plist not found or CLIENT_ID missing")
            return
        }
        
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config
        print("Google Sign-In configured successfully")
    }
    
    private func handleReminoraLink(_ url: URL) {
        print("🔗 handleReminoraLink called with: \(url)")
        
        guard url.scheme == "reminora",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("🔗 ❌ Failed to parse URL components")
            return
        }
        
        print("🔗 URL components: \(components)")
        print("🔗 Path components: \(url.pathComponents)")
        
        // Handle different link types
        if url.pathComponents.contains("place") {
            print("🔗 ✅ Found 'place' in path, calling handlePlaceLink")
            handlePlaceLink(components)
        } else {
            print("🔗 ❌ No 'place' found in path components: \(url.pathComponents)")
        }
    }
    
    private func handlePlaceLink(_ components: URLComponents) {
        print("🔗 handlePlaceLink called with components: \(components)")
        
        guard let queryItems = components.queryItems else {
            print("🔗 ❌ No query items found")
            return
        }
        
        print("🔗 Query items: \(queryItems)")
        
        guard let name = queryItems.first(where: { $0.name == "name" })?.value,
              let latString = queryItems.first(where: { $0.name == "lat" })?.value,
              let lonString = queryItems.first(where: { $0.name == "lon" })?.value,
              let lat = Double(latString),
              let lon = Double(lonString) else {
            print("🔗 ❌ Failed to parse required parameters:")
            print("🔗    name: \(queryItems.first(where: { $0.name == "name" })?.value ?? "nil")")
            print("🔗    lat: \(queryItems.first(where: { $0.name == "lat" })?.value ?? "nil")")
            print("🔗    lon: \(queryItems.first(where: { $0.name == "lon" })?.value ?? "nil")")
            return
        }
        
        // Extract owner information (optional)
        let ownerId = queryItems.first(where: { $0.name == "ownerId" })?.value ?? ""
        let ownerHandle = queryItems.first(where: { $0.name == "ownerHandle" })?.value ?? ""
        
        print("🔗 ✅ Parsed parameters:")
        print("🔗    name: \(name)")
        print("🔗    lat: \(lat)")
        print("🔗    lon: \(lon)")
        print("🔗    ownerId: \(ownerId)")
        print("🔗    ownerHandle: \(ownerHandle)")
        
        // Extract place ID from path if available
        let pathComponents = components.url?.pathComponents ?? []
        var originalPlaceId: String?
        if pathComponents.count > 2 && pathComponents[1] == "place" {
            originalPlaceId = pathComponents[2]
        }
        
        print("🔗 Path components: \(pathComponents)")
        print("🔗 Original place ID: \(originalPlaceId ?? "nil")")
        
        // Create a new place and add it to the shared list
        let context = persistenceController.container.viewContext
        
        print("🔗 Creating new place...")
        // Create the place
        let newPlace = Place(context: context)
        newPlace.dateAdded = Date()
        newPlace.post = name
        newPlace.url = "Shared via Reminora link"
        
        print("🔗 ✅ Created new place with name: \(name)")
        
        // Try to copy image data from original place if available
        if let placeId = originalPlaceId,
           let originalPlace = findPlace(withId: placeId, context: context) {
            newPlace.imageData = originalPlace.imageData
            // Keep the original creation date if available
            if let originalDate = originalPlace.dateAdded {
                newPlace.dateAdded = originalDate
            }
        }
        
        // Store location
        let location = CLLocation(latitude: lat, longitude: lon)
        if let locationData = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false) {
            newPlace.setValue(locationData, forKey: "location")
        }
        
        // Find or create the shared list
        let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@ AND userId == %@", "Shared", authService.currentAccount?.id ?? "")
        
        do {
            print("🔗 Fetching shared lists...")
            let sharedLists = try context.fetch(fetchRequest)
            let sharedList: UserList
            
            if let existingList = sharedLists.first {
                print("🔗 ✅ Found existing shared list: \(existingList.name ?? "Unknown")")
                sharedList = existingList
            } else {
                print("🔗 Creating new shared list...")
                // Create shared list
                sharedList = UserList(context: context)
                sharedList.id = UUID().uuidString
                sharedList.name = "Shared"
                sharedList.createdAt = Date()
                sharedList.userId = authService.currentAccount?.id ?? ""
                print("🔗 ✅ Created new shared list")
            }
            
            print("🔗 Adding place to shared list...")
            // Add item to shared list
            let listItem = ListItem(context: context)
            listItem.id = UUID().uuidString
            listItem.placeId = newPlace.objectID.uriRepresentation().absoluteString
            listItem.addedAt = Date()
            listItem.sharedLink = components.url?.absoluteString
            listItem.listId = sharedList.id ?? ""
            
            // Store owner information for follow functionality
            if !ownerId.isEmpty {
                listItem.sharedByUserId = ownerId
                print("🔗 ✅ Stored owner ID: \(ownerId)")
            }
            if !ownerHandle.isEmpty {
                listItem.sharedByUserName = ownerHandle
                print("🔗 ✅ Stored owner handle: \(ownerHandle)")
            }
            
            print("🔗 Saving to Core Data...")
            try context.save()
            print("🔗 ✅ Successfully added shared place to Shared list: \(name)")
            
            // Navigate to the shared place
            DispatchQueue.main.async {
                self.navigateToSharedPlace(newPlace)
            }
            
        } catch {
            print("🔗 ❌ Failed to add shared place: \(error)")
        }
    }
    
    private func navigateToSharedPlace(_ place: Place) {
        print("🔗 navigateToSharedPlace called for: \(place.post ?? "Unknown")")
        
        // Post a notification to trigger navigation in ContentView
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToSharedPlace"),
            object: place
        )
        
        print("🔗 ✅ Posted navigation notification")
    }
    
    private func findPlace(withId placeId: String, context: NSManagedObjectContext) -> Place? {
        // Try to find the place using Core Data URI
        if let url = URL(string: placeId),
           let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url) {
            return try? context.existingObject(with: objectID) as? Place
        }
        return nil
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.blue.opacity(0.8)
                .ignoresSafeArea()
            
            VStack {
                Image(systemName: "camera.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                Text("Reminora")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .padding(.top, 20)
            }
        }
    }
}
