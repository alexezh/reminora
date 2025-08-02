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
class SelectedAssetService: ObservableObject {
    static let shared = SelectedAssetService()
    
    @Published private var selectedPhotos: Set<String> = [] // Asset localIdentifiers
    @Published private var selectedPins: Set<String> = [] // Pin objectID strings
    @Published private var currentPhoto: PHAsset? = nil // Current photo in SwipePhotoView
    
    private init() {}
    
    // MARK: - Photo Selection Management
    
    func setSelectedPhotos(_ photoIdentifiers: Set<String>) {
        selectedPhotos = photoIdentifiers
        print("📱 SelectedAssetService: Updated selected photos count: \(selectedPhotos.count)")
    }
    
    func addSelectedPhoto(_ photoIdentifier: String) {
        selectedPhotos.insert(photoIdentifier)
        print("📱 SelectedAssetService: Added photo to selection, total: \(selectedPhotos.count)")
    }
    
    func removeSelectedPhoto(_ photoIdentifier: String) {
        selectedPhotos.remove(photoIdentifier)
        print("📱 SelectedAssetService: Removed photo from selection, total: \(selectedPhotos.count)")
    }
    
    func clearSelectedPhotos() {
        selectedPhotos.removeAll()
        print("📱 SelectedAssetService: Cleared photo selection")
    }
    
    func isPhotoSelected(_ photoIdentifier: String) -> Bool {
        return selectedPhotos.contains(photoIdentifier)
    }
    
    var selectedPhotoIdentifiers: Set<String> {
        return selectedPhotos
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
    
    // MARK: - Current Photo Management (for SwipePhotoView)
    
    func setCurrentPhoto(_ asset: PHAsset?) {
        currentPhoto = asset
        if let asset = asset {
            print("📱 SelectedAssetService: Set current photo: \(asset.localIdentifier)")
        } else {
            print("📱 SelectedAssetService: Cleared current photo")
        }
    }
    
    var getCurrentPhoto: PHAsset? {
        return currentPhoto
    }
    
    // MARK: - Selection State Queries
    
    /// Returns true if any photos are selected OR there's a current photo
    var hasPhotoSelection: Bool {
        return !selectedPhotos.isEmpty || currentPhoto != nil
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
        return selectedPhotos.count
    }
    
    /// Returns the count of selected pins
    var selectedPinCount: Int {
        return selectedPins.count
    }
    
    // MARK: - Clear All Selections
    
    func clearAllSelections() {
        selectedPhotos.removeAll()
        selectedPins.removeAll()
        currentPhoto = nil
        print("📱 SelectedAssetService: Cleared all selections")
    }
    
    // MARK: - Context-Aware Selection Info
    
    /// Get selection info for current context
    func getSelectionInfo() -> (hasPhotos: Bool, hasPin: Bool, hasCurrent: Bool, photoCount: Int, pinCount: Int) {
        return (
            hasPhotos: !selectedPhotos.isEmpty,
            hasPin: !selectedPins.isEmpty,
            hasCurrent: currentPhoto != nil,
            photoCount: selectedPhotos.count,
            pinCount: selectedPins.count
        )
    }
}

// MARK: - Environment Integration
private struct SelectedAssetServiceKey: EnvironmentKey {
    static let defaultValue = SelectedAssetService.shared
}

extension EnvironmentValues {
    var selectedAssetService: SelectedAssetService {
        get { self[SelectedAssetServiceKey.self] }
        set { self[SelectedAssetServiceKey.self] = newValue }
    }
}