//
//  GroupLayer.swift
//  reminora
//
//  Created by alexezh on 8/18/25.
//


import Foundation
import UIKit
import CoreGraphics

struct GroupLayer: OnionLayer {
    let id: UUID
    var name: String
    var transform: LayerTransform
    var filters: [LayerFilter]
    var isVisible: Bool
    var zOrder: Int
    
    // Group-specific properties
    var childLayers: [AnyOnionLayer]
    var clipsContent: Bool // whether to clip children to group bounds
    
    let layerType: LayerType = .group
    
    init(id: UUID = UUID(), name: String = "Group Layer", transform: LayerTransform = LayerTransform()) {
        self.id = id
        self.name = name
        self.transform = transform
        self.filters = []
        self.isVisible = true
        self.zOrder = 0
        self.childLayers = []
        self.clipsContent = false
    }
    
    func render(in context: CGContext, bounds: CGRect) throws {
        guard isVisible else { return }
        
        context.saveGState()
        defer { context.restoreGState() }
        
        // Apply transform
        context.concatenate(transform.transformMatrix)
        
        // Apply opacity
        context.setAlpha(transform.opacity)
        
        // Set clipping if enabled
        if clipsContent {
            context.clip(to: CGRect(origin: .zero, size: transform.size))
        }
        
        // Render child layers in z-order
        let sortedChildren = childLayers.sorted { $0.zOrder < $1.zOrder }
        for child in sortedChildren {
            try child.render(in: context, bounds: CGRect(origin: .zero, size: transform.size))
        }
    }
    
    func naturalSize() -> CGSize {
        guard !childLayers.isEmpty else { return CGSize(width: 100, height: 100) }
        
        // Calculate bounding rect of all child layers
        var minX: CGFloat = .greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude
        
        for child in childLayers {
            let bounds = child.transform.transformedBounds
            minX = min(minX, bounds.minX)
            minY = min(minY, bounds.minY)
            maxX = max(maxX, bounds.maxX)
            maxY = max(maxY, bounds.maxY)
        }
        
        return CGSize(width: maxX - minX, height: maxY - minY)
    }
    
    func copy() -> GroupLayer {
        var copy = GroupLayer(
            id: UUID(),
            name: name,
            transform: transform
        )
        copy.filters = filters
        copy.isVisible = isVisible
        copy.zOrder = zOrder
        copy.childLayers = childLayers.map { $0.copy() }
        copy.clipsContent = clipsContent
        return copy
    }
    
    mutating func addChild(_ layer: AnyOnionLayer) {
        childLayers.append(layer)
    }
    
    mutating func removeChild(withId id: UUID) {
        childLayers.removeAll { $0.id == id }
    }
    
    mutating func moveChild(fromIndex: Int, toIndex: Int) {
        guard fromIndex < childLayers.count && toIndex < childLayers.count else { return }
        let child = childLayers.remove(at: fromIndex)
        childLayers.insert(child, at: toIndex)
    }
}