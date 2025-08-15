//
//  ActionRouter.swift
//  reminora
//
//  Created by Claude on 8/2/25.
//

import Foundation
import SwiftUI
import Photos
import Combine
import CoreData
import CoreLocation

// MARK: - Action Types
enum ActionType: Equatable {
    // Navigation Actions
    case switchToTab(String)
    case showActionSheet
    
    // Photo Actions
    case archive
    case delete
    case duplicate
    case addToQuickList
    case findSimilar(PHAsset?)
    case findDuplicates(PHAsset?)
    case makeECard([PHAsset])
    case makeClip([PHAsset])
    case makeCollage([PHAsset])
    case sharePhoto(PHAsset?)
    case toggleFavorite(PHAsset?)
    
    // Pin Actions
    case addPin
    case addOpenInvite
    case toggleSort
    case addPinFromPhoto(PHAsset)
    case addPinFromLocation(LocationInfo)
    case showPinDetail(PinData, [PinData])
    
    // List Actions
    case refreshLists
    case showQuickList
    case showAllLists
    
    // QuickList Actions
    case emptyQuickList
    case createListFromQuickList
    case addQuickListToExistingList
    
    // ECard Actions
    case editCaption
    case selectImage
    case savePhoto
    
    // Map Actions
    case showNearbyPhotos(CLLocationCoordinate2D)
    case showNearbyLocations(CLLocationCoordinate2D, String)
    
    // Search Actions
    case showSearchDialog
    
    // Custom Actions
    case custom(String, () -> Void)
    
    static func == (lhs: ActionType, rhs: ActionType) -> Bool {
        switch (lhs, rhs) {
        case (.switchToTab(let a), .switchToTab(let b)): return a == b
        case (.showActionSheet, .showActionSheet): return true
        case (.archive, .archive): return true
        case (.delete, .delete): return true
        case (.duplicate, .duplicate): return true
        case (.addToQuickList, .addToQuickList): return true
        case (.findSimilar(let a), .findSimilar(let b)): return a?.localIdentifier == b?.localIdentifier
        case (.findDuplicates(let a), .findDuplicates(let b)): return a?.localIdentifier == b?.localIdentifier
        case (.makeECard(let a), .makeECard(let b)): return a.map(\.localIdentifier) == b.map(\.localIdentifier)
        case (.makeClip(let a), .makeClip(let b)): return a.map(\.localIdentifier) == b.map(\.localIdentifier)
        case (.makeCollage(let a), .makeCollage(let b)): return a.map(\.localIdentifier) == b.map(\.localIdentifier)
        case (.sharePhoto(let a), .sharePhoto(let b)): return a?.localIdentifier == b?.localIdentifier
        case (.toggleFavorite(let a), .toggleFavorite(let b)): return a?.localIdentifier == b?.localIdentifier
        case (.addPin, .addPin): return true
        case (.addOpenInvite, .addOpenInvite): return true
        case (.toggleSort, .toggleSort): return true
        case (.addPinFromPhoto(let a), .addPinFromPhoto(let b)): return a.localIdentifier == b.localIdentifier
        case (.addPinFromLocation(let a), .addPinFromLocation(let b)): return a.id == b.id
        case (.refreshLists, .refreshLists): return true
        case (.showQuickList, .showQuickList): return true
        case (.showAllLists, .showAllLists): return true
        case (.emptyQuickList, .emptyQuickList): return true
        case (.createListFromQuickList, .createListFromQuickList): return true
        case (.addQuickListToExistingList, .addQuickListToExistingList): return true
        case (.editCaption, .editCaption): return true
        case (.selectImage, .selectImage): return true
        case (.savePhoto, .savePhoto): return true
        case (.showSearchDialog, .showSearchDialog): return true
        case (.custom(let a, _), .custom(let b, _)): return a == b
        default: return false
        }
    }
}

// MARK: - Action Router Service
class ActionRouter: ObservableObject {
    static let shared = ActionRouter()
    
    @Published private var isProcessing = false
    
