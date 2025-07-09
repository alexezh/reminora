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
                // Handle Google Sign-In URLs
                if url.scheme == "com.googleusercontent.apps" {
                    GIDSignIn.sharedInstance.handle(url)
                }
                // Handle Reminora deep links
                else if url.host == "reminora.app" {
                    handleReminoraLink(url)
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
        guard url.host == "reminora.app",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return
        }
        
        // Handle different link types
        if url.pathComponents.contains("place") {
            handlePlaceLink(components)
        }
    }
    
    private func handlePlaceLink(_ components: URLComponents) {
        guard let queryItems = components.queryItems,
              let name = queryItems.first(where: { $0.name == "name" })?.value,
              let latString = queryItems.first(where: { $0.name == "lat" })?.value,
              let lonString = queryItems.first(where: { $0.name == "lon" })?.value,
              let lat = Double(latString),
              let lon = Double(lonString) else {
            return
        }
        
        // Create a new place and add it to the shared list
        let context = persistenceController.container.viewContext
        
        // Create the place
        let newPlace = Place(context: context)
        newPlace.dateAdded = Date()
        newPlace.post = name
        newPlace.url = "Shared via Reminora link"
        
        // Store location
        let location = CLLocation(latitude: lat, longitude: lon)
        if let locationData = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false) {
            newPlace.setValue(locationData, forKey: "location")
        }
        
        // Find or create the shared list
        let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@ AND userId == %@", "Shared", authService.currentAccount?.id ?? "")
        
        do {
            let sharedLists = try context.fetch(fetchRequest)
            let sharedList: UserList
            
            if let existingList = sharedLists.first {
                sharedList = existingList
            } else {
                // Create shared list
                sharedList = UserList(context: context)
                sharedList.id = UUID().uuidString
                sharedList.name = "Shared"
                sharedList.createdAt = Date()
                sharedList.userId = authService.currentAccount?.id ?? ""
            }
            
            // Add item to shared list
            let listItem = ListItem(context: context)
            listItem.id = UUID().uuidString
            listItem.placeId = newPlace.objectID.uriRepresentation().absoluteString
            listItem.addedAt = Date()
            listItem.sharedLink = components.url?.absoluteString
            listItem.listId = sharedList.id ?? ""
            
            try context.save()
            print("Added shared place to Shared list: \(name)")
            
        } catch {
            print("Failed to add shared place: \(error)")
        }
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
