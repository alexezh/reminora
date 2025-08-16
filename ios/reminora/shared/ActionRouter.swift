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
    
    // Pin Actions
    case addPin
    case addOpenInvite
    case toggleSort
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
        
    // Map Actions
    case showNearbyPhotos(CLLocationCoordinate2D)
    case showNearbyLocations(CLLocationCoordinate2D, String)
    
    // Search Actions
    case showSearchDialog
    
    // Custom Actions
    case custom(String, () -> Void)
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
            
        // Pin Actions
        case .addPin:
            handleAddPin()
            
        case .addOpenInvite:
            handleAddOpenInvite()
            
        case .toggleSort:
            handleToggleSort()
            
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
    
    public func addToQuickList(stack: RPhotoStack) {
        NotificationCenter.default.post(name: NSNotification.Name("AddToQuickList"), object: stack)
        NotificationCenter.default.post(name: NSNotification.Name("QuickListUpdated"), object: stack)
    }
    
    public func findSimilar(_ asset: PHAsset?) {
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
    
    private func findDuplicates(_ asset: PHAsset?) {
        if let asset = asset {
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToDuplicatePhotos"), object: asset)
        } else {
            NotificationCenter.default.post(name: NSNotification.Name("FindDuplicatePhotos"), object: nil)
        }
    }
    
    private func makeECard(_ assets: [PHAsset]) {
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
        
        // Start ECard editing session and navigate to ECardEditor
        ECardEditor.shared.startEditing(with: assetsToUse)
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToECardEditor"), object: assetsToUse)
        print("🎯 ActionRouter: Started ECard editing with \(assetsToUse.count) assets")
    }
    
    private func makeClip(_ assets: [PHAsset]) {
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
        
        // Start Clip editing session and navigate to ClipEditor
        ClipEditor.shared.startEditing(with: assetsToUse)
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToClipEditor"), object: assetsToUse)
        print("🎯 ActionRouter: Started Clip editing with \(assetsToUse.count) assets")
    }
    
    private func makeCollage(_ assets: [PHAsset]) {
        // TODO: Implement collage functionality
        print("🎯 ActionRouter: Collage action not yet implemented")
    }
    
    public func sharePhoto(_ stack: RPhotoStack?) {
        if let stack = stack {
            PhotoSharingService.shared.sharePhoto(stack.primaryAsset)
        } else {
            print("🎯 ActionRouter: No asset available for sharing")
        }
    }
    
    public func toggleFavorite(_ stqck: RPhotoStack?) {
        
        guard let stqck = stqck else { return }
        
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: stqck.primaryAsset)
            request.isFavorite = !stqck.primaryAsset.isFavorite
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
    
    public func addPinFromPhoto(_ asset: RPhotoStack) {
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
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToQuickList"), object: nil)
    }
    
    private func handleShowAllLists() {
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToAllLists"), object: nil)
    }
    
    private func handleShowNearbyPhotos(_ location: CLLocationCoordinate2D) {
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToNearbyPhotos"), object: location)
    }
    
    private func handleShowNearbyLocations(_ location: CLLocationCoordinate2D, _ name: String) {
        let locationData: [String: Any] = ["searchLocation": location, "locationName": name]
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToNearbyLocations"), object: locationData)
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
    
    public func editCaption() {
        ECardEditor.shared.editCaption()
    }
    
    public func selectImage() {
        ECardEditor.shared.selectImage()
    }
    
    public func savePhoto() {
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
