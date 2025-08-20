//
//  OnionTestScene.swift
//  reminora
//
//  Created by Claude on 8/18/25.
//

import Foundation
import UIKit
import CoreGraphics
import Photos

// MARK: - Onion Test Scene Factory

class OnionTestScene {
    
    /// Create a test scene that replicates the polaroid_classic template
    static func createPolaroidClassicTestScene() -> OnionScene {
        // Create scene with polaroid proportions (4:5 ratio like classic instant photos)
        let scene = OnionScene(
            name: "Polaroid Classic Test",
            size: CGSize(width: 400, height: 500)
        )
        scene.backgroundColor = "#FFFFFF"
        
        // 1. Add background layer with noise for natural look
        let backgroundLayer = createNoisyBackgroundLayer(size: scene.size)
        scene.addLayer(backgroundLayer)
        
        // 2. Add polaroid frame (white border with drop shadow)
        let frameLayer = createPolaroidFrameLayer(sceneSize: scene.size)
        scene.addLayer(frameLayer)
        
        // 3. Add photo area (placeholder image or actual photo)
        let photoLayer = createPhotoLayer(sceneSize: scene.size)
        scene.addLayer(photoLayer)
        
        // 4. Add vintage film overlay for authentic look
        let filmOverlay = createFilmOverlayLayer(sceneSize: scene.size)
        scene.addLayer(filmOverlay)
        
        // 5. Add text area at bottom (classic polaroid style)
        let textLayer = createPolaroidTextLayer(sceneSize: scene.size)
        scene.addLayer(textLayer)
        
        print("🧅 OnionTestScene: Created polaroid_classic test scene with \(scene.layerCount) layers")
        return scene
    }
    
    // MARK: - Layer Creation Methods
    
    /// Create a background layer with subtle noise for natural texture
    private static func createNoisyBackgroundLayer(size: CGSize) -> GeometryLayer {
        var backgroundLayer = GeometryLayer(
            id: UUID(),
            name: "Noisy Background",
            transform: LayerTransform(
                position: CGPoint.zero,
                size: size
            )
        )
        
        backgroundLayer.shape = .rectangle
        backgroundLayer.fillColor = "#F8F8F8" // Slightly off-white
        backgroundLayer.strokeColor = nil
        backgroundLayer.zOrder = 0
        
        // Add subtle noise filter for texture
        backgroundLayer.filters = [
            .brightness(amount: 0.05),
            .contrast(amount: 1.1)
        ]
        
        return backgroundLayer
    }
    
    /// Create the main polaroid frame with drop shadow
    private static func createPolaroidFrameLayer(sceneSize: CGSize) -> GeometryLayer {
        var frameLayer = GeometryLayer(
            id: UUID(),
            name: "Polaroid Frame",
            transform: LayerTransform(
                position: CGPoint(x: 20, y: 20),
                size: CGSize(width: sceneSize.width - 40, height: sceneSize.height - 40)
            )
        )
        
        frameLayer.shape = .rectangle
        frameLayer.fillColor = "#FFFFFF"
        frameLayer.strokeColor = "#E0E0E0"
        frameLayer.strokeWidth = 1
        frameLayer.cornerRadius = 8
        frameLayer.zOrder = 1
        
        // Add drop shadow for depth
        frameLayer.filters = [
            .shadow(
                offset: CGSize(width: 3, height: 5),
                blur: 8,
                color: "#00000020"
            )
        ]
        
        return frameLayer
    }
    
    /// Create the photo area with placeholder or actual image
    private static func createPhotoLayer(sceneSize: CGSize) -> ImageLayer {
        var photoLayer = ImageLayer(
            id: UUID(),
            name: "Main Photo",
            transform: LayerTransform(
                position: CGPoint(x: 40, y: 40),
                size: CGSize(width: sceneSize.width - 80, height: sceneSize.width - 80) // Square photo area
            )
        )
        
        // Create a placeholder gradient image
        photoLayer.imageData = createPlaceholderImageData(
            size: CGSize(width: 320, height: 320),
            colors: ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4"]
        )
        photoLayer.contentMode = .scaleAspectFill
        photoLayer.zOrder = 2
        
        // Add vintage photo filters
        photoLayer.filters = [
            .sepia(intensity: 0.3),
            .contrast(amount: 1.1),
            .brightness(amount: -0.05),
            .vintage
        ]
        
        return photoLayer
    }
    
