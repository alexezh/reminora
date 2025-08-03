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
    @State private var isSwipePhotoViewOpen = false
    @StateObject private var toolbarManager = ToolbarManager()
    @StateObject private var selectedAssetService = SelectionService.shared
    @StateObject private var sheetStack = SheetStack.shared
    @StateObject private var eCardTemplateService = ECardTemplateService.shared
    @StateObject private var eCardEditor = ECardEditor.shared
    @StateObject private var actionSheetModel = UniversalActionSheetModel.shared
    @State private var isActionSheetScrolling = false

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
        .environment(\.sheetStack, sheetStack)
        .environment(\.eCardTemplateService, eCardTemplateService)
        .environment(\.eCardEditor, eCardEditor)
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
        // ECardEditorView overlay - shows when editor is active
        .overlay {
            if actionSheetModel.currentEditor == .eCard && eCardEditor.hasActiveSession {
                ECardEditorView(
                    initialAssets: eCardEditor.getCurrentAssets(),
                    onDismiss: {
                        eCardEditor.endEditing()
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.1).combined(with: .opacity),
                    removal: .scale(scale: 0.1).combined(with: .opacity)
                ))
                .zIndex(1000) // Above other overlays
            }
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
                    // ECardEditorView will be shown automatically via overlay when editor is active
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
                selectedTab = 2
                sheetStack.push(.pinDetail(place: place, allPlaces: []))

                print("🔗 ContentView set selectedTab=2, showing shared place via SheetStack")
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
                sheetStack.push(.eCardEditor(assets: [asset]))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MakeECardFromSelected"))) { notification in
            if let identifiers = notification.object as? Set<String> {
                print("🎨 ContentView: Creating ECard for \(identifiers.count) selected assets")
                let fetchOptions = PHFetchOptions()
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(identifiers), options: fetchOptions)
                let assets = (0..<fetchResult.count).compactMap { fetchResult.object(at: $0) }
                if !assets.isEmpty {
                    sheetStack.push(.eCardEditor(assets: assets))
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
    
    private func setupToolbarForTab(_ tabIndex: Int) {
        print("🔧 ContentView: Setting up toolbar for tab \(tabIndex)")
        
        switch tabIndex {
        case 0: // Photos Tab - FAB only
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.photos)
            
        case 1: // Map Tab - Full toolbar with navigation buttons
            let mapButtons = [
                ToolbarButtonConfig(
                    id: "photos",
                    title: "Photos",
                    systemImage: "photo",
                    actionType: .switchToTab(0),
                    color: .blue
                ),
                ToolbarButtonConfig(
                    id: "pins",
                    title: "Pins",
                    systemImage: "mappin.and.ellipse",
                    actionType: .switchToTab(2),
                    color: .red
                ),
                ToolbarButtonConfig(
                    id: "lists",
                    title: "Lists",
                    systemImage: "list.bullet.circle",
                    actionType: .switchToTab(3),
                    color: .purple
                )
            ]
            toolbarManager.setCustomToolbar(buttons: mapButtons)
            UniversalActionSheetModel.shared.setContext(.map)
            
        case 2: // Pins Tab - Show FAB only
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.pins)
            
        case 3: // Lists Tab - Show FAB only
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.lists)
            
        case 4: // Profile Tab - FAB only for now
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.profile)
            
        default:
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.lists)
        }
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
