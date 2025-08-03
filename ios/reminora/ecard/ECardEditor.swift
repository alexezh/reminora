//
//  ECardEditor.swift
//  reminora
//
//  Created by Claude on 8/3/25.
//

import Foundation
import Photos
import SwiftUI

// MARK: - ECard Editor State Manager
class ECardEditor: ObservableObject {
    @Published var isActive: Bool = false
    @Published var currentAssets: [PHAsset] = []
    
    static let shared = ECardEditor()
    
    private let userDefaults = UserDefaults.standard
    private let currentAssetIdsKey = "ECardEditor.currentAssetIds"
    private let isActiveKey = "ECardEditor.isActive"
    
    private init() {
        loadPersistedState()
    }
    
    // MARK: - Public Interface
    
    /// Start ECard editing session with assets
    func startEditing(with assets: [PHAsset]) {
        DispatchQueue.main.async {
            self.currentAssets = assets
            self.isActive = true
            self.persistState()
            
            // Set the current editor in ActionSheet model
            UniversalActionSheetModel.shared.setCurrentEditor(.eCard)
            
            print("🎨 ECardEditor: Started editing with \(assets.count) assets")
        }
    }
    
    /// End ECard editing session
    func endEditing() {
        DispatchQueue.main.async {
            self.currentAssets = []
            self.isActive = false
            self.clearPersistedState()
            
            // Clear the current editor in ActionSheet model
            UniversalActionSheetModel.shared.setCurrentEditor(nil)
            
            print("🎨 ECardEditor: Ended editing session")
        }
    }
    
    /// Check if currently editing
    var hasActiveSession: Bool {
        return isActive && !currentAssets.isEmpty
    }
    
    /// Get current editing assets
    func getCurrentAssets() -> [PHAsset] {
        return currentAssets
    }
    
    // MARK: - Action Methods
    
    /// Edit caption action
    func editCaption() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ECardEditCaption"), object: nil)
            print("🎨 ECardEditor: Edit caption action triggered")
        }
    }
    
    /// Select image action
    func selectImage() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ECardSelectImage"), object: nil)
            print("🎨 ECardEditor: Select image action triggered")
        }
    }
    
    /// Save photo action with high quality rendering
    func savePhoto() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ECardSavePhoto"), object: nil)
            print("🎨 ECardEditor: Save photo action triggered")
        }
    }
    
    // MARK: - Persistence
    
    private func persistState() {
        let assetIds = currentAssets.map { $0.localIdentifier }
        userDefaults.set(assetIds, forKey: currentAssetIdsKey)
        userDefaults.set(isActive, forKey: isActiveKey)
        
        print("🎨 ECardEditor: Persisted state - \(assetIds.count) assets, active: \(isActive)")
    }
    
    private func loadPersistedState() {
        guard let persistedAssetIds = userDefaults.array(forKey: currentAssetIdsKey) as? [String],
              !persistedAssetIds.isEmpty else {
            return
        }
        
        let wasActive = userDefaults.bool(forKey: isActiveKey)
        guard wasActive else {
            clearPersistedState()
            return
        }
        
        // Restore assets from persisted IDs
        let fetchOptions = PHFetchOptions()
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: persistedAssetIds, options: fetchOptions)
        let restoredAssets = (0..<fetchResult.count).compactMap { fetchResult.object(at: $0) }
        
        if !restoredAssets.isEmpty {
            DispatchQueue.main.async {
                self.currentAssets = restoredAssets
                self.isActive = true
                
                // Restore editor state in ActionSheet model
                UniversalActionSheetModel.shared.setCurrentEditor(.eCard)
                
                print("🎨 ECardEditor: Restored editing session with \(restoredAssets.count) assets")
            }
        } else {
            // Assets no longer exist, clear state
            clearPersistedState()
        }
    }
    
    private func clearPersistedState() {
        userDefaults.removeObject(forKey: currentAssetIdsKey)
        userDefaults.removeObject(forKey: isActiveKey)
        
        print("🎨 ECardEditor: Cleared persisted state")
    }
}

// MARK: - Environment Key
private struct ECardEditorKey: EnvironmentKey {
    static let defaultValue = ECardEditor.shared
}

extension EnvironmentValues {
    var eCardEditor: ECardEditor {
        get { self[ECardEditorKey.self] }
        set { self[ECardEditorKey.self] = newValue }
    }
}