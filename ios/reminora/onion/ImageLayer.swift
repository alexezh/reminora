//
//  ImageLayer.swift
//  reminora
//
//  Created by alexezh on 8/18/25.
//


import Foundation
import UIKit
import CoreGraphics

struct ImageLayer: OnionLayer {
    let id: UUID
    var name: String
    var transform: LayerTransform
    var filters: [LayerFilter]
    var isVisible: Bool
    var zOrder: Int
    
    // Image-specific properties
    var imageData: Data? // JPEG/PNG data
    var contentMode: ContentMode
    
    let layerType: LayerType = .image
    
    enum ContentMode: String, Codable, CaseIterable {
        case scaleToFill = "scaleToFill"
        case scaleAspectFit = "scaleAspectFit"
        case scaleAspectFill = "scaleAspectFill"
        case center = "center"
        case top = "top"
        case bottom = "bottom"
        case left = "left"
        case right = "right"
        case topLeft = "topLeft"
        case topRight = "topRight"
        case bottomLeft = "bottomLeft"
        case bottomRight = "bottomRight"
        
        var displayName: String {
            switch self {
            case .scaleToFill: return "Scale to Fill"
            case .scaleAspectFit: return "Aspect Fit"
            case .scaleAspectFill: return "Aspect Fill"
            case .center: return "Center"
            case .top: return "Top"
            case .bottom: return "Bottom"
            case .left: return "Left"
            case .right: return "Right"
            case .topLeft: return "Top Left"
            case .topRight: return "Top Right"
            case .bottomLeft: return "Bottom Left"
            case .bottomRight: return "Bottom Right"
            }
        }
    }
    
    init(id: UUID = UUID(), name: String = "Image Layer", transform: LayerTransform = LayerTransform()) {
        self.id = id
        self.name = name
        self.transform = transform
        self.filters = []
        self.isVisible = true
        self.zOrder = 0
        self.contentMode = .scaleAspectFit
    }
    
    func render(in context: CGContext, bounds: CGRect) throws {
        guard isVisible, let imageData = imageData, let image = UIImage(data: imageData) else { return }
        
        context.saveGState()
        defer { context.restoreGState() }
        
        // Apply transform
        context.concatenate(transform.transformMatrix)
        
        // Apply opacity
        context.setAlpha(transform.opacity)
        
        // Calculate draw rect based on content mode
        let drawRect = calculateDrawRect(for: image.size, in: CGRect(origin: .zero, size: transform.size))
        
        // Apply filters to image if needed
        let filteredImage = applyFilters(to: image)
        
        // Draw the image
        if let cgImage = filteredImage.cgImage {
            context.draw(cgImage, in: drawRect)
        }
    }
    
    func naturalSize() -> CGSize {
        guard let imageData = imageData, let image = UIImage(data: imageData) else {
            return CGSize(width: 100, height: 100)
        }
        return image.size
    }
    
    func copy() -> ImageLayer {
        var copy = ImageLayer(
            id: UUID(),
            name: name,
            transform: transform
        )
        copy.filters = filters
        copy.isVisible = isVisible
        copy.zOrder = zOrder
        copy.imageData = imageData
        copy.contentMode = contentMode
        return copy
    }
    
    private func calculateDrawRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        switch contentMode {
        case .scaleToFill:
            return bounds
            
        case .scaleAspectFit:
            let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            return CGRect(
                x: bounds.midX - scaledSize.width / 2,
                y: bounds.midY - scaledSize.height / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )
            
        case .scaleAspectFill:
            let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            return CGRect(
                x: bounds.midX - scaledSize.width / 2,
                y: bounds.midY - scaledSize.height / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )
            
        case .center:
            return CGRect(
                x: bounds.midX - imageSize.width / 2,
                y: bounds.midY - imageSize.height / 2,
                width: imageSize.width,
                height: imageSize.height
            )
            
        case .top:
            return CGRect(
                x: bounds.midX - imageSize.width / 2,
                y: bounds.minY,
                width: imageSize.width,
                height: imageSize.height
            )
            
        case .bottom:
            return CGRect(
                x: bounds.midX - imageSize.width / 2,
                y: bounds.maxY - imageSize.height,
                width: imageSize.width,
                height: imageSize.height
            )
            
        case .left:
            return CGRect(
                x: bounds.minX,
                y: bounds.midY - imageSize.height / 2,
                width: imageSize.width,
                height: imageSize.height
            )
            
        case .right:
            return CGRect(
                x: bounds.maxX - imageSize.width,
                y: bounds.midY - imageSize.height / 2,
                width: imageSize.width,
                height: imageSize.height
            )
            
        case .topLeft:
            return CGRect(x: bounds.minX, y: bounds.minY, width: imageSize.width, height: imageSize.height)
            
        case .topRight:
            return CGRect(x: bounds.maxX - imageSize.width, y: bounds.minY, width: imageSize.width, height: imageSize.height)
            
        case .bottomLeft:
            return CGRect(x: bounds.minX, y: bounds.maxY - imageSize.height, width: imageSize.width, height: imageSize.height)
            
        case .bottomRight:
            return CGRect(x: bounds.maxX - imageSize.width, y: bounds.maxY - imageSize.height, width: imageSize.width, height: imageSize.height)
        }
    }
    
    private func applyFilters(to image: UIImage) -> UIImage {
        guard !filters.isEmpty else { return image }
        
        // For now, return the original image
        // Full filter implementation would require Core Image integration
        return image
    }
}