    /// Create a subtle film overlay for vintage authenticity
    private static func createFilmOverlayLayer(sceneSize: CGSize) -> GeometryLayer {
        var overlayLayer = GeometryLayer(
            id: UUID(),
            name: "Film Overlay",
            transform: LayerTransform(
                position: CGPoint(x: 40, y: 40),
                size: CGSize(width: sceneSize.width - 80, height: sceneSize.width - 80)
            )
        )
        
        overlayLayer.shape = .rectangle
        overlayLayer.fillColor = "#FFFFEF" // Subtle warm tint
        overlayLayer.strokeColor = nil
        overlayLayer.zOrder = 3
        overlayLayer.transform.opacity = 0.1 // Very subtle
        
        overlayLayer.filters = [
            .warm,
            .brightness(amount: 0.02)
        ]
        
        return overlayLayer
    }
    
    /// Create the text area typical of polaroid photos
    private static func createPolaroidTextLayer(sceneSize: CGSize) -> TextLayer {
        var textLayer = TextLayer(
            id: UUID(),
            name: "Polaroid Caption",
            transform: LayerTransform(
                position: CGPoint(x: 50, y: sceneSize.width + 60),
                size: CGSize(width: sceneSize.width - 100, height: 80)
            )
        )
        
        textLayer.text = "Summer memories 📸"
        textLayer.fontName = "Helvetica"
        textLayer.fontSize = 18
        textLayer.textColor = "#333333"
        textLayer.textAlignment = .center
        textLayer.lineSpacing = 4
        textLayer.zOrder = 4
        
        // Add subtle text shadow for depth
        textLayer.filters = [
            .shadow(
                offset: CGSize(width: 1, height: 1),
                blur: 2,
                color: "#00000015"
            )
        ]
        
        return textLayer
    }
    
    // MARK: - Test Scene Variations
    
    /// Create a more complex test scene with multiple photos and text
    static func createAdvancedPolaroidScene() -> OnionScene {
        let scene = OnionScene(
            name: "Advanced Polaroid Test",
            size: CGSize(width: 600, height: 800)
        )
        scene.backgroundColor = "#F5F5F5"
        
        // Background with texture
        let backgroundLayer = createTexturedBackground(size: scene.size)
        scene.addLayer(backgroundLayer)
        
        // Multiple polaroid frames at different angles and positions
        for i in 0..<3 {
            let polaroid = createRotatedPolaroid(
                sceneSize: scene.size,
                index: i,
                totalCount: 3
            )
            scene.addLayer(polaroid)
        }
        
        // Title text at top
        let titleLayer = createTitleLayer(sceneSize: scene.size)
        scene.addLayer(titleLayer)
        
        print("🧅 OnionTestScene: Created advanced polaroid scene with \(scene.layerCount) layers")
        return scene
    }
    
    private static func createTexturedBackground(size: CGSize) -> GeometryLayer {
        var backgroundLayer = GeometryLayer(
            id: UUID(),
            name: "Textured Background",
            transform: LayerTransform(position: .zero, size: size)
        )
        
        backgroundLayer.shape = .rectangle
        backgroundLayer.fillColor = "#F8F8F8"
        backgroundLayer.strokeColor = nil
        backgroundLayer.zOrder = 0
        
        backgroundLayer.filters = [
            .brightness(amount: 0.1),
            .contrast(amount: 1.05),
            .warm
        ]
        
        return backgroundLayer
    }
    
