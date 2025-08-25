//
//  SelectedAssetService.swift
//  reminora
//
//  Created by Claude on 8/2/25.
//

import Foundation
import Photos
import SwiftUI

// MARK: - Selected Asset Types
enum SelectedAssetType {
    case photo(PHAsset)
    case pin(PinData)
}

// MARK: - Selected Asset Service
class SelectionService: ObservableObject {
    static let shared = SelectionService()
    
    @Published private var _selectedPhotos: Set<RPhotoStack> = [] // Asset localIdentifiers
    @Published private var selectedPins: Set<String> = [] // Pin objectID strings
    
    private init() {}
    
    // MARK: - Photo Selection Management
    
    func setSelectedPhotos(_ photoIdentifiers: Set<RPhotoStack>) {
        _selectedPhotos = photoIdentifiers
        print("📱 SelectedAssetService: Updated selected photos count: \(_selectedPhotos.count)")
    }

    func setSelectedPhoto(_ photo: RPhotoStack) {
        _selectedPhotos = [photo]
        print("📱 SelectedAssetService: Updated selected photos count: \(_selectedPhotos.count)")
    }

    func addSelectedPhoto(_ photoIdentifier: RPhotoStack) {
        _selectedPhotos.insert(photoIdentifier)
        print("📱 SelectedAssetService: Added photo to selection, total: \(_selectedPhotos.count)")
    }
    
    func removeSelectedPhoto(_ photoIdentifier: RPhotoStack) {
        _selectedPhotos.remove(photoIdentifier)
        print("📱 SelectedAssetService: Removed photo from selection, total: \(_selectedPhotos.count)")
    }
    
    func clearSelectedPhotos() {
        _selectedPhotos.removeAll()
        print("📱 SelectedAssetService: Cleared photo selection")
    }
    
    func isPhotoSelected(_ photoIdentifier: RPhotoStack) -> Bool {
        return _selectedPhotos.contains(photoIdentifier)
    }
    
    var selectedPhotos: Set<RPhotoStack> {
        return _selectedPhotos
    }

    var selectedPhotosArray: [RPhotoStack] {
        return Array(_selectedPhotos)
    }

    // MARK: - Pin Selection Management
    
    func setSelectedPins(_ pinIds: Set<String>) {
        selectedPins = pinIds
        print("📱 SelectedAssetService: Updated selected pins count: \(selectedPins.count)")
    }
    
    func addSelectedPin(_ pinId: String) {
        selectedPins.insert(pinId)
        print("📱 SelectedAssetService: Added pin to selection, total: \(selectedPins.count)")
    }
    
    func removeSelectedPin(_ pinId: String) {
        selectedPins.remove(pinId)
        print("📱 SelectedAssetService: Removed pin from selection, total: \(selectedPins.count)")
    }
    
    func clearSelectedPins() {
        selectedPins.removeAll()
        print("📱 SelectedAssetService: Cleared pin selection")
    }
    
    func isPinSelected(_ pinId: String) -> Bool {
        return selectedPins.contains(pinId)
    }
    
    var selectedPinIds: Set<String> {
        return selectedPins
    }
    
    // MARK: - Legacy Photo Management (for backwards compatibility)
    
    /// Returns true if any photos are selected OR there's a current photo stack
    var hasPhotoSelection: Bool {
        return !_selectedPhotos.isEmpty
    }
    
    /// Returns true if any pins are selected
    var hasPinSelection: Bool {
        return !selectedPins.isEmpty
    }
    
    /// Returns true if anything is selected (photos, pins, or current photo)
    var hasSelection: Bool {
        return hasPhotoSelection || hasPinSelection
    }
    
    /// Returns the count of selected photos (not including current photo)
    var selectedPhotoCount: Int {
        return _selectedPhotos.count
    }
    
    /// Returns the count of selected pins
    var selectedPinCount: Int {
        return selectedPins.count
    }
    
    // MARK: - Clear All Selections
    
    func clearAllSelections() {
        _selectedPhotos.removeAll()
        selectedPins.removeAll()
        print("📱 SelectedAssetService: Cleared all selections")
    }
    
    // MARK: - Context-Aware Selection Info
    
    /// Get selection info for current context
    func getSelectionInfo() -> (hasPhotos: Bool, hasPin: Bool, photoCount: Int, pinCount: Int) {
        return (
            hasPhotos: !_selectedPhotos.isEmpty,
            hasPin: !selectedPins.isEmpty,
            photoCount: _selectedPhotos.count,
            pinCount: selectedPins.count
        )
    }
}

// MARK: - Environment Integration
private struct SelectedAssetServiceKey: EnvironmentKey {
    static let defaultValue = SelectionService.shared
}

extension EnvironmentValues {
    var selectedAssetService: SelectionService {
        get { self[SelectedAssetServiceKey.self] }
        set { self[SelectedAssetServiceKey.self] = newValue }
    }
}
