//
//  ECardTemplateService.swift
//  reminora
//
//  Created by Claude on 8/2/25.
//

import Foundation
import Photos
import SwiftUI
import UIKit


// MARK: - ECard Template Service
class ECardTemplateService: ObservableObject {
    static let shared = ECardTemplateService()

    @Published private var templates: [ECardTemplate] = []
    private var templatesLoaded = false
    
    // Default output size for ECards
    private let size = CGSize(width: 800, height: 1000)

    private init() {
        // Templates will be loaded lazily on first access
    }

    // MARK: - Public Interface

    func getAllTemplates() -> [ECardTemplate] {
        loadTemplatesIfNeeded()
        return templates
    }

    func getTemplate(id: String) -> ECardTemplate? {
        loadTemplatesIfNeeded()
        return templates.first { $0.id == id }
    }

    func getTemplates(for category: ECardCategory) -> [ECardTemplate] {
        loadTemplatesIfNeeded()
        return templates.filter { $0.category == category }
    }

    func getTemplateForAssets(_ assets: [RPhotoStack]) -> ECardTemplate? {
        loadTemplatesIfNeeded()
        // Return default template since all templates now handle both orientations
        return getTemplate(id: "polaroid_classic") ?? templates.first
    }

    // MARK: - Template Loading

    private func loadTemplatesIfNeeded() {
        guard !templatesLoaded else { return }
        loadBuiltInTemplates()
        templatesLoaded = true
    }

    private func loadBuiltInTemplates() {
        print("🎨 ECardTemplateService: Loading built-in templates...")

        let templateDefinitions: [(String, String, ECardCategory, (PHAsset, String, CGSize) async throws -> OnionScene)] = [
            ("polaroid_classic", "Classic Polaroid", ECardCategory.polaroid, createPolaroidScene),
            ("modern_gradient", "Modern Gradient", ECardCategory.modern, createPolaroidScene),
            ("vintage_postcard", "Vintage Postcard", ECardCategory.vintage, createPolaroidScene),
            ("restaurant_dining", "Restaurant", ECardCategory.general, createPolaroidScene),
            ("vacation_paradise", "Vacation", ECardCategory.travel, createPolaroidScene),
        ]

        templates = templateDefinitions.compactMap { (filename, name, category, sceneBuilder) in
            print("🎨 Loading template: \(filename)")
            let template = createTemplateFromFunction(filename, name: name, category: category, sceneBuilder: sceneBuilder)
            if template != nil {
                print("✅ Successfully loaded: \(filename)")
            } else {
                print("❌ Failed to load: \(filename)")
            }
            return template
        }

        print("🎨 ECardTemplateService: Loaded \(templates.count) templates")
    }

    private func createTemplateFromFunction(
        _ id: String, 
        name: String, 
        category: ECardCategory, 
        sceneBuilder: @escaping (PHAsset, String, CGSize) async throws -> OnionScene
    ) -> ECardTemplate? {
        
        return ECardTemplate(
            id: id,
            name: name,
            category: category
        )
    }
    
    /// Create a polaroid-style scene with white border
    private func createPolaroidScene(
        with asset: PHAsset,
        caption: String,
        size: CGSize
    ) async throws -> OnionScene {
        
        let scene = OnionScene(name: "Polaroid Scene", size: size)
        scene.backgroundColor = "#FFFFFF"
        
        // Polaroid styling: thicker white border, smaller image area
        let borderThickness: CGFloat = 60
        let bottomTextArea: CGFloat = 120
        
        // Create white background border - using standard CoreGraphics coordinates
        let borderTransform = LayerTransform(
            position: CGPoint(x: 0, y: 0),
            size: CGSize(width: size.width, height: size.height)
        )
        
        var borderLayer = GeometryLayer(name: "Polaroid Border", transform: borderTransform)
        borderLayer.shape = .rectangle
        borderLayer.fillColor = "#FFFFFF"
        borderLayer.strokeColor = "#E0E0E0"
        borderLayer.strokeWidth = 1
        borderLayer.cornerRadius = 8
        borderLayer.zOrder = 0
        scene.addLayer(borderLayer)
        
        // Create image layer - positioned with proper coordinate system
        let imageData = try await loadImageData(from: asset)
        let imageTransform = LayerTransform(
            position: CGPoint(x: borderThickness, y: borderThickness),
            size: CGSize(width: size.width - (borderThickness * 2), height: size.height - borderThickness - bottomTextArea)
        )
        
        var imageLayer = ImageLayer(name: "Photo", transform: imageTransform)
        imageLayer.imageData = imageData
        imageLayer.contentMode = .scaleAspectFill
        imageLayer.zOrder = 10  // Higher z-order to ensure it's visible
        scene.addLayer(imageLayer)
        
        print("🖼️ Created image layer with data size: \(imageData.count) bytes, z-order: \(imageLayer.zOrder)")
        
        // Create text layer in bottom white area - using bottom-up positioning
        let textTransform = LayerTransform(
            position: CGPoint(x: borderThickness, y: size.height - bottomTextArea + 20),
            size: CGSize(width: size.width - (borderThickness * 2), height: 40)
        )
        
        var textLayer = TextLayer(name: "Caption", transform: textTransform)
        textLayer.text = caption
        textLayer.fontSize = 28
        textLayer.textColor = "#333333"
        textLayer.textAlignment = .center
        textLayer.zOrder = 20  // Ensure text is on top
        scene.addLayer(textLayer)
        
        print("📝 Created text layer with caption: '\(caption)', z-order: \(textLayer.zOrder)")
        
        return scene
    }
    
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
                    continuation.resume(throwing: NSError(domain: "ECardTemplateService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image data"]))
                    return
                }
                
                continuation.resume(returning: imageData)
            }
        }
    }
    
    /// Create scene from template using its scene builder
    func createScene(from template: ECardTemplate, asset: PHAsset, caption: String = "Caption") async throws -> OnionScene {
        return try await createPolaroidScene(with: asset, caption: caption, size: CGSize(width: 800, height: 1000))
    }


    // MARK: - Custom Templates
    func addCustomTemplate(_ template: ECardTemplate) {
        templates.append(template)
    }

    func removeTemplate(id: String) {
        templates.removeAll { $0.id == id }
    }
}

// MARK: - Environment Integration
private struct ECardTemplateServiceKey: EnvironmentKey {
    static let defaultValue = ECardTemplateService.shared
}

extension EnvironmentValues {
    var eCardTemplateService: ECardTemplateService {
        get { self[ECardTemplateServiceKey.self] }
        set { self[ECardTemplateServiceKey.self] = newValue }
    }
}
