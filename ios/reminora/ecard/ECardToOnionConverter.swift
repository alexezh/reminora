//
//  ECardToOnionConverter.swift
//  reminora
//
//  Created by Claude on 8/22/25.
//

import Foundation
import UIKit
import Photos
import SwiftUI

/// Converts ECard templates and instances into Onion scenes for rendering
class ECardToOnionConverter {
    static let shared = ECardToOnionConverter()
    
    private init() {}
    
    // MARK: - Template to Scene Conversion
    
    /// Convert an ECard template into an OnionScene with the given size
    func createScene(
        from template: ECardTemplate,
        imageAssignments: [String: PHAsset],
        textAssignments: [String: String],
        size: CGSize = CGSize(width: 800, height: 1000)
    ) async throws -> OnionScene {
        
        let scene = OnionScene(name: "ECard - \(template.name)", size: size)
        scene.backgroundColor = "#FFFFFF" // White background for ECards
        
        // Calculate scale factor from template coordinates to scene size
        let scaleX = size.width / template.svgDimensions.width
        let scaleY = size.height / template.svgDimensions.height
        
        print("🎨 ECardToOnionConverter: Creating scene with scale factors: x=\(scaleX), y=\(scaleY)")
        
        var zOrder = 0
        
        // Add image layers
        for imageSlot in template.imageSlots {
            if let asset = imageAssignments[imageSlot.id] {
                do {
                    let imageLayer = try await createImageLayer(
                        from: asset,
                        slot: imageSlot,
                        scaleX: scaleX,
                        scaleY: scaleY,
                        zOrder: zOrder
                    )
                    scene.addLayer(imageLayer)
                    zOrder += 1
                    print("🖼️ ECardToOnionConverter: Added image layer for slot \(imageSlot.id)")
                } catch {
                    print("❌ ECardToOnionConverter: Failed to create image layer for slot \(imageSlot.id): \(error)")
                }
            }
        }
        
        // Add text layers
        for textSlot in template.textSlots {
            let text = textAssignments[textSlot.id] ?? textSlot.placeholder
            let textLayer = createTextLayer(
                from: text,
                slot: textSlot,
                scaleX: scaleX,
                scaleY: scaleY,
                zOrder: zOrder
            )
            scene.addLayer(textLayer)
            zOrder += 1
            print("📝 ECardToOnionConverter: Added text layer for slot \(textSlot.id): '\(text)'")
        }
        
        print("✅ ECardToOnionConverter: Created scene with \(scene.layers.count) layers")
        return scene
    }
    
    // MARK: - Layer Creation
    
    private func createImageLayer(
        from asset: PHAsset,
        slot: ImageSlot,
        scaleX: CGFloat,
        scaleY: CGFloat,
        zOrder: Int
    ) async throws -> ImageLayer {
        
        // Load image data from PHAsset
        let imageData = try await loadImageData(from: asset)
        
        // Create transform based on slot position and size
        let transform = LayerTransform(
            position: CGPoint(
                x: slot.x * scaleX,
                y: slot.y * scaleY
            ),
            size: CGSize(
                width: slot.width * scaleX,
                height: slot.height * scaleY
            )
        )
        
        var imageLayer = ImageLayer(
            name: "Image - \(slot.id)",
            transform: transform
        )
        
        imageLayer.imageData = imageData
        imageLayer.contentMode = .scaleAspectFill // Fill the slot area
        imageLayer.zOrder = zOrder
        
        return imageLayer
    }
    
    private func createTextLayer(
        from text: String,
        slot: TextSlot,
        scaleX: CGFloat,
        scaleY: CGFloat,
        zOrder: Int
    ) -> TextLayer {
        
        // Create transform based on slot position and size
        let transform = LayerTransform(
            position: CGPoint(
                x: slot.x * scaleX,
                y: slot.y * scaleY
            ),
            size: CGSize(
                width: slot.width * scaleX,
                height: slot.height * scaleY
            )
        )
        
        var textLayer = TextLayer(
            name: "Text - \(slot.id)",
            transform: transform
        )
        
        textLayer.text = text
        textLayer.fontSize = slot.fontSize * min(scaleX, scaleY) // Scale font size
        textLayer.textColor = "#000000" // Black text
        textLayer.textAlignment = .center // Center align text in ECards
        textLayer.zOrder = zOrder
        
        return textLayer
    }
    
    // MARK: - Image Loading
    
    private func loadImageData(from asset: PHAsset) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let imageManager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            
            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let imageData = data else {
                    continuation.resume(throwing: ECardToOnionError.imageLoadFailed)
                    return
                }
                
                continuation.resume(returning: imageData)
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Create a scene from ECardEditor's current state
    func createSceneFromEditor(
        template: ECardTemplate,
        imageAssignments: [String: PHAsset],
        textAssignments: [String: String],
        size: CGSize = CGSize(width: 800, height: 1000)
    ) async throws -> OnionScene {
        return try await createScene(
            from: template,
            imageAssignments: imageAssignments,
            textAssignments: textAssignments,
            size: size
        )
    }
    
    /// Get recommended scene size for an ECard template
    func recommendedSceneSize(for template: ECardTemplate, quality: OnionRenderConfig.RenderQuality = .high) -> CGSize {
        let baseSize = CGSize(width: 800, height: 1000) // 4:5 aspect ratio for ECards
        let scale = quality.scaleFactor
        return CGSize(width: baseSize.width * scale, height: baseSize.height * scale)
    }
}

// MARK: - Errors

enum ECardToOnionError: LocalizedError {
    case imageLoadFailed
    case invalidTemplate
    case missingAsset(String)
    
    var errorDescription: String? {
        switch self {
        case .imageLoadFailed:
            return "Failed to load image data from photo asset"
        case .invalidTemplate:
            return "Invalid ECard template structure"
        case .missingAsset(let assetId):
            return "Missing photo asset: \(assetId)"
        }
    }
}

// MARK: - Environment Integration

private struct ECardToOnionConverterKey: EnvironmentKey {
    static let defaultValue = ECardToOnionConverter.shared
}

extension EnvironmentValues {
    var eCardToOnionConverter: ECardToOnionConverter {
        get { self[ECardToOnionConverterKey.self] }
        set { self[ECardToOnionConverterKey.self] = newValue }
    }
}