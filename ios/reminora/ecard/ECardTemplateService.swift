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
        scene.backgroundColor = "#FFFFFF"  // Pure white background
        print("🎨 Scene background color set to: \(scene.backgroundColor)")
        
        // Polaroid styling: reduced margins
        let marginTop: CGFloat = size.height * 0.05    // 5% top margin
        let marginSides: CGFloat = size.width * 0.05   // 5% side margins  
        let marginBottom: CGFloat = size.height * 0.10 // 10% bottom margin
        
        // Create white background with paper noise filter using position-based transform
        let borderTransform = LayerTransform(
            position: CGPoint(x: 0, y: 0),
            size: size
        )
        
        var borderLayer = GeometryLayer(name: "White Background", transform: borderTransform)
        borderLayer.shape = .rectangle
        borderLayer.fillColor = "#FFFFFF"  // Pure white background
        borderLayer.strokeColor = nil // No stroke at all
        borderLayer.strokeWidth = 0
        borderLayer.cornerRadius = 0
        borderLayer.zOrder = 0
        borderLayer.filters = [] // Explicitly no filters
        scene.addLayer(borderLayer)
        
        print("🎨 Background layer: fillColor=\(borderLayer.fillColor ?? "nil"), strokeColor=\(borderLayer.strokeColor ?? "nil"), filters=\(borderLayer.filters.count)")
        
        // Create image layer with new margins using position-based transform
        let imageData = try await loadImageData(from: asset)
        let imageTransform = LayerTransform(
            position: CGPoint(x: marginSides, y: marginTop),
            size: CGSize(
                width: size.width - (marginSides * 2), 
                height: size.height - marginTop - marginBottom
            )
        )
        
        var imageLayer = ImageLayer(name: "Photo", transform: imageTransform)
        imageLayer.imageData = imageData
        imageLayer.contentMode = .scaleAspectFill
        imageLayer.zOrder = 10  // Higher z-order to ensure it's visible
        scene.addLayer(imageLayer)
        
        print("🖼️ Created image layer with data size: \(imageData.count) bytes, z-order: \(imageLayer.zOrder)")
        
        // Create text layer at bottom using top-left coordinates
        let imageBottom = marginTop + (size.height - marginTop - marginBottom)
        let textY = imageBottom + 20 // 20px below image
        let textTransform = LayerTransform(
            position: CGPoint(x: marginSides, y: textY),
            size: CGSize(width: size.width - (marginSides * 2), height: 60)
        )
        
        var textLayer = TextLayer(name: "Caption", transform: textTransform)
        textLayer.text = caption
        textLayer.fontSize = 36  // Increased font size
        textLayer.textColor = "#333333"
        textLayer.textAlignment = .center
        textLayer.zOrder = 20  // Ensure text is on top
        scene.addLayer(textLayer)
        
        print("📝 Created text layer with caption: '\(caption)', font size: \(textLayer.fontSize), z-order: \(textLayer.zOrder)")
        print("📝 Text position - textY: \(textY), marginBottom: \(marginBottom), scene height: \(size.height)")
        print("📝 Text layer position: \(textTransform.position), size: \(textTransform.size)")
        
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
