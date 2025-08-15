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

enum AppTab: String, CaseIterable {
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

// MARK: - Helper Functions

func tabIndexToRoute(_ index: Int) -> AppTab {
    switch index {
    case 0: return .photo
    case 1: return .map
    case 2: return .pin
    case 3: return .lists
    case 4: return .profile
    default: return .photo
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

struct AllListsData: Hashable {
    let userId: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(userId)
    }
    
    static func == (lhs: AllListsData, rhs: AllListsData) -> Bool {
        lhs.userId == rhs.userId
    }
}

struct QuickListData: Hashable {
    let userId: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(userId)
    }
    
    static func == (lhs: QuickListData, rhs: QuickListData) -> Bool {
        lhs.userId == rhs.userId
    }
}

struct DuplicatePhotosData: Hashable {
    let targetAssetIdentifier: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(targetAssetIdentifier)
    }
    
    static func == (lhs: DuplicatePhotosData, rhs: DuplicatePhotosData) -> Bool {
        lhs.targetAssetIdentifier == rhs.targetAssetIdentifier
    }
}

struct NearbyPhotosData: Hashable {
    let centerLatitude: Double
    let centerLongitude: Double
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(centerLatitude)
        hasher.combine(centerLongitude)
    }
    
    static func == (lhs: NearbyPhotosData, rhs: NearbyPhotosData) -> Bool {
        lhs.centerLatitude == rhs.centerLatitude && 
        lhs.centerLongitude == rhs.centerLongitude
    }
}

struct NearbyLocationsData: Hashable {
    let searchLatitude: Double
    let searchLongitude: Double
    let locationName: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(searchLatitude)
        hasher.combine(searchLongitude)
        hasher.combine(locationName)
    }
    
    static func == (lhs: NearbyLocationsData, rhs: NearbyLocationsData) -> Bool {
        lhs.searchLatitude == rhs.searchLatitude &&
        lhs.searchLongitude == rhs.searchLongitude &&
        lhs.locationName == rhs.locationName
    }
}

struct ECardEditorData: Hashable {
    let assetIdentifiers: [String]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(assetIdentifiers)
    }
    
    static func == (lhs: ECardEditorData, rhs: ECardEditorData) -> Bool {
        lhs.assetIdentifiers == rhs.assetIdentifiers
    }
}

struct ClipEditorData: Hashable {
    let assetIdentifiers: [String]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(assetIdentifiers)
    }
    
    static func == (lhs: ClipEditorData, rhs: ClipEditorData) -> Bool {
        lhs.assetIdentifiers == rhs.assetIdentifiers
    }
}


struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authService: AuthenticationService

    @State private var navigationPath = NavigationPath()
    @State private var currentTab: AppTab = {
        if let savedTab = UserDefaults.standard.string(forKey: "selectedTab"),
           let route = AppTab(rawValue: savedTab) {
            return route
        }
        return .photo
    }()
    
    // Per-tab navigation stack storage
    @State private var tabNavigationStacks: [AppTab: NavigationPath] = [:]
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
    
    // Navigation data for migrated sheet types
    @State private var navigationNearbyPhotosCenter: CLLocationCoordinate2D?
    @State private var navigationNearbyLocationsSearch: CLLocationCoordinate2D?
    @State private var navigationNearbyLocationsName: String?
    @State private var navigationECardAssets: [PHAsset]?
    @State private var navigationClipAssets: [PHAsset]?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            // Root view based on current route
            rootView(for: currentTab)
                .navigationBarHidden(true)
                .navigationDestination(for: AppTab.self) { route in
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
                                // Refresh filter to remove disliked photos from view
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshPhotoFilter"), object: nil)
                                // Restore toolbar state
                                NotificationCenter.default.post(name: NSNotification.Name("RestoreToolbar"), object: nil)
                            }
                        )
                        .navigationBarHidden(true)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.1, anchor: .center).combined(with: .opacity),
                            removal: .scale(scale: 0.1, anchor: .center).combined(with: .opacity)
                        ))
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
                .navigationDestination(for: AllListsData.self) { data in
                    // AllRListsView
                    AllRListsView(
                        context: viewContext,
                        userId: data.userId
                    )
                    .navigationBarHidden(true)
                }
                .navigationDestination(for: QuickListData.self) { data in
                    // QuickListView
                    RListService.createQuickListView(
                        context: viewContext,
                        userId: data.userId,
                        onPhotoStackTap: { photoStack in
                            navigationPath.removeLast() // Close current view
                            print("📷 Quick List photo stack tapped: \(photoStack.count) photos")
                        },
                        onPinTap: { place in
                            // Replace current view with pin detail
                            navigationPath.removeLast() // Remove QuickList
                            sheetStack.push(.pinDetail(place: place, allPlaces: []))
                        }
                    )
                    .navigationBarHidden(true)
                }
                .navigationDestination(for: DuplicatePhotosData.self) { _ in
                    // SimilarPhotoView for duplicates
                    if let targetAsset = navigationTargetAsset {
                        SimilarPhotoView(targetAsset: targetAsset)
                            .navigationBarHidden(true)
                    } else {
                        Text("Target asset not available")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationDestination(for: NearbyPhotosData.self) { _ in
                    // NearbyPhotosGridView
                    if let centerLocation = navigationNearbyPhotosCenter {
                        NavigationView {
                            NearbyPhotosGridView(
                                centerLocation: centerLocation,
                                onDismiss: {
                                    navigationPath.removeLast()
                                }
                            )
                            .navigationBarTitleDisplayMode(.inline)
                        }
                        .navigationBarHidden(true)
                    } else {
                        Text("Center location not available")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationDestination(for: NearbyLocationsData.self) { _ in
                    // NearbyLocationsView
                    if let searchLocation = navigationNearbyLocationsSearch,
                       let locationName = navigationNearbyLocationsName {
                        NearbyLocationsView(
                            searchLocation: searchLocation,
                            locationName: locationName,
                            isSelectMode: false,
                            selectedLocations: .constant([])
                        )
                        .navigationBarHidden(true)
                    } else {
                        Text("Location data not available")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationDestination(for: ECardEditorData.self) { _ in
                    // ECardEditorView
                    if let assets = navigationECardAssets {
                        NavigationView {
                            ECardEditorView(
                                initialAssets: assets,
                                onDismiss: {
                                    navigationPath.removeLast()
                                }
                            )
                        }
                        .navigationBarHidden(true)
                    } else {
                        Text("Assets not available")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationDestination(for: ClipEditorData.self) { _ in
                    // ClipEditorView
                    if let assets = navigationClipAssets {
                        NavigationView {
                            ClipEditorView(
                                initialAssets: assets,
                                onDismiss: {
                                    navigationPath.removeLast()
                                }
                            )
                        }
                        .navigationBarHidden(true)
                    } else {
                        Text("Assets not available")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
        }
        .onChange(of: currentTab) { _, newRoute in
            UserDefaults.standard.set(newRoute.rawValue, forKey: "selectedTab")
            
            // Set appropriate toolbar for the selected route
            setupToolbarForRoute(newRoute)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToClipEditor"))) { _ in
            navigateToTab(.clip)
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
                selectedTab: currentTab.rawValue,
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
            // Custom dynamic toolbar (show when enabled)
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
            // Initialize navigation stacks for all tabs
            if tabNavigationStacks.isEmpty {
                for tab in AppTab.allCases {
                    tabNavigationStacks[tab] = NavigationPath()
                }
                print("🔄 ContentView: Initialized navigation stacks for all tabs")
            }
            
            // Configure ActionRouter with services
            ActionRouter.shared.configure(
                sheetStack: sheetStack,
                selectionService: selectedAssetService,
                toolbarManager: toolbarManager
            )
            
            // Start background embedding computation for all photos
            startBackgroundEmbeddingComputation()
            
            // Set up toolbar for initial route
            setupToolbarForRoute(currentTab)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RestoreToolbar"))) { _ in
            // Restore toolbar when returning from overlay views
            print("🔧 ContentView: Restoring toolbar for current route \(currentTab.displayName)")
            setupToolbarForRoute(currentTab)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenCurrentEditor"))) { notification in
            if let editorType = notification.object as? EditorType {
                print("🎨 ContentView: Opening current editor: \(editorType.displayName)")
                switch editorType {
                case .eCard:
                    navigateToTab(.ecard)
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
                navigateToTab(.pin)
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
               let route = AppTab(rawValue: routeName) {
                navigateToTab(route)
                print("🔗 ContentView switched to route: \(route.displayName)")
            } else if let tabIndex = notification.object as? Int {
                // Legacy support for integer tab indices
                let route = tabIndexToRoute(tabIndex)
                navigateToTab(route)
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
                navigateToDuplicatePhotos(targetAsset: firstAsset)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MakeECard"))) { notification in
            if let asset = notification.object as? PHAsset {
                print("🎨 ContentView: Creating ECard for single asset: \(asset.localIdentifier)")
                eCardEditor.startEditing(with: [asset])
                // Clear ecard tab stack and switch to it (fresh start for each ecard)
                clearTabNavigationStack(.ecard)
                navigateToTab(.ecard)
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
                    // Clear ecard tab stack and switch to it (fresh start for each ecard)
                    clearTabNavigationStack(.ecard)
                    navigateToTab(.ecard)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToAllLists"))) { _ in
            print("📝 ContentView: Navigating to All Lists")
            let userId = authService.currentAccount?.id ?? ""
            navigateToAllLists(userId: userId)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToQuickList"))) { _ in
            print("📝 ContentView: Navigating to Quick List")
            let userId = authService.currentAccount?.id ?? ""
            navigateToQuickList(userId: userId)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToNearbyPhotos"))) { notification in
            if let centerLocation = notification.object as? CLLocationCoordinate2D {
                print("📷 ContentView: Navigating to Nearby Photos")
                navigateToNearbyPhotos(centerLocation: centerLocation)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToNearbyLocations"))) { notification in
            if let locationData = notification.object as? [String: Any],
               let searchLocation = locationData["searchLocation"] as? CLLocationCoordinate2D,
               let locationName = locationData["locationName"] as? String {
                print("📍 ContentView: Navigating to Nearby Locations")
                navigateToNearbyLocations(searchLocation: searchLocation, locationName: locationName)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToECardEditor"))) { notification in
            if let assets = notification.object as? [PHAsset] {
                print("🎨 ContentView: Navigating to ECard Editor with \(assets.count) assets")
                navigateToECardEditor(assets: assets)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToClipEditor"))) { notification in
            if let assets = notification.object as? [PHAsset] {
                print("🎬 ContentView: Navigating to Clip Editor with \(assets.count) assets")
                navigateToClipEditor(assets: assets)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToDuplicatePhotos"))) { notification in
            if let asset = notification.object as? PHAsset {
                print("📷 ContentView: Navigating to Duplicate Photos with asset: \(asset.localIdentifier)")
                navigateToDuplicatePhotos(targetAsset: asset)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToPhotoView"))) { notification in
            if let navigationData = notification.object as? [String: Any],
               let photoStackCollection = navigationData["photoStackCollection"] as? RPhotoStackCollection,
               let initialStack = navigationData["initialStack"] as? RPhotoStack {
                print("📷 ContentView: Navigating to SwipePhotoView")
                navigateToPhotoView(photoStackCollection: photoStackCollection, initialStack: initialStack)
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
    
    private func navigateToTab(_ route: AppTab) {
        // Save current tab's navigation stack before switching
        if currentTab != route {
            print("🔄 ContentView: Saving navigation stack for \(currentTab.displayName) and switching to \(route.displayName)")
            
            // Save current navigation stack
            tabNavigationStacks[currentTab] = navigationPath
            
            // Restore target tab's navigation stack (or create empty one)
            navigationPath = tabNavigationStacks[route] ?? NavigationPath()
            
            // Update current tab
            currentTab = route
        }
    }
    
    /// Navigate to a specific tab and optionally push a destination to that tab's stack
    private func navigateToTab(_ route: AppTab, pushDestination destination: (any Hashable)? = nil) {
        // Switch to the target tab first
        navigateToTab(route)
        
        // If a destination is provided, push it to the current navigation stack
        if let destination = destination {
            print("🔄 ContentView: Pushing destination to \(route.displayName) tab")
            navigationPath.append(destination)
        }
    }
    
    /// Clear the navigation stack for a specific tab (useful for resetting tab state)
    private func clearTabNavigationStack(_ route: AppTab) {
        print("🔄 ContentView: Clearing navigation stack for \(route.displayName) tab")
        
        if currentTab == route {
            // If it's the current tab, clear the active navigation path
            navigationPath = NavigationPath()
        }
        
        // Clear the stored stack for this tab
        tabNavigationStacks[route] = NavigationPath()
    }
    
    /// Clear navigation stacks for all tabs (useful for app reset or logout)
    private func clearAllTabNavigationStacks() {
        print("🔄 ContentView: Clearing all tab navigation stacks")
        
        // Clear the active navigation path
        navigationPath = NavigationPath()
        
        // Clear all stored stacks
        for tab in AppTab.allCases {
            tabNavigationStacks[tab] = NavigationPath()
        }
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
    
    func navigateToAllLists(userId: String) {
        let allListsData = AllListsData(userId: userId)
        navigationPath.append(allListsData)
    }
    
    func navigateToQuickList(userId: String) {
        let quickListData = QuickListData(userId: userId)
        navigationPath.append(quickListData)
    }
    
    func navigateToDuplicatePhotos(targetAsset: PHAsset) {
        // Store the target asset
        navigationTargetAsset = targetAsset
        
        // Navigate using DuplicatePhotosData
        let duplicateData = DuplicatePhotosData(targetAssetIdentifier: targetAsset.localIdentifier)
        navigationPath.append(duplicateData)
    }
    
    func navigateToNearbyPhotos(centerLocation: CLLocationCoordinate2D) {
        // Store the center location
        navigationNearbyPhotosCenter = centerLocation
        
        // Navigate using NearbyPhotosData
        let nearbyData = NearbyPhotosData(
            centerLatitude: centerLocation.latitude,
            centerLongitude: centerLocation.longitude
        )
        navigationPath.append(nearbyData)
    }
    
    func navigateToNearbyLocations(searchLocation: CLLocationCoordinate2D, locationName: String) {
        // Store the location data
        navigationNearbyLocationsSearch = searchLocation
        navigationNearbyLocationsName = locationName
        
        // Navigate using NearbyLocationsData
        let nearbyLocationsData = NearbyLocationsData(
            searchLatitude: searchLocation.latitude,
            searchLongitude: searchLocation.longitude,
            locationName: locationName
        )
        navigationPath.append(nearbyLocationsData)
    }
    
    func navigateToECardEditor(assets: [PHAsset]) {
        // Store the assets
        navigationECardAssets = assets
        
        // Navigate using ECardEditorData
        let eCardData = ECardEditorData(assetIdentifiers: assets.map { $0.localIdentifier })
        navigationPath.append(eCardData)
    }
    
    func navigateToClipEditor(assets: [PHAsset]) {
        // Store the assets
        navigationClipAssets = assets
        
        // Navigate using ClipEditorData
        let clipData = ClipEditorData(assetIdentifiers: assets.map { $0.localIdentifier })
        navigationPath.append(clipData)
    }
    
    @ViewBuilder
    private func rootView(for route: AppTab) -> some View {
        switch route {
        case .photo:
            PhotoMainView()
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
                    navigateToTab(.photo) // Return to photos after dismissing
                }
            )
        case .clip:
            ClipEditorView(
                initialAssets: clipEditor.getCurrentAssets(),
                onDismiss: {
                    clipEditor.endEditing()
                    navigateToTab(.photo) // Return to photos after dismissing
                }
            )
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: AppTab) -> some View {
        rootView(for: route)
    }
    
    // MARK: - Toolbar Management
    
    private func setupToolbarForRoute(_ route: AppTab) {
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
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