    private static func createRotatedPolaroid(sceneSize: CGSize, index: Int, totalCount: Int) -> GroupLayer {
        var polaroidGroup = GroupLayer(
            id: UUID(),
            name: "Polaroid \(index + 1)",
            transform: LayerTransform(
                position: CGPoint(
                    x: 50 + CGFloat(index) * 120,
                    y: 100 + CGFloat(index) * 150
                ),
                size: CGSize(width: 200, height: 250)
            )
        )
        
        // Rotate each polaroid slightly for natural scatter effect
        let rotations: [CGFloat] = [-0.2, 0.15, -0.1]
        if index < rotations.count {
            polaroidGroup.transform.rotation = rotations[index]
        }
        
        polaroidGroup.zOrder = 10 + index
        
        // Add frame
        var frame = GeometryLayer(
            name: "Frame \(index + 1)",
            transform: LayerTransform(position: .zero, size: polaroidGroup.transform.size)
        )
        frame.shape = .rectangle
        frame.fillColor = "#FFFFFF"
        frame.strokeColor = "#E0E0E0"
        frame.strokeWidth = 1
        frame.cornerRadius = 6
        frame.filters = [
            .shadow(offset: CGSize(width: 2, height: 4), blur: 6, color: "#00000030")
        ]
        
        // Add photo
        var photo = ImageLayer(
            name: "Photo \(index + 1)",
            transform: LayerTransform(
                position: CGPoint(x: 15, y: 15),
                size: CGSize(width: 170, height: 170)
            )
        )
        photo.imageData = createPlaceholderImageData(
            size: CGSize(width: 170, height: 170),
            colors: [
                ["#FF9A9E", "#FECFEF"],
                ["#A8E6CF", "#DCEDC1"],
                ["#FFD54F", "#FFECB3"]
            ][index % 3]
        )
        photo.contentMode = .scaleAspectFill
        photo.filters = [
            .vintage,
            .sepia(intensity: 0.2),
            .contrast(amount: 1.1)
        ]
        
        // Add caption
        var caption = TextLayer(
            name: "Caption \(index + 1)",
            transform: LayerTransform(
                position: CGPoint(x: 20, y: 200),
                size: CGSize(width: 160, height: 30)
            )
        )
        caption.text = ["Vacation", "Friends", "Adventure"][index % 3]
        caption.fontName = "Helvetica"
        caption.fontSize = 14
        caption.textColor = "#555555"
        caption.textAlignment = .center
        
        polaroidGroup.addChild(AnyOnionLayer(frame))
        polaroidGroup.addChild(AnyOnionLayer(photo))
        polaroidGroup.addChild(AnyOnionLayer(caption))
        
        return polaroidGroup
    }
    
    private static func createTitleLayer(sceneSize: CGSize) -> TextLayer {
        var titleLayer = TextLayer(
            id: UUID(),
            name: "Scene Title",
            transform: LayerTransform(
                position: CGPoint(x: 50, y: 30),
                size: CGSize(width: sceneSize.width - 100, height: 50)
            )
        )
        
        titleLayer.text = "My Photo Collection"
        titleLayer.fontName = "Helvetica-Bold"
        titleLayer.fontSize = 28
        titleLayer.textColor = "#2C3E50"
        titleLayer.textAlignment = .center
        titleLayer.zOrder = 100
        
        titleLayer.filters = [
            .shadow(
                offset: CGSize(width: 2, height: 2),
                blur: 4,
                color: "#00000020"
            )
        ]
        
        return titleLayer
    }
    
    // MARK: - Utility Methods
    
