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
            .presentationDetents([.medium])
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
            
        case 2: // Pins Tab - Full toolbar with navigation buttons  
            let pinButtons = [
                ToolbarButtonConfig(
                    id: "photos",
                    title: "Photos",
                    systemImage: "photo",
                    action: { self.selectedTab = 0 },
                    color: .blue
                ),
                ToolbarButtonConfig(
                    id: "map",
                    title: "Map",
                    systemImage: "map",
                    action: { self.selectedTab = 1 },
                    color: .green
                ),
                ToolbarButtonConfig(
                    id: "lists",
                    title: "Lists",
                    systemImage: "list.bullet.circle",
                    action: { self.selectedTab = 3 },
                    color: .purple
                )
            ]
            toolbarManager.setCustomToolbar(buttons: pinButtons)
            
        case 3: // Lists Tab - Full toolbar with navigation buttons
            let listButtons = [
                ToolbarButtonConfig(
                    id: "photos",
                    title: "Photos",
                    systemImage: "photo",
                    action: { self.selectedTab = 0 },
                    color: .blue
                ),
                ToolbarButtonConfig(
                    id: "map",
                    title: "Map",
                    systemImage: "map",
                    action: { self.selectedTab = 1 },
                    color: .green
                ),
                ToolbarButtonConfig(
                    id: "pins",
                    title: "Pins",
                    systemImage: "mappin.and.ellipse",
                    action: { self.selectedTab = 2 },
                    color: .red
                )
            ]
            toolbarManager.setCustomToolbar(buttons: listButtons)
            
        case 4: // Profile Tab - FAB only for now
            toolbarManager.setFABOnlyMode()
            
        default:
            toolbarManager.setFABOnlyMode()
        }
    }
}

// MARK: - Universal Action Sheet

struct UniversalActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let selectedTab: Int
    let onRefreshLists: () -> Void
    let onAddPin: () -> Void
    let onAddOpenInvite: () -> Void
    let onToggleSort: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar - closer to top
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 6)
                .padding(.bottom, 16)
            
            // Top section with Photo, Pin, List, Settings buttons
            HStack(spacing: 20) {
                QuickActionButton(
                    icon: "photo",
                    title: "Photo",
                    color: .blue,
                    action: {
                        dismiss()
                        // Navigate to photo tab
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: 0)
                    }
                )
                
                QuickActionButton(
                    icon: "mappin.and.ellipse",
                    title: "Pin",
                    color: .red,
                    action: {
                        dismiss()
                        // Navigate to pin tab
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: 2)
                    }
                )
                
                QuickActionButton(
                    icon: "list.bullet.circle",
                    title: "List",
                    color: .orange,
                    action: {
                        dismiss()
                        // Navigate to list tab
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: 3)
                    }
                )
                
                // Show context-specific fourth button based on tab
                if selectedTab == 3 {
                    // Lists tab - show Refresh
                    QuickActionButton(
                        icon: "arrow.clockwise",
                        title: "Refresh",
                        color: .green,
                        action: {
                            dismiss()
                            onRefreshLists()
                        }
                    )
                } else if selectedTab == 2 {
                    // Pins tab - show Sort
                    QuickActionButton(
                        icon: "arrow.up.arrow.down",
                        title: "Sort",
                        color: .green,
                        action: {
                            dismiss()
                            onToggleSort()
                        }
                    )
                } else {
                    // Other tabs - show Settings
                    QuickActionButton(
                        icon: "gear",
                        title: "Settings",
                        color: .gray,
                        action: {
                            dismiss()
                            print("Settings tapped")
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            
            // Second row for Pins tab - Add Pin and Add Open Invite
            if selectedTab == 2 {
                HStack(spacing: 20) {
                    QuickActionButton(
                        icon: "plus.circle",
                        title: "Add Pin",
                        color: .orange,
                        action: {
                            dismiss()
                            onAddPin()
                        }
                    )
                    
                    QuickActionButton(
                        icon: "envelope.open",
                        title: "Open Invite",
                        color: .purple,
                        action: {
                            dismiss()
                            onAddOpenInvite()
                        }
                    )
                    
                    // Empty spacers to maintain layout
                    Spacer()
                        .frame(width: 50, height: 50)
                    Spacer()
                        .frame(width: 50, height: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .padding(.bottom, 34)
        .background(Color(.systemBackground))
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .clipShape(Circle())
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct UniversalActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
