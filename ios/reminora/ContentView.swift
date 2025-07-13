//
//  ContentView.swift
//  reminora
//
//  Created by alexezh on 5/26/25.
//

import CoreData
import MapKit
import PhotosUI
import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authService: AuthenticationService

    @State private var selectedTab = 0
    @State private var showPhotoLibrary = false
    @State private var showingSharedPlace = false
    @State private var sharedPlace: Place?

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home/Map Tab
            ZStack {
                PinMainView()

                // Show the system photo picker as a sheet when showPhotoLibrary is true
                if showPhotoLibrary {
                    PhotoLibraryView(isPresented: $showPhotoLibrary)
                        .ignoresSafeArea()
                        .transition(.move(edge: .bottom))
                }
            }
            .tabItem {
                Image(systemName: "mappin.and.ellipse")
                Text("Pin")
            }
            .tag(0)

            // Photos Tab
            PhotoStackView()
                .tabItem {
                    Image(systemName: "photo.stack")
                    Text("Photos")
                }
                .tag(1)

            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(4)
        }
        .accentColor(.blue)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToSharedPlace"))) { notification in
            print("🔗 ContentView received NavigateToSharedPlace notification")
            
            if let place = notification.object as? Place {
                print("🔗 ContentView navigating to shared place: \(place.post ?? "Unknown")")
                
                // Switch to Pin tab and show the shared place
                selectedTab = 0
                sharedPlace = place
                showingSharedPlace = true
                
                print("🔗 ContentView set selectedTab=0, showing shared place")
            } else {
                print("🔗 ❌ ContentView: notification object is not a Place")
            }
        }
        .sheet(isPresented: $showingSharedPlace) {
            if let place = sharedPlace {
                NavigationView {
                    PinDetailView(
                        place: place,
                        allPlaces: [],
                        onBack: {
                            showingSharedPlace = false
                            sharedPlace = nil
                        }
                    )
                }
            }
        }
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
