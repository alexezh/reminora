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
    
    // MARK: - Action Handlers
    
    public func switchToTab(_ tabName: String) {
        NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: tabName)
    }
    
    public func showActionSheet() {
        // Use broadcast event instead of direct property access
        NotificationCenter.default.post(name: NSNotification.Name("FABPressed"), object: nil)
    }
    
    public func archivePhoto() {
        // TODO: Implement archive functionality
        print("🎯 ActionRouter: Archive action not yet implemented")
    }
    
    public func deletePhoto() {
        // TODO: Implement delete functionality
        print("🎯 ActionRouter: Delete action not yet implemented")
    }
    
    public func duplicatePhoto() {
        // TODO: Implement duplicate functionality
        print("🎯 ActionRouter: Duplicate action not yet implemented")
    }
    
    public func addToQuickList(_ stack: [RPhotoStack]) {
        NotificationCenter.default.post(name: NSNotification.Name("AddToQuickList"), object: stack)
        NotificationCenter.default.post(name: NSNotification.Name("QuickListUpdated"), object: stack)
    }
    
    public func openPhotoView(collection: RPhotoStackCollection, photo: RPhotoStack) {
        let navigationData = PhotoViewData(
            collection: collection,
            photo: photo
        )
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToPhotoView"), object: navigationData)
    }
    
    public func findSimilar(_ asset: [RPhotoStack]) {
        if asset.count == 0 {
            return;
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("FindSimilarPhotos"), object: asset)
    }
    
    public func findDuplicates(_ asset: [RPhotoStack]) {
        if asset.count == 0 {
            return;
        }
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToDuplicatePhotos"), object: asset)
    }
    
    public func makeECard(_ stacks: [RPhotoStack]) {
        if stacks.isEmpty {
            print("🎯 ActionRouter: No assets available for ECard")
            return
        }
        
        // Start ECard editing session and navigate to ECardEditor
        ECardEditor.shared.startEditing(with: stacks)
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToECardEditor"), object: ECardEditorData(stacks: stacks))
        print("🎯 ActionRouter: Started ECard editing with \(stacks.count) assets")
    }
    
    public func makeClip(_ assets: [RPhotoStack]) {
        if assets.isEmpty {
            print("🎯 ActionRouter: No assets available for Clip")
            return
        }
        
        // Start Clip editing session and navigate to ClipEditor
        ClipEditor.shared.startEditing(with: assets)
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToClipEditor"), object: assets)
        print("🎯 ActionRouter: Started Clip editing with \(assets.count) assets")
    }
    
    public func makeCollage(_ assets: [PHAsset]) {
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
    
    public func addPin() {
        NotificationCenter.default.post(name: NSNotification.Name("AddPin"), object: nil)
    }
    
    public func addOpenInvite() {
        NotificationCenter.default.post(name: NSNotification.Name("AddOpenInvite"), object: nil)
    }
    
    public func toggleSort() {
        NotificationCenter.default.post(name: NSNotification.Name("ToggleSort"), object: nil)
    }
    
    public func addPinFromPhoto(_ asset: RPhotoStack) {
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToAddPinFromPhoto"), object: asset)
    }
    
    public func addPinFromLocation(_ location: LocationInfo) {
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToAddPinFromLocation"), object: location)
    }
    
    public func showPinDetail(_ place: PinData, _ allPlaces: [PinData]) {
        sheetStack?.push(.pinDetail(place: place, allPlaces: allPlaces))
    }
    
    public func refreshLists() {
        NotificationCenter.default.post(name: NSNotification.Name("RefreshLists"), object: nil)
    }
    
    private func showQuickList() {
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToQuickList"), object: nil)
    }
    
    private func showAllLists() {
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToAllLists"), object: nil)
    }
    
    private func showNearbyPhotos(_ location: CLLocationCoordinate2D) {
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToNearbyPhotos"), object: location)
    }
    
    public func showNearbyLocations(_ location: CLLocationCoordinate2D, _ name: String) {
        let locationData: [String: Any] = ["searchLocation": location, "locationName": name]
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToNearbyLocations"), object: locationData)
    }
    
    public func showSearchDialog() {
        sheetStack?.push(.searchDialog)
    }
    
    public func emptyQuickList() {
        NotificationCenter.default.post(name: NSNotification.Name("EmptyQuickList"), object: nil)
    }
    
    public func createListFromQuickList() {
        NotificationCenter.default.post(name: NSNotification.Name("CreateListFromQuickList"), object: nil)
    }
    
    public func addQuickListToExistingList() {
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
        if !selectionService.selectedPhotos.isEmpty {
            let fetchOptions = PHFetchOptions()
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: selectionService.selectedPhotos.map{ $0.localIdentifier }, options: fetchOptions)
            return (0..<fetchResult.count).compactMap { fetchResult.object(at: $0) }
        }
        
        return nil
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
