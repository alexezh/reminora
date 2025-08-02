//
//  ContentView.swift
//  reminora
//
//  Created by alexezh on 5/26/25.
//

import CoreData
import MapKit
import Photos
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
    @StateObject private var selectedAssetService = SelectedAssetService.shared
    @State private var showingSimilarPhotos = false
    @State private var similarPhotoTarget: PHAsset?
    @State private var showingDuplicatePhotos = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Photos Tab
                if selectedTab == 0 {
                    NavigationView {
                        PhotoMainView(isSwipePhotoViewOpen: $isSwipePhotoViewOpen)
                    }
                    .navigationBarHidden(true)
                }
                
                // Map Tab
                if selectedTab == 1 {
                    NavigationView {
                        MapView()
                    }
                    .navigationBarHidden(true)
                }
                
                // Pins Tab
                if selectedTab == 2 {
                    NavigationView {
                        PinMainView()
                    }
                    .navigationBarHidden(true)
                }
                
                // Lists Tab
                if selectedTab == 3 {
                    AllRListsView(
                        context: viewContext,
                        userId: authService.currentAccount?.id ?? ""
                    )
                }
                
                // Profile Tab
                if selectedTab == 4 {
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: selectedTab) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "selectedTab")
            
            // Set appropriate toolbar for the selected tab
            setupToolbarForTab(newValue)
        }
        .environment(\.toolbarManager, toolbarManager)
        .environment(\.selectedAssetService, selectedAssetService)
        .sheet(isPresented: $toolbarManager.showActionSheet) {
            UniversalActionSheet(
                selectedTab: selectedTab,
                onRefreshLists: {
                    // Trigger refresh on Lists tab
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshLists"), object: nil)
                },
                onAddPin: {
                    // Trigger add pin on Pins tab
                    NotificationCenter.default.post(name: NSNotification.Name("AddPin"), object: nil)
                },
                onAddOpenInvite: {
                    // Trigger add open invite on Pins tab
                    NotificationCenter.default.post(name: NSNotification.Name("AddOpenInvite"), object: nil)
                },
                onToggleSort: {
                    // Trigger sort toggle on Pins tab
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleSort"), object: nil)
                }
            )
            .presentationDetents([.height(400), .medium])
        }
        .overlay(alignment: .bottom) {
            // Custom dynamic toolbar (show when enabled, including when SwipePhotoView is open with its buttons)
            if toolbarManager.showCustomToolbar {
                DynamicToolbar(
                    buttons: toolbarManager.customButtons,
                    position: .bottom,
                    backgroundColor: Color(.systemBackground),
                    isVisible: toolbarManager.showCustomToolbar,
                    version: toolbarManager.version,
                    showOnlyFAB: toolbarManager.showOnlyFAB
                )
                .ignoresSafeArea(.container, edges: .bottom) // Extend to bottom edge
            }
        }
        .onAppear {
            // Start background embedding computation for all photos
            startBackgroundEmbeddingComputation()
            
            // Set up toolbar for initial tab
            setupToolbarForTab(selectedTab)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RestoreToolbar"))) { _ in
            // Restore toolbar when returning from SwipePhotoView or other overlay views
            print("🔧 ContentView: Restoring toolbar for current tab \(selectedTab)")
            setupToolbarForTab(selectedTab)
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
        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToTab"))
        ) { notification in
            if let tabIndex = notification.object as? Int {
                selectedTab = tabIndex
                print("🔗 ContentView switched to tab: \(tabIndex)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FindSimilarPhotos"))) { notification in
            if let asset = notification.object as? PHAsset {
                print("📷 ContentView: Finding similar photos for single asset: \(asset.localIdentifier)")
                similarPhotoTarget = asset
                showingSimilarPhotos = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FindSimilarToSelected"))) { notification in
            if let identifiers = notification.object as? Set<String> {
                // Find the first selected asset from all photo assets (we'll need to get these from Photos library)
                print("📷 ContentView: Finding similar photos for selected assets: \(identifiers.count) selected")
                // For now, we'll need to get the first asset from the identifiers
                if let firstId = identifiers.first {
                    // Get the asset from Photos library
                    let fetchOptions = PHFetchOptions()
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [firstId], options: fetchOptions)
                    if let targetAsset = fetchResult.firstObject {
                        similarPhotoTarget = targetAsset
                        showingSimilarPhotos = true
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FindDuplicatePhotos"))) { _ in
            print("📷 ContentView: Finding duplicate photos across entire library")
            showingDuplicatePhotos = true
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
        .sheet(isPresented: $showingSimilarPhotos) {
            if let targetAsset = similarPhotoTarget {
                SimilarPhotosGridView(targetAsset: targetAsset)
            }
        }
        .sheet(isPresented: $showingDuplicatePhotos) {
            // Use a dummy asset for duplicate detection - PhotoSimilarityView will find all duplicates
            let fetchOptions = PHFetchOptions()
            fetchOptions.fetchLimit = 1
            let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            if let firstAsset = fetchResult.firstObject {
                PhotoSimilarityView(targetAsset: firstAsset)
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
    
    // MARK: - Toolbar Management
    
    private func setupToolbarForTab(_ tabIndex: Int) {
        print("🔧 ContentView: Setting up toolbar for tab \(tabIndex)")
        
        switch tabIndex {
        case 0: // Photos Tab - FAB only
            toolbarManager.setFABOnlyMode()
            
        case 1: // Map Tab - Full toolbar with navigation buttons
            let mapButtons = [
                ToolbarButtonConfig(
                    id: "photos",
                    title: "Photos",
                    systemImage: "photo",
                    action: { self.selectedTab = 0 },
                    color: .blue
                ),
                ToolbarButtonConfig(
                    id: "pins",
                    title: "Pins",
                    systemImage: "mappin.and.ellipse",
                    action: { self.selectedTab = 2 },
                    color: .red
                ),
                ToolbarButtonConfig(
                    id: "lists",
                    title: "Lists",
                    systemImage: "list.bullet.circle",
                    action: { self.selectedTab = 3 },
                    color: .purple
                )
            ]
            toolbarManager.setCustomToolbar(buttons: mapButtons)
            
        case 2: // Pins Tab - Show FAB only
            toolbarManager.setFABOnlyMode()
            
        case 3: // Lists Tab - Show FAB only
            toolbarManager.setFABOnlyMode()
            
        case 4: // Profile Tab - FAB only for now
            toolbarManager.setFABOnlyMode()
            
        default:
            toolbarManager.setFABOnlyMode()
        }
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