    /// Create placeholder image data for testing
    private static func createPlaceholderImageData(size: CGSize, colors: [String]) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            
            // Create gradient background
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let cgColors = colors.compactMap { UIColor(hex: $0)?.cgColor }
            
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors as CFArray, locations: nil) {
                cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint.zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            } else {
                // Fallback to solid color
                cgContext.setFillColor(UIColor(hex: colors.first ?? "#CCCCCC")?.cgColor ?? UIColor.gray.cgColor)
                cgContext.fill(CGRect(origin: .zero, size: size))
            }
            
            // Add some geometric shapes for visual interest
            cgContext.setFillColor(UIColor.white.withAlphaComponent(0.3).cgColor)
            cgContext.fillEllipse(in: CGRect(x: size.width * 0.2, y: size.height * 0.3, width: size.width * 0.6, height: size.height * 0.4))
            
            cgContext.setFillColor(UIColor.white.withAlphaComponent(0.2).cgColor)
            cgContext.fillEllipse(in: CGRect(x: size.width * 0.1, y: size.height * 0.1, width: size.width * 0.3, height: size.height * 0.3))
        }
        
        return image.jpegData(compressionQuality: 0.8)
    }
    
    /// Create a test scene from actual photo assets
    static func createPolaroidSceneWithAssets(_ assets: [RPhotoStack]) -> OnionScene {
        let scene = OnionScene(
            name: "Polaroid from Photos",
            size: CGSize(width: 400, height: 500)
        )
        scene.backgroundColor = "#FFFFFF"
        
        // Add background
        let backgroundLayer = createNoisyBackgroundLayer(size: scene.size)
        scene.addLayer(backgroundLayer)
        
        // Add frame
        let frameLayer = createPolaroidFrameLayer(sceneSize: scene.size)
        scene.addLayer(frameLayer)
        
        // Add actual photo if available
        if let firstAsset = assets.first {
            let photoLayer = createPhotoLayerFromAsset(firstAsset, sceneSize: scene.size)
            scene.addLayer(photoLayer)
        } else {
            // Fallback to placeholder
            let photoLayer = createPhotoLayer(sceneSize: scene.size)
            scene.addLayer(photoLayer)
        }
        
        // Add film overlay
        let filmOverlay = createFilmOverlayLayer(sceneSize: scene.size)
        scene.addLayer(filmOverlay)
        
        // Add date text (from photo metadata if available)
        let textLayer = createDateTextLayer(from: assets.first, sceneSize: scene.size)
        scene.addLayer(textLayer)
        
        print("🧅 OnionTestScene: Created polaroid scene with real photos")
        return scene
    }
    
    private static func createPhotoLayerFromAsset(_ stack: RPhotoStack, sceneSize: CGSize) -> ImageLayer {
        var photoLayer = ImageLayer(
            id: UUID(),
            name: "Photo from Asset",
            transform: LayerTransform(
                position: CGPoint(x: 40, y: 40),
                size: CGSize(width: sceneSize.width - 80, height: sceneSize.width - 80)
            )
        )
        
        // Load image data from PHAsset
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = true
        
        imageManager.requestImage(
            for: stack.primaryAsset,
            targetSize: CGSize(width: 800, height: 800),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                photoLayer.imageData = image.jpegData(compressionQuality: 0.9)
            }
        }
        
        photoLayer.contentMode = .scaleAspectFill
        photoLayer.zOrder = 2
        
        // Apply vintage filters
        photoLayer.filters = [
            .sepia(intensity: 0.3),
            .contrast(amount: 1.1),
            .brightness(amount: -0.05),
            .vintage
        ]
        
        return photoLayer
    }
    
    private static func createDateTextLayer(from stack: RPhotoStack?, sceneSize: CGSize) -> TextLayer {
        var textLayer = TextLayer(
            id: UUID(),
            name: "Photo Date",
            transform: LayerTransform(
                position: CGPoint(x: 50, y: sceneSize.width + 60),
                size: CGSize(width: sceneSize.width - 100, height: 80)
            )
        )
        
        // Extract date from photo metadata
        if let stack = stack,
           let creationDate = stack.primaryAsset.creationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            textLayer.text = formatter.string(from: creationDate)
        } else {
            textLayer.text = "Summer 2025"
        }
        
        textLayer.fontName = "Helvetica"
        textLayer.fontSize = 16
        textLayer.textColor = "#555555"
        textLayer.textAlignment = .center
        textLayer.zOrder = 4
        
        return textLayer
    }
}

// MARK: - Test Scene Rendering

extension OnionTestScene {
    
    /// Render test scene and return UIImage
    static func renderTestScene(_ scene: OnionScene, quality: OnionRenderConfig.RenderQuality = .standard) async throws -> UIImage {
        let renderer = OnionRenderer.shared
        let config = OnionRenderConfig(scene: scene, quality: quality)
        let result = try await renderer.render(scene: scene, config: config)
        
        print("🧅 OnionTestScene: Rendered scene '\(scene.name)' in \(String(format: "%.2f", result.renderTime))s")
        print("🧅 Statistics: \(result.statistics.visibleLayers) visible layers, \(result.statistics.skippedLayers) skipped")
        
        return result.image
    }
    
    /// Create and render a quick test scene
    static func createAndRenderQuickTest() async throws -> UIImage {
        let scene = createPolaroidClassicTestScene()
        return try await renderTestScene(scene, quality: .high)
    }
}