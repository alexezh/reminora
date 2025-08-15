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

// MARK: - Navigation Route Enum

enum AppRoute: String, CaseIterable {
    case photo = "Photo"
    case map = "Map"
    case pin = "Pin"
    case lists = "Lists"
    case profile = "Profile"
    case ecard = "ECard"
    case clip = "Clip"
    
    var displayName: String {
        switch self {
        case .photo: return "Photos"
        case .map: return "Map"
        case .pin: return "Pins"
        case .lists: return "Lists"
        case .profile: return "Profile"
        case .ecard: return "ECard Editor"
        case .clip: return "Clip Editor"
        }
    }
    
    var systemImage: String {
        switch self {
        case .photo: return "photo"
        case .map: return "map"
        case .pin: return "mappin.and.ellipse"
        case .lists: return "list.bullet.circle"
        case .profile: return "person.circle"
        case .ecard: return "rectangle.and.pencil.and.ellipsis"
        case .clip: return "video"
        }
    }
}

// MARK: - Navigation Data Structures

struct PhotoViewData: Hashable {
    let photoStackCollectionId: String
    let initialStackId: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(photoStackCollectionId)
        hasher.combine(initialStackId)
    }
    
    static func == (lhs: PhotoViewData, rhs: PhotoViewData) -> Bool {
        lhs.photoStackCollectionId == rhs.photoStackCollectionId && 
        lhs.initialStackId == rhs.initialStackId
    }
}

struct AddPinFromPhotoData: Hashable {
    let assetIdentifier: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(assetIdentifier)
    }
    
    static func == (lhs: AddPinFromPhotoData, rhs: AddPinFromPhotoData) -> Bool {
        lhs.assetIdentifier == rhs.assetIdentifier
    }
}

struct AddPinFromLocationData: Hashable {
    let locationName: String
    let locationCoordinate: CLLocationCoordinate2D
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(locationName)
        hasher.combine(locationCoordinate.latitude)
        hasher.combine(locationCoordinate.longitude)
    }
    
    static func == (lhs: AddPinFromLocationData, rhs: AddPinFromLocationData) -> Bool {
        lhs.locationName == rhs.locationName &&
        lhs.locationCoordinate.latitude == rhs.locationCoordinate.latitude &&
        lhs.locationCoordinate.longitude == rhs.locationCoordinate.longitude
    }
}

struct SimilarPhotosData: Hashable {
    let targetAssetIdentifier: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(targetAssetIdentifier)
    }
    
    static func == (lhs: SimilarPhotosData, rhs: SimilarPhotosData) -> Bool {
        lhs.targetAssetIdentifier == rhs.targetAssetIdentifier
    }
}


struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authService: AuthenticationService

    @State private var navigationPath = NavigationPath()
    @State private var currentRoute: AppRoute = {
        if let savedTab = UserDefaults.standard.string(forKey: "selectedTab"),
           let route = AppRoute(rawValue: savedTab) {
            return route
        }
        return .photo
    }()
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
    
    // Shared photo navigation data
    @State private var sharedPhotoStackCollection: RPhotoStackCollection?
    @State private var selectedPhotoStack: RPhotoStack?
    
    // Navigation data for moved views
    @State private var navigationAsset: PHAsset?
    @State private var navigationLocation: LocationInfo?
    @State private var navigationTargetAsset: PHAsset?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            // Root view based on current route
            rootView(for: currentRoute)
                .navigationBarHidden(true)
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                        .navigationBarHidden(true)
                }
                .navigationDestination(for: PhotoViewData.self) { _ in
                    // SwipePhotoView for photo viewing
                    if let collection = sharedPhotoStackCollection,
                       let initialStack = selectedPhotoStack {
                        SwipePhotoView(
                            photoStackCollection: collection,
                            initialStack: initialStack,
                            onDismiss: {
                                navigationPath.removeLast()
                            }
                        )
                        .navigationBarHidden(true)
                    } else {
                        Text("Photo not available")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black)
                    }
                }
                .navigationDestination(for: AddPinFromPhotoData.self) { _ in
                    // AddPinFromPhotoView
                    if let asset = navigationAsset {
                        AddPinFromPhotoView(
                            asset: asset,
                            onDismiss: {
                                navigationPath.removeLast()
                            }
                        )
                        .navigationBarHidden(true)
                    } else {
                        Text("Asset not available")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationDestination(for: AddPinFromLocationData.self) { _ in
                    // AddPinFromLocationView
                    if let location = navigationLocation {
                        AddPinFromLocationView(
                            location: location,
                            onDismiss: {
                                navigationPath.removeLast()
                            }
                        )
                        .navigationBarHidden(true)
                    } else {
                        Text("Location not available")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationDestination(for: SimilarPhotosData.self) { _ in
                    // SimilarPhotosGridView
                    if let targetAsset = navigationTargetAsset {
                        SimilarPhotosGridView(targetAsset: targetAsset)
                            .navigationBarHidden(true)
                    } else {
                        Text("Target asset not available")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
        }
        .onChange(of: currentRoute) { _, newRoute in
            UserDefaults.standard.set(newRoute.rawValue, forKey: "selectedTab")
            
            // Set appropriate toolbar for the selected route
            setupToolbarForRoute(newRoute)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToClipEditor"))) { _ in
            navigateToRoute(.clip)
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
                selectedTab: currentRoute.rawValue,
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
            
            // Set up toolbar for initial route
            setupToolbarForRoute(currentRoute)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RestoreToolbar"))) { _ in
            // Restore toolbar when returning from SwipePhotoView or other overlay views
            print("🔧 ContentView: Restoring toolbar for current route \(currentRoute.displayName)")
            setupToolbarForRoute(currentRoute)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenCurrentEditor"))) { notification in
            if let editorType = notification.object as? EditorType {
                print("🎨 ContentView: Opening current editor: \(editorType.displayName)")
                switch editorType {
                case .eCard:
                    navigateToRoute(.ecard)
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

                // Switch to Pin route and show the shared place via SheetStack
                navigateToRoute(.pin)
                sheetStack.push(.pinDetail(place: place, allPlaces: []))

                print("🔗 ContentView set currentRoute=Pin, showing shared place via SheetStack")
            } else {
                print("🔗 ❌ ContentView: notification object is not a Place")
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToTab"))
        ) { notification in
            if let routeName = notification.object as? String,
               let route = AppRoute(rawValue: routeName) {
                navigateToRoute(route)
                print("🔗 ContentView switched to route: \(route.displayName)")
            } else if let tabIndex = notification.object as? Int {
                // Legacy support for integer tab indices
                let route = tabIndexToRoute(tabIndex)
                navigateToRoute(route)
                print("🔗 ContentView switched to route: \(route.displayName) (from legacy index \(tabIndex))")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FindSimilarPhotos"))) { notification in
            if let asset = notification.object as? PHAsset {
                print("📷 ContentView: Finding similar photos for single asset: \(asset.localIdentifier)")
                navigateToSimilarPhotos(targetAsset: asset)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FindSimilarToSelected"))) { notification in
            if let identifiers = notification.object as? Set<String>, let firstId = identifiers.first {
                print("📷 ContentView: Finding similar photos for selected assets: \(identifiers.count) selected")
                let fetchOptions = PHFetchOptions()
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [firstId], options: fetchOptions)
                if let targetAsset = fetchResult.firstObject {
                    navigateToSimilarPhotos(targetAsset: targetAsset)
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
                navigateToRoute(.ecard)
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
                    navigateToRoute(.ecard)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToAddPinFromPhoto"))) { notification in
            if let asset = notification.object as? PHAsset {
                print("📍 ContentView: Navigating to AddPinFromPhoto for asset: \(asset.localIdentifier)")
                navigateToAddPinFromPhoto(asset: asset)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToAddPinFromLocation"))) { notification in
            if let location = notification.object as? LocationInfo {
                print("📍 ContentView: Navigating to AddPinFromLocation for location: \(location.name)")
                navigateToAddPinFromLocation(location: location)
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
    
    // MARK: - Navigation Methods
    
    private func navigateToRoute(_ route: AppRoute) {
        currentRoute = route
    }
    
    func navigateToPhotoView(photoStackCollection: RPhotoStackCollection, initialStack: RPhotoStack) {
        // Store the shared data
        sharedPhotoStackCollection = photoStackCollection
        selectedPhotoStack = initialStack
        
        // Navigate using a simple PhotoViewData
        let photoData = PhotoViewData(
            photoStackCollectionId: UUID().uuidString, // Just use a UUID since we're storing the actual collection
            initialStackId: initialStack.id
        )
        navigationPath.append(photoData)
    }
    
    func navigateToAddPinFromPhoto(asset: PHAsset) {
        // Store the asset
        navigationAsset = asset
        
        // Navigate using AddPinFromPhotoData
        let addPinData = AddPinFromPhotoData(assetIdentifier: asset.localIdentifier)
        navigationPath.append(addPinData)
    }
    
    func navigateToAddPinFromLocation(location: LocationInfo) {
        // Store the location
        navigationLocation = location
        
        // Navigate using AddPinFromLocationData
        let addPinData = AddPinFromLocationData(
            locationName: location.name,
            locationCoordinate: location.coordinate
        )
        navigationPath.append(addPinData)
    }
    
    func navigateToSimilarPhotos(targetAsset: PHAsset) {
        // Store the target asset
        navigationTargetAsset = targetAsset
        
        // Navigate using SimilarPhotosData
        let similarData = SimilarPhotosData(targetAssetIdentifier: targetAsset.localIdentifier)
        navigationPath.append(similarData)
    }
    
    @ViewBuilder
    private func rootView(for route: AppRoute) -> some View {
        switch route {
        case .photo:
            PhotoMainView(isSwipePhotoViewOpen: $isSwipePhotoViewOpen)
        case .map:
            MapView()
        case .pin:
            PinMainView()
        case .lists:
            AllRListsView(
                context: viewContext,
                userId: authService.currentAccount?.id ?? ""
            )
        case .profile:
            ProfileView()
        case .ecard:
            ECardEditorView(
                initialAssets: eCardEditor.getCurrentAssets(),
                onDismiss: {
                    eCardEditor.endEditing()
                    navigateToRoute(.photo) // Return to photos after dismissing
                }
            )
        case .clip:
            ClipEditorView(
                initialAssets: clipEditor.getCurrentAssets(),
                onDismiss: {
                    clipEditor.endEditing()
                    navigateToRoute(.photo) // Return to photos after dismissing
                }
            )
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        rootView(for: route)
    }
    
    // MARK: - Toolbar Management
    
    private func setupToolbarForRoute(_ route: AppRoute) {
        print("🔧 ContentView: Setting up toolbar for route \(route.displayName)")
        
        switch route {
        case .photo: // Photos Route - FAB only
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.photos)
            
        case .map: // Map Route - Full toolbar with navigation buttons
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
            
        case .pin: // Pins Route - Show FAB only
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.pins)
            
        case .lists: // Lists Route - Show FAB only
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.lists)
            
        case .profile: // Profile Route - FAB only for now
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.profile)
            
        case .ecard: // ECard Editor Route - FAB only for now
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.ecard)
            
        case .clip: // Clip Editor Route - FAB only for now
            toolbarManager.setFABOnlyMode()
            UniversalActionSheetModel.shared.setContext(.clip)
        }
    }
    
    // MARK: - Helper Functions
    
    private func tabIndexToRoute(_ index: Int) -> AppRoute {
        switch index {
        case 0: return .photo
        case 1: return .map
        case 2: return .pin
        case 3: return .lists
        case 4: return .profile
        default: return .photo
        }
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
