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
                Image(systemName: "house")
                Text("Home")
            }
            .tag(0)

            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
