//
//  ECardEditor.swift
//  reminora
//
//  Created by Claude on 8/3/25.
//

import Foundation
import Photos
import SwiftUI
import UIKit

// MARK: - ECard Editor State Manager
class ECardEditor: ObservableObject {
    @Published var isActive: Bool = false
    @Published var currentAssets: [PHAsset] = []
    @Published var currentTemplate: ECardTemplate?
    @Published var imageAssignments: [String: PHAsset] = [:]
    @Published var textAssignments: [String: String] = [:]
    
    static let shared = ECardEditor()
    
    private let userDefaults = UserDefaults.standard
    private let currentAssetIdsKey = "ECardEditor.currentAssetIds"
    private let isActiveKey = "ECardEditor.isActive"
    private let currentTemplateIdKey = "ECardEditor.currentTemplateId"
    private let imageAssignmentsKey = "ECardEditor.imageAssignments"
    private let textAssignmentsKey = "ECardEditor.textAssignments"
    
    private init() {
        loadPersistedState()
    }
    
    // MARK: - Public Interface
    
    /// Start ECard editing session with assets
    func startEditing(with assets: [PHAsset]) {
        DispatchQueue.main.async {
            self.currentAssets = assets
            self.isActive = true
            
            // Auto-assign first asset to first image slot if template is available
            if let template = self.currentTemplate,
               let firstAsset = assets.first,
               let firstImageSlot = template.imageSlots.first {
                self.imageAssignments[firstImageSlot.id] = firstAsset
            }
            
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
            self.currentTemplate = nil
            self.imageAssignments = [:]
            self.textAssignments = [:]
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
    
    /// Set current template and persist state
    func setCurrentTemplate(_ template: ECardTemplate) {
        DispatchQueue.main.async {
            self.currentTemplate = template
            
            // Auto-assign first asset to first image slot if available
            if let firstAsset = self.currentAssets.first,
               let firstImageSlot = template.imageSlots.first {
                self.imageAssignments[firstImageSlot.id] = firstAsset
            }
            
            // Initialize text assignments with placeholders
            for textSlot in template.textSlots {
                if self.textAssignments[textSlot.id] == nil {
                    self.textAssignments[textSlot.id] = textSlot.placeholder
                }
            }
            
            self.persistState()
            print("🎨 ECardEditor: Set template \(template.name) with \(self.imageAssignments.count) image assignments")
        }
    }
    
    /// Update image assignment
    func setImageAssignment(assetId: String, for slotId: String) {
        DispatchQueue.main.async {
            if let asset = self.currentAssets.first(where: { $0.localIdentifier == assetId }) {
                self.imageAssignments[slotId] = asset
                self.persistState()
                print("🎨 ECardEditor: Assigned asset \(assetId) to slot \(slotId)")
            }
        }
    }
    
    /// Update text assignment
    func setTextAssignment(text: String, for slotId: String) {
        DispatchQueue.main.async {
            self.textAssignments[slotId] = text
            self.persistState()
            print("🎨 ECardEditor: Set text for slot \(slotId)")
        }
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
    
    // MARK: - Image Generation
    
    /// Generate ECard image with template, image assignments, and text assignments
    func generateECardImage(
        template: ECardTemplate,
        imageAssignments: [String: PHAsset],
        textAssignments: [String: String],
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        let size = CGSize(width: 800, height: 1000) // High quality size
        
        // Pre-load all assigned images first
        var loadedImages: [String: UIImage] = [:]
        let dispatchGroup = DispatchGroup()
        
        // Load all assigned images asynchronously
        for slot in template.imageSlots {
            if let asset = imageAssignments[slot.id] {
                dispatchGroup.enter()
                
                let imageManager = PHImageManager.default()
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.resizeMode = .exact
                options.isNetworkAccessAllowed = true
                
                imageManager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: 800, height: 600), // High resolution
                    contentMode: .aspectFill,
                    options: options
                ) { loadedImage, _ in
                    if let loadedImage = loadedImage {
                        loadedImages[slot.id] = loadedImage
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        // Once all images are loaded, render the final ECard
        dispatchGroup.notify(queue: .main) {
            self.renderECardWithImages(
                template: template,
                loadedImages: loadedImages,
                textAssignments: textAssignments,
                size: size,
                completion: completion
            )
        }
    }
    
    /// Render the final ECard image with loaded images and text
    private func renderECardWithImages(
        template: ECardTemplate,
        loadedImages: [String: UIImage],
        textAssignments: [String: String],
        size: CGSize,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let cgContext = context.cgContext
            
            // White background
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Draw assigned images based on template layout
            for (index, slot) in template.imageSlots.enumerated() {
                if let loadedImage = loadedImages[slot.id] {
                    // Calculate image position based on template slots
                    let imageWidth: CGFloat = 600
                    let imageHeight: CGFloat = 400
                    let x: CGFloat = (size.width - imageWidth) / 2 // Center horizontally
                    let y: CGFloat = 60 + CGFloat(index) * 420
                    
                    let imageRect = CGRect(x: x, y: y, width: imageWidth, height: imageHeight)
                    
                    // Save context, apply corner radius if specified
                    cgContext.saveGState()
                    if slot.cornerRadius > 0 {
                        let path = UIBezierPath(roundedRect: imageRect, cornerRadius: CGFloat(slot.cornerRadius))
                        cgContext.addPath(path.cgPath)
                        cgContext.clip()
                    }
                    
                    // Draw the image with aspect fill behavior
                    let aspectRatio = loadedImage.size.width / loadedImage.size.height
                    let targetAspectRatio = imageWidth / imageHeight
                    
                    var drawRect = imageRect
                    if aspectRatio > targetAspectRatio {
                        // Image is wider, fit height and crop width
                        let scaledWidth = imageHeight * aspectRatio
                        drawRect = CGRect(x: imageRect.midX - scaledWidth/2, y: imageRect.minY, width: scaledWidth, height: imageHeight)
                    } else {
                        // Image is taller, fit width and crop height
                        let scaledHeight = imageWidth / aspectRatio
                        drawRect = CGRect(x: imageRect.minX, y: imageRect.midY - scaledHeight/2, width: imageWidth, height: scaledHeight)
                    }
                    
                    loadedImage.draw(in: drawRect)
                    cgContext.restoreGState()
                }
            }
            
            // Draw text slots
            let imageCount = template.imageSlots.count
            var textY: CGFloat = 60 + CGFloat(imageCount) * 420 + 40
            
            for slot in template.textSlots {
                let text = textAssignments[slot.id] ?? slot.placeholder
                let textRect = CGRect(x: 40, y: textY, width: size.width - 80, height: 60)
                
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                
                text.draw(in: textRect, withAttributes: [
                    .font: UIFont.systemFont(ofSize: CGFloat(slot.fontSize)),
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraphStyle
                ])
                textY += 70
            }
        }
        
        completion(.success(image))
    }
    
    /// Save ECard image to photo library with override confirmation
    func saveECardToPhotoLibrary(
        _ image: UIImage,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                let error = NSError(domain: "ECardError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Photo library access denied"])
                completion(.failure(error))
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                
                // Convert to high-quality JPEG data
                guard let jpegData = image.jpegData(compressionQuality: 0.95) else {
                    let error = NSError(domain: "ECardError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
                    completion(.failure(error))
                    return
                }
                
                creationRequest.addResource(with: .photo, data: jpegData, options: nil)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("✅ ECard saved to photo library")
                        completion(.success(()))
                    } else {
                        let saveError = error ?? NSError(domain: "ECardError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to save ECard"])
                        print("❌ Failed to save ECard: \(saveError.localizedDescription)")
                        completion(.failure(saveError))
                    }
                }
            }
        }
    }
    
    // MARK: - Persistence
    
    private func persistState() {
        let assetIds = currentAssets.map { $0.localIdentifier }
        userDefaults.set(assetIds, forKey: currentAssetIdsKey)
        userDefaults.set(isActive, forKey: isActiveKey)
        
        // Persist template
        if let template = currentTemplate {
            userDefaults.set(template.id, forKey: currentTemplateIdKey)
        } else {
            userDefaults.removeObject(forKey: currentTemplateIdKey)
        }
        
        // Persist image assignments (as asset IDs)
        let imageAssignmentIds = imageAssignments.mapValues { $0.localIdentifier }
        userDefaults.set(imageAssignmentIds, forKey: imageAssignmentsKey)
        
        // Persist text assignments
        userDefaults.set(textAssignments, forKey: textAssignmentsKey)
        
        print("🎨 ECardEditor: Persisted state - \(assetIds.count) assets, template: \(currentTemplate?.name ?? "none"), \(imageAssignments.count) image assignments")
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
                
                // Restore template
                if let templateId = self.userDefaults.string(forKey: self.currentTemplateIdKey) {
                    self.currentTemplate = ECardTemplateService.shared.getTemplate(id: templateId)
                }
                
                // Restore text assignments
                if let persistedTextAssignments = self.userDefaults.dictionary(forKey: self.textAssignmentsKey) as? [String: String] {
                    self.textAssignments = persistedTextAssignments
                }
                
                // Restore image assignments
                if let persistedImageAssignmentIds = self.userDefaults.dictionary(forKey: self.imageAssignmentsKey) as? [String: String] {
                    // Convert asset IDs back to PHAssets
                    let allAssetIds = Array(persistedImageAssignmentIds.values)
                    let fetchOptions = PHFetchOptions()
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: allAssetIds, options: fetchOptions)
                    var assetDict: [String: PHAsset] = [:]
                    (0..<fetchResult.count).forEach { index in
                        let asset = fetchResult.object(at: index)
                        assetDict[asset.localIdentifier] = asset
                    }
                    
                    // Rebuild imageAssignments dictionary
                    for (slotId, assetId) in persistedImageAssignmentIds {
                        if let asset = assetDict[assetId] {
                            self.imageAssignments[slotId] = asset
                        }
                    }
                }
                
                // Restore editor state in ActionSheet model
                UniversalActionSheetModel.shared.setCurrentEditor(.eCard)
                
                print("🎨 ECardEditor: Restored editing session with \(restoredAssets.count) assets, template: \(self.currentTemplate?.name ?? "none"), \(self.imageAssignments.count) image assignments")
            }
        } else {
            // Assets no longer exist, clear state
            clearPersistedState()
        }
    }
    
    private func clearPersistedState() {
        userDefaults.removeObject(forKey: currentAssetIdsKey)
        userDefaults.removeObject(forKey: isActiveKey)
        userDefaults.removeObject(forKey: currentTemplateIdKey)
        userDefaults.removeObject(forKey: imageAssignmentsKey)
        userDefaults.removeObject(forKey: textAssignmentsKey)
        
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