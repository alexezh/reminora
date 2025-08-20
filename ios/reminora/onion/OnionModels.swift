//
//  OnionModels.swift
//  reminora
//
//  Created by Claude on 8/17/25.
//

import Foundation
import UIKit
import CoreGraphics

// MARK: - Layer Transform

struct LayerTransform: Codable, Equatable {
    var position: CGPoint = .zero
    var size: CGSize = CGSize(width: 100, height: 100)
    var rotation: CGFloat = 0 // in radians
    var scale: CGFloat = 1.0
    var opacity: CGFloat = 1.0
    var anchorPoint: CGPoint = CGPoint(x: 0.5, y: 0.5) // normalized (0-1)
    
    init(position: CGPoint = .zero, size: CGSize = CGSize(width: 100, height: 100)) {
        self.position = position
        self.size = size
    }
    
    /// Calculate the transformation matrix for this layer
    var transformMatrix: CGAffineTransform {
        var transform = CGAffineTransform.identity
        
        // Apply scale
        transform = transform.scaledBy(x: scale, y: scale)
        
        // Apply rotation around anchor point
        let anchorX = size.width * anchorPoint.x
        let anchorY = size.height * anchorPoint.y
        
        transform = transform.translatedBy(x: -anchorX, y: -anchorY)
        transform = transform.rotated(by: rotation)
        transform = transform.translatedBy(x: anchorX, y: anchorY)
        
        // Apply position
        transform = transform.translatedBy(x: position.x, y: position.y)
        
        return transform
    }
    
    /// Calculate the bounding rect after transformation
    var transformedBounds: CGRect {
        let rect = CGRect(origin: .zero, size: size)
        return rect.applying(transformMatrix)
    }
}

// MARK: - Layer Filter

enum LayerFilter: Codable, Equatable, CaseIterable {
    case none
    case blur(radius: CGFloat)
    case brightness(amount: CGFloat) // -1.0 to 1.0
    case contrast(amount: CGFloat)   // 0.0 to 2.0
    case saturation(amount: CGFloat) // 0.0 to 2.0
    case sepia(intensity: CGFloat)   // 0.0 to 1.0
    case blackAndWhite
    case vintage
    case warm
    case cool
    case shadow(offset: CGSize, blur: CGFloat, color: String) // color as hex string
    
    static var allCases: [LayerFilter] {
        return [
            .none,
            .blur(radius: 5.0),
            .brightness(amount: 0.2),
            .contrast(amount: 1.2),
            .saturation(amount: 1.3),
            .sepia(intensity: 0.8),
            .blackAndWhite,
            .vintage,
            .warm,
            .cool,
            .shadow(offset: CGSize(width: 2, height: 2), blur: 4, color: "#000000")
        ]
    }
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .blur: return "Blur"
        case .brightness: return "Brightness"
        case .contrast: return "Contrast"
        case .saturation: return "Saturation"
        case .sepia: return "Sepia"
        case .blackAndWhite: return "Black & White"
        case .vintage: return "Vintage"
        case .warm: return "Warm"
        case .cool: return "Cool"
        case .shadow: return "Shadow"
        }
    }
}

// MARK: - Base Layer Protocol

protocol OnionLayer: Codable, Identifiable, Equatable {
    var id: UUID { get }
    var name: String { get set }
    var transform: LayerTransform { get set }
    var filters: [LayerFilter] { get set }
    var isVisible: Bool { get set }
    var zOrder: Int { get set }
    var layerType: LayerType { get }
    
    /// Render this layer to a CGContext with the given bounds
    func render(in context: CGContext, bounds: CGRect) throws
    
    /// Get the natural size of this layer content
    func naturalSize() -> CGSize
    
    /// Create a copy of this layer
    func copy() -> Self
}

// MARK: - Layer Type Enum

enum LayerType: String, Codable, CaseIterable {
    case image = "image"
    case text = "text"
    case geometry = "geometry"
    case group = "group"
    
    var displayName: String {
        switch self {
        case .image: return "Image"
        case .text: return "Text"
        case .geometry: return "Shape"
        case .group: return "Group"
        }
    }
}

// MARK: - Type-Erased Layer Wrapper


