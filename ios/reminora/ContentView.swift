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

    @State private var selectedTab = UserDefaults.standard.integer(forKey: "selectedTab")
    @State private var showingSharedPlace = false
    @State private var sharedPlace: PinData?
    @State private var isSwipePhotoViewOpen = false
    @StateObject private var toolbarManager = ToolbarManager()

    var body: some View {
        TabView(selection: $selectedTab) {
            // Photos Tab
            NavigationView {
                PhotoStackView(isSwipePhotoViewOpen: $isSwipePhotoViewOpen)
            }
            .tabItem {
                Image(systemName: "photo.stack")
            }
            .tag(0)

            // Map Tab
            NavigationView {
                MapView()
            }
            .tabItem {
                Image(systemName: "map")
            }
            .tag(1)

            // Pins Tab
            NavigationView {
                PinMainView()
            }
            .tabItem {
                Image(systemName: "mappin.and.ellipse")
            }
            .tag(2)

            AllRListsView(
                context: viewContext,
                userId: authService.currentAccount?.id ?? ""
            )
            .tabItem {
                Image(systemName: "list.bullet.circle")
            }
            .tag(3)
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(4)
        }
        .accentColor(.blue)
        .toolbar(toolbarManager.hideDefaultTabBar || isSwipePhotoViewOpen ? .hidden : .visible, for: .tabBar)
        .onChange(of: selectedTab) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "selectedTab")
        }
        .environment(\.toolbarManager, toolbarManager)
        .overlay(alignment: .bottom) {
            // Custom dynamic toolbar (show when enabled, including when SwipePhotoView is open with its buttons)
            if toolbarManager.showCustomToolbar {
                DynamicToolbar(
                    buttons: toolbarManager.customButtons,
                    position: .bottom,
                    backgroundColor: Color(.systemBackground),
                    isVisible: toolbarManager.showCustomToolbar,
                    version: toolbarManager.version
                )
            }
        }
        .onAppear {
            // Start background embedding computation for all photos
            startBackgroundEmbeddingComputation()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToSharedPlace"))
        ) { notification in
            print("🔗 ContentView received NavigateToSharedPlace notification")

            if let place = notification.object as? PinData {
                print("🔗 ContentView navigating to shared place: \(place.post ?? "Unknown")")

                // Switch to Pin tab and show the shared place
                selectedTab = 2
                sharedPlace = place
                showingSharedPlace = true

                print("🔗 ContentView set selectedTab=1, showing shared place")
            } else {
                print("🔗 ❌ ContentView: notification object is not a Place")
            }
        }
        .overlay {
            if showingSharedPlace, let place = sharedPlace {
                PinDetailView(
                    place: place,
                    allPlaces: [],
                    onBack: {
                        showingSharedPlace = false
                        sharedPlace = nil
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.1).combined(with: .opacity),
                    removal: .scale(scale: 0.1).combined(with: .opacity)
                ))
            }
        }
    }


    // MARK: - Background Embedding Computation

    private func startBackgroundEmbeddingComputation() {
        print("📊 Starting background embedding computation for all photos")

        Task {
            // Get embedding stats to see if we need to compute embeddings
            let stats = PhotoEmbeddingService.shared.getEmbeddingStats(in: viewContext)
            print(
                "📊 Current embedding stats: \(stats.photosWithEmbeddings)/\(stats.totalPhotos) photos analyzed (\(stats.coveragePercentage)%)"
            )

            // Only start computation if coverage is less than 100%
            if stats.coverage < 1.0 {
                print(
                    "📊 Starting background computation for \(stats.totalPhotos - stats.photosWithEmbeddings) remaining photos"
                )

                await PhotoEmbeddingService.shared.computeAllEmbeddings(in: viewContext) {
                    processed, total in
                    // Log progress every 10 photos to avoid spam
                    if processed % 10 == 0 || processed == total {
                        print(
                            "📊 Embedding progress: \(processed)/\(total) photos processed (\(Int(Float(processed)/Float(total)*100))%)"
                        )
                    }
                }

                print("📊 ✅ Background embedding computation completed!")
            } else {
                print("📊 ✅ All photos already have embeddings, skipping computation")
            }
        }
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