    // Dependencies - injected to avoid circular references
    private weak var sheetStack: SheetStack?
    private weak var selectionService: SelectionService?
    private weak var toolbarManager: ToolbarManager?
    
    private init() {}
    
    // MARK: - Setup Dependencies
    func configure(
        sheetStack: SheetStack = SheetStack.shared,
        selectionService: SelectionService = SelectionService.shared,
        toolbarManager: ToolbarManager? = nil
    ) {
        self.sheetStack = sheetStack
        self.selectionService = selectionService
        self.toolbarManager = toolbarManager
    }
    
    // MARK: - Action Execution
    func execute(_ action: ActionType) {
        guard !isProcessing else {
            print("🎯 ActionRouter: Ignoring action \(action) - already processing")
            return
        }
        
        print("🎯 ActionRouter: Executing action \(action)")
        isProcessing = true
        
        defer {
            DispatchQueue.main.async {
                self.isProcessing = false
            }
        }
        
        switch action {
        // Navigation Actions
        case .switchToTab(let tabName):
            handleSwitchToTab(tabName)
            
        case .showActionSheet:
            handleShowActionSheet()
            
        // Photo Actions
        case .archive:
            handleArchive()
            
        case .delete:
            handleDelete()
            
        case .duplicate:
            handleDuplicate()
            
        case .addToQuickList:
            handleAddToQuickList()
            
        case .findSimilar(let asset):
            handleFindSimilar(asset)
            
        case .findDuplicates(let asset):
            handleFindDuplicates(asset)
            
        case .makeECard(let assets):
            handleMakeECard(assets)
            
        case .makeClip(let assets):
            handleMakeClip(assets)
            
        case .makeCollage(let assets):
            handleMakeCollage(assets)
            
        case .sharePhoto(let asset):
            handleSharePhoto(asset)
            
        case .toggleFavorite(let asset):
            handleToggleFavorite(asset)
            
        // Pin Actions
        case .addPin:
            handleAddPin()
            
        case .addOpenInvite:
            handleAddOpenInvite()
            
        case .toggleSort:
            handleToggleSort()
            
        case .addPinFromPhoto(let asset):
            handleAddPinFromPhoto(asset)
            
        case .addPinFromLocation(let location):
            handleAddPinFromLocation(location)
            
        case .showPinDetail(let place, let allPlaces):
            handleShowPinDetail(place, allPlaces)
            
        // List Actions
        case .refreshLists:
            handleRefreshLists()
            
        case .showQuickList:
            handleShowQuickList()
            
        case .showAllLists:
            handleShowAllLists()
            
        // QuickList Actions
        case .emptyQuickList:
            handleEmptyQuickList()
            
        case .createListFromQuickList:
            handleCreateListFromQuickList()
            
        case .addQuickListToExistingList:
            handleAddQuickListToExistingList()
            
        // ECard Actions
        case .editCaption:
            handleEditCaption()
            
        case .selectImage:
            handleSelectImage()
            
        case .savePhoto:
            handleSavePhoto()
            
        // Map Actions
        case .showNearbyPhotos(let location):
            handleShowNearbyPhotos(location)
            
        case .showNearbyLocations(let location, let name):
            handleShowNearbyLocations(location, name)
            
        // Search Actions
        case .showSearchDialog:
            handleShowSearchDialog()
            
        // Custom Actions
        case .custom(let id, let closure):
            print("🎯 ActionRouter: Executing custom action \(id)")
            closure()
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleSwitchToTab(_ tabName: String) {
        NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: tabName)
    }
    
    private func handleShowActionSheet() {
        toolbarManager?.showActionSheet = true
    }
    
    private func handleArchive() {
        // TODO: Implement archive functionality
        print("🎯 ActionRouter: Archive action not yet implemented")
    }
    
    private func handleDelete() {
        // TODO: Implement delete functionality
        print("🎯 ActionRouter: Delete action not yet implemented")
    }
    
    private func handleDuplicate() {
        // TODO: Implement duplicate functionality
        print("🎯 ActionRouter: Duplicate action not yet implemented")
    }
    
    private func handleAddToQuickList() {
        NotificationCenter.default.post(name: NSNotification.Name("AddToQuickList"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("QuickListUpdated"), object: nil)
    }
    
    private func handleFindSimilar(_ asset: PHAsset?) {
        if let asset = asset {
            NotificationCenter.default.post(name: NSNotification.Name("FindSimilarPhotos"), object: asset)
        } else {
            // Use first selected asset if available
            if let selectedAssets = getSelectedAssets(), let firstAsset = selectedAssets.first {
                NotificationCenter.default.post(name: NSNotification.Name("FindSimilarPhotos"), object: firstAsset)
            } else {
                print("🎯 ActionRouter: No asset available for find similar")
            }
        }
    }
    
    private func handleFindDuplicates(_ asset: PHAsset?) {
        if let asset = asset {
            sheetStack?.push(.duplicatePhotos(targetAsset: asset))
        } else {
            NotificationCenter.default.post(name: NSNotification.Name("FindDuplicatePhotos"), object: nil)
        }
    }
    
    private func handleMakeECard(_ assets: [PHAsset]) {
        let assetsToUse: [PHAsset]
        
        if assets.isEmpty {
            // Use selected assets
            if let selectedAssets = getSelectedAssets(), !selectedAssets.isEmpty {
                assetsToUse = selectedAssets
            } else {
                print("🎯 ActionRouter: No assets available for ECard")
                return
            }
        } else {
            assetsToUse = assets
        }
        
        // Start ECard editing session
        ECardEditor.shared.startEditing(with: assetsToUse)
        // Switch to Editor tab
        NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: "Editor")
        print("🎯 ActionRouter: Started ECard editing with \(assetsToUse.count) assets")
    }
    
    private func handleMakeClip(_ assets: [PHAsset]) {
        let assetsToUse: [PHAsset]
        
        if assets.isEmpty {
            // Use selected assets
            if let selectedAssets = getSelectedAssets(), !selectedAssets.isEmpty {
                assetsToUse = selectedAssets
            } else {
                print("🎯 ActionRouter: No assets available for Clip")
                return
            }
        } else {
            assetsToUse = assets
        }
        
        // Start Clip editing session
        ClipEditor.shared.startEditing(with: assetsToUse)
        // Show ClipEditorView via SheetStack
        sheetStack?.push(.clipEditor(assets: assetsToUse))
        print("🎯 ActionRouter: Started Clip editing with \(assetsToUse.count) assets")
    }
    
    private func handleMakeCollage(_ assets: [PHAsset]) {
        // TODO: Implement collage functionality
        print("🎯 ActionRouter: Collage action not yet implemented")
    }
    
    private func handleSharePhoto(_ asset: PHAsset?) {
        if let asset = asset {
            PhotoSharingService.shared.sharePhoto(asset)
        } else if let selectedAssets = getSelectedAssets(), let firstAsset = selectedAssets.first {
            PhotoSharingService.shared.sharePhoto(firstAsset)
        } else {
            print("🎯 ActionRouter: No asset available for sharing")
        }
    }
    
    private func handleToggleFavorite(_ asset: PHAsset?) {
        let targetAsset: PHAsset?
        if let asset = asset {
            targetAsset = asset
        } else if let selectedAssets = getSelectedAssets(), let firstAsset = selectedAssets.first {
            targetAsset = firstAsset
        } else {
            print("🎯 ActionRouter: No asset available for favorite toggle")
            return
        }
        
        guard let asset = targetAsset else { return }
        
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = !asset.isFavorite
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("🎯 ActionRouter: Successfully toggled favorite status")
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                } else {
                    print("🎯 ActionRouter: Failed to toggle favorite: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func handleAddPin() {
        NotificationCenter.default.post(name: NSNotification.Name("AddPin"), object: nil)
    }
    
    private func handleAddOpenInvite() {
        NotificationCenter.default.post(name: NSNotification.Name("AddOpenInvite"), object: nil)
    }
    
    private func handleToggleSort() {
        NotificationCenter.default.post(name: NSNotification.Name("ToggleSort"), object: nil)
    }
    
    private func handleAddPinFromPhoto(_ asset: PHAsset) {
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToAddPinFromPhoto"), object: asset)
    }
    
    private func handleAddPinFromLocation(_ location: LocationInfo) {
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToAddPinFromLocation"), object: location)
    }
    
    private func handleShowPinDetail(_ place: PinData, _ allPlaces: [PinData]) {
        sheetStack?.push(.pinDetail(place: place, allPlaces: allPlaces))
    }
    
    private func handleRefreshLists() {
        NotificationCenter.default.post(name: NSNotification.Name("RefreshLists"), object: nil)
    }
    
    private func handleShowQuickList() {
        sheetStack?.push(.quickList)
    }
    
    private func handleShowAllLists() {
        sheetStack?.push(.allLists)
    }
    
    private func handleShowNearbyPhotos(_ location: CLLocationCoordinate2D) {
        sheetStack?.push(.nearbyPhotos(centerLocation: location))
    }
    
    private func handleShowNearbyLocations(_ location: CLLocationCoordinate2D, _ name: String) {
        sheetStack?.push(.nearbyLocations(searchLocation: location, locationName: name))
    }
    
    private func handleShowSearchDialog() {
        sheetStack?.push(.searchDialog)
    }
    
    private func handleEmptyQuickList() {
        NotificationCenter.default.post(name: NSNotification.Name("EmptyQuickList"), object: nil)
    }
    
    private func handleCreateListFromQuickList() {
        NotificationCenter.default.post(name: NSNotification.Name("CreateListFromQuickList"), object: nil)
    }
    
    private func handleAddQuickListToExistingList() {
        NotificationCenter.default.post(name: NSNotification.Name("AddQuickListToExistingList"), object: nil)
    }
    
    private func handleEditCaption() {
        ECardEditor.shared.editCaption()
    }
    
    private func handleSelectImage() {
        ECardEditor.shared.selectImage()
    }
    
    private func handleSavePhoto() {
        ECardEditor.shared.savePhoto()
    }
    
    // MARK: - Helper Methods
    
    private func getSelectedAssets() -> [PHAsset]? {
        guard let selectionService = selectionService else {
            return nil
        }
        
        // First check for multi-selected photos
        if !selectionService.selectedPhotoIdentifiers.isEmpty {
            let fetchOptions = PHFetchOptions()
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(selectionService.selectedPhotoIdentifiers), options: fetchOptions)
            return (0..<fetchResult.count).compactMap { fetchResult.object(at: $0) }
        }
        
        // If no multi-selected photos, check for current photo (SwipePhotoView scenario)
        if let currentPhoto = selectionService.getCurrentPhoto {
            return [currentPhoto]
        }
        
        return nil
    }
    
    // MARK: - Convenience Methods
    
    /// Create a button action closure for the given action type
    func createAction(_ actionType: ActionType) -> () -> Void {
        return { [weak self] in
            self?.execute(actionType)
        }
    }
    
    /// Execute action with automatic asset selection
    func executeWithCurrentAsset(_ actionType: ActionType) {
        // Some actions might need the current asset automatically injected
        switch actionType {
        case .findSimilar(_):
            execute(.findSimilar(nil)) // Will use first selected asset
        case .sharePhoto(_):
            execute(.sharePhoto(nil)) // Will use first selected asset
        case .toggleFavorite(_):
            execute(.toggleFavorite(nil)) // Will use first selected asset
        default:
            execute(actionType)
        }
    }
}

// MARK: - Environment Integration
private struct ActionRouterKey: EnvironmentKey {
    static let defaultValue = ActionRouter.shared
}

extension EnvironmentValues {
    var actionRouter: ActionRouter {
        get { self[ActionRouterKey.self] }
        set { self[ActionRouterKey.self] = newValue }
    }
}