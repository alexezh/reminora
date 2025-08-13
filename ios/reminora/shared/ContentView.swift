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

    @State private var selectedTab = UserDefaults.standard.string(forKey: "selectedTab") ?? "Photo"
    @State private var isSwipePhotoViewOpen = false
    @StateObject private var toolbarManager = ToolbarManager()
    @StateObject private var selectedAssetService = SelectionService.shared
    @StateObject private var sheetStack = SheetStack.shared
    @StateObject private var eCardTemplateService = ECardTemplateService.shared
    @StateObject private var eCardEditor = ECardEditor.shared
    @StateObject private var clipEditor = ClipEditor.shared
    @StateObject private var clipManager = ClipManager.shared
    @StateObject private var actionSheetModel = UniversalActionSheetModel.shared
    @State private var isActionSheetScrolling = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Photos Tab
                if selectedTab == "Photo" {
                    NavigationView {
                        PhotoMainView(isSwipePhotoViewOpen: $isSwipePhotoViewOpen)
                    }
                    .navigationBarHidden(true)
                }
                
                // Map Tab
                if selectedTab == "Map" {
                    NavigationView {
                        MapView()
                    }
                    .navigationBarHidden(true)
                }
                
                // Pins Tab
                if selectedTab == "Pin" {
                    NavigationView {
                        PinMainView()
                    }
                    .navigationBarHidden(true)
                }
                
                // Lists Tab
                if selectedTab == "Lists" {
                    AllRListsView(
                        context: viewContext,
                        userId: authService.currentAccount?.id ?? ""
                    )
                }
                
                // Profile Tab
                if selectedTab == "Profile" {
                    ProfileView()
                }
                
                // ECard Editor Tab
                if selectedTab == "ECard" {
                    ECardEditorView(
                        initialAssets: eCardEditor.getCurrentAssets(),
                        onDismiss: {
                            eCardEditor.endEditing()
                        }
                    )
                }
                
                // Clip Editor Tab
                if selectedTab == "Clip" {
                    ClipEditorView(
                        initialAssets: clipEditor.getCurrentAssets(),
                        onDismiss: {
                            clipEditor.endEditing()
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: selectedTab) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "selectedTab")
            
            // Set appropriate toolbar for the selected tab
            setupToolbarForTab(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToClipEditor"))) { _ in
            selectedTab = "Clip"
        }
        .environment(\.toolbarManager, toolbarManager)
        .environment(\.selectedAssetService, selectedAssetService)
        .environment(\.sheetStack, sheetStack)
        .environment(\.eCardTemplateService, eCardTemplateService)
        .environment(\.eCardEditor, eCardEditor)
        .environment(\.clipEditor, clipEditor)
        .environment(\.clipManager, clipManager)
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
                },
                onScrollingStateChanged: { isScrolling in
                    isActionSheetScrolling = isScrolling
                }
            )
            .presentationDetents([.height(400), .medium])
            .interactiveDismissDisabled(isActionSheetScrolling)
        }
        // Add SheetRouter for centralized sheet management
        .overlay {
            SheetRouter(sheetStack: sheetStack)
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
            // Configure ActionRouter with services
            ActionRouter.shared.configure(
                sheetStack: sheetStack,
                selectionService: selectedAssetService,
                toolbarManager: toolbarManager
            )
            
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenCurrentEditor"))) { notification in
            if let editorType = notification.object as? EditorType {
                print("🎨 ContentView: Opening current editor: \(editorType.displayName)")
                switch editorType {
                case .eCard:
                    selectedTab = "Editor"
                    break
                case .clip:
                    // Clip editor is handled via sheet presentation
                    print("🎨 ContentView: Clip editor opened via sheet")
                    break
                case .collage, .videoEditor:
                    // Future editor types can be handled here
                    print("🎨 ContentView: Editor type \(editorType.displayName) not yet implemented")
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToSharedPlace"))
        ) { notification in
            print("🔗 ContentView received NavigateToSharedPlace notification")

            if let place = notification.object as? PinData {
                print("🔗 ContentView navigating to shared place: \(place.post ?? "Unknown")")

                // Switch to Pin tab and show the shared place via SheetStack
                selectedTab = "Pin"
                sheetStack.push(.pinDetail(place: place, allPlaces: []))

                print("🔗 ContentView set selectedTab=Pin, showing shared place via SheetStack")
            } else {
                print("🔗 ❌ ContentView: notification object is not a Place")
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToTab"))
        ) { notification in
            if let tabName = notification.object as? String {
                selectedTab = tabName
                print("🔗 ContentView switched to tab: \(tabName)")
            } else if let tabIndex = notification.object as? Int {
                // Legacy support for integer tab indices
                let tabName = tabIndexToString(tabIndex)
                selectedTab = tabName
                print("🔗 ContentView switched to tab: \(tabName) (from legacy index \(tabIndex))")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FindSimilarPhotos"))) { notification in
            if let asset = notification.object as? PHAsset {
                print("📷 ContentView: Finding similar photos for single asset: \(asset.localIdentifier)")
                sheetStack.push(.similarPhotos(targetAsset: asset))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FindSimilarToSelected"))) { notification in
            if let identifiers = notification.object as? Set<String>, let firstId = identifiers.first {
                print("📷 ContentView: Finding similar photos for selected assets: \(identifiers.count) selected")
                let fetchOptions = PHFetchOptions()
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [firstId], options: fetchOptions)
                if let targetAsset = fetchResult.firstObject {
                    sheetStack.push(.similarPhotos(targetAsset: targetAsset))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FindDuplicatePhotos"))) { _ in
            print("📷 ContentView: Finding duplicate photos across entire library")
            // Use first available photo as target for duplicate detection
            let fetchOptions = PHFetchOptions()
            fetchOptions.fetchLimit = 1
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            if let firstAsset = fetchResult.firstObject {
                sheetStack.push(.duplicatePhotos(targetAsset: firstAsset))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MakeECard"))) { notification in
            if let asset = notification.object as? PHAsset {
                print("🎨 ContentView: Creating ECard for single asset: \(asset.localIdentifier)")
                eCardEditor.startEditing(with: [asset])
                selectedTab = "Editor"
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MakeECardFromSelected"))) { notification in
            if let identifiers = notification.object as? Set<String> {
                print("🎨 ContentView: Creating ECard for \(identifiers.count) selected assets")
                let fetchOptions = PHFetchOptions()
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(identifiers), options: fetchOptions)
                let assets = (0..<fetchResult.count).compactMap { fetchResult.object(at: $0) }
                if !assets.isEmpty {
                    eCardEditor.startEditing(with: assets)
                    selectedTab = "Editor"
                }
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
    
    private func setupToolbarForTab(_ tabName: String) {
        print("🔧 ContentView: Setting up toolbar for tab \(tabName)")
        
        switch tabName {
        case "Photo": // Photos Tab - FAB only
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.photos)
            
        case "Map": // Map Tab - Full toolbar with navigation buttons
            let mapButtons = [
                ToolbarButtonConfig(
                    id: "photos",
                    title: "Photos",
                    systemImage: "photo",
                    actionType: .switchToTab("Photo"),
                    color: .blue
                ),
                ToolbarButtonConfig(
                    id: "pins",
                    title: "Pins",
                    systemImage: "mappin.and.ellipse",
                    actionType: .switchToTab("Pin"),
                    color: .red
                ),
                ToolbarButtonConfig(
                    id: "lists",
                    title: "Lists",
                    systemImage: "list.bullet.circle",
                    actionType: .switchToTab("Lists"),
                    color: .purple
                )
            ]
            toolbarManager.setCustomToolbar(buttons: mapButtons)
            UniversalActionSheetModel.shared.setContext(.map)
            
        case "Pin": // Pins Tab - Show FAB only
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.pins)
            
        case "Lists": // Lists Tab - Show FAB only
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.lists)
            
        case "Profile": // Profile Tab - FAB only for now
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.profile)
            
        case "Editor": // Editor Tab - FAB only for now
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.ecard)
            
        default:
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.lists)
        }
    }
    
    // MARK: - Helper Functions
    
    private func tabIndexToString(_ index: Int) -> String {
        switch index {
        case 0: return "Photo"
        case 1: return "Map"
        case 2: return "Pin"
        case 3: return "Lists"
        case 4: return "Profile"
        default: return "Photo"
        }
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
