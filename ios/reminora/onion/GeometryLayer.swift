//
//  GeometryLayer.swift
//  reminora
//
//  Created by alexezh on 8/18/25.
//


import Foundation
import UIKit
import CoreGraphics

struct GeometryLayer: OnionLayer {
    let id: UUID
    var name: String
    var transform: LayerTransform
    var filters: [LayerFilter]
    var isVisible: Bool
    var zOrder: Int
    
    // Geometry-specific properties
    var shape: GeometryShape
    var fillColor: String? // hex color string, nil for no fill
    var strokeColor: String? // hex color string, nil for no stroke
    var strokeWidth: CGFloat
    var cornerRadius: CGFloat // for rectangles
    
    let layerType: LayerType = .geometry
    
    enum GeometryShape: String, Codable, CaseIterable {
        case rectangle = "rectangle"
        case circle = "circle"
        case ellipse = "ellipse"
        case triangle = "triangle"
        case star = "star"
        case polygon = "polygon"
        
        var displayName: String {
            switch self {
            case .rectangle: return "Rectangle"
            case .circle: return "Circle"
            case .ellipse: return "Ellipse"
            case .triangle: return "Triangle"
            case .star: return "Star"
            case .polygon: return "Polygon"
            }
        }
    }
    
    init(id: UUID = UUID(), name: String = "Shape Layer", transform: LayerTransform = LayerTransform()) {
        self.id = id
        self.name = name
        self.transform = transform
        self.filters = []
        self.isVisible = true
        self.zOrder = 0
        self.shape = .rectangle
        self.fillColor = "#FF0000"
        self.strokeColor = nil
        self.strokeWidth = 1.0
        self.cornerRadius = 0
    }
    
    func render(in context: CGContext, bounds: CGRect) throws {
        guard isVisible else { return }
        
        context.saveGState()
        defer { context.restoreGState() }
        
        // Apply transform
        context.concatenate(transform.transformMatrix)
        
        // Apply opacity
        context.setAlpha(transform.opacity)
        
        // Create path based on shape
        let path = createPath()
        
        // Set fill color
        if let fillColorHex = fillColor, let fillColor = UIColor(hex: fillColorHex) {
            context.setFillColor(fillColor.cgColor)
            context.addPath(path)
            context.fillPath()
        }
        
        // Set stroke color
        if let strokeColorHex = strokeColor, let strokeColor = UIColor(hex: strokeColorHex) {
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(strokeWidth)
            context.addPath(path)
            context.strokePath()
        }
    }
    
    func naturalSize() -> CGSize {
        return transform.size
    }
    
    func copy() -> GeometryLayer {
        var copy = GeometryLayer(
            id: UUID(),
            name: name,
            transform: transform
        )
        copy.filters = filters
        copy.isVisible = isVisible
        copy.zOrder = zOrder
        copy.shape = shape
        copy.fillColor = fillColor
        copy.strokeColor = strokeColor
        copy.strokeWidth = strokeWidth
        copy.cornerRadius = cornerRadius
        return copy
    }
    
    private func createPath() -> CGPath {
        let bounds = CGRect(origin: .zero, size: transform.size)
        
        switch shape {
        case .rectangle:
            if cornerRadius > 0 {
                return CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            } else {
                return CGPath(rect: bounds, transform: nil)
            }
            
        case .circle:
            let radius = min(bounds.width, bounds.height) / 2
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            return CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), transform: nil)
            
        case .ellipse:
            return CGPath(ellipseIn: bounds, transform: nil)
            
        case .triangle:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
            path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
            path.closeSubpath()
            return path
            
        case .star:
            return createStarPath(in: bounds)
            
        case .polygon:
            return createPolygonPath(in: bounds, sides: 6)
        }
    }
    
    private func createStarPath(in bounds: CGRect) -> CGPath {
        let path = CGMutablePath()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let outerRadius = min(bounds.width, bounds.height) / 2
        let innerRadius = outerRadius * 0.4
        let points = 5
        
        for i in 0..<points * 2 {
            let angle = CGFloat(i) * .pi / CGFloat(points)
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + cos(angle - .pi / 2) * radius
            let y = center.y + sin(angle - .pi / 2) * radius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
    
    private func createPolygonPath(in bounds: CGRect, sides: Int) -> CGPath {
        let path = CGMutablePath()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2
        
        for i in 0..<sides {
            let angle = CGFloat(i) * 2 * .pi / CGFloat(sides)
            let x = center.x + cos(angle - .pi / 2) * radius
            let y = center.y + sin(angle - .pi / 2) * radius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}