//
//  OnionScene.swift
//  reminora
//
//  Created by Claude on 8/17/25.
//

import Foundation
import UIKit
import CoreGraphics

// MARK: - Scene Composition System

class OnionScene: ObservableObject, Codable {
    @Published var id: UUID
    @Published var name: String
    @Published var size: CGSize
    @Published var backgroundColor: String // hex color
    @Published var layers: [AnyOnionLayer]
    @Published var createdAt: Date
    @Published var modifiedAt: Date
    
    // Metadata
    var version: Int = 1
    var metadata: [String: String] = [:]
    
    // Current selection state (not persisted)
    @Published var selectedLayerIds: Set<UUID> = []
    
    private enum CodingKeys: String, CodingKey {
        case id, name, size, backgroundColor, layers, createdAt, modifiedAt, version, metadata
    }
    
    init(id: UUID = UUID(), name: String = "New Scene", size: CGSize = CGSize(width: 800, height: 600)) {
        self.id = id
        self.name = name
        self.size = size
        self.backgroundColor = "#FFFFFF"
        self.layers = []
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    // MARK: - Codable Implementation
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        size = try container.decode(CGSize.self, forKey: .size)
        backgroundColor = try container.decode(String.self, forKey: .backgroundColor)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
        
        // Decode layers (this requires custom handling due to type erasure)
        layers = try container.decode([AnyOnionLayer].self, forKey: .layers)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(size, forKey: .size)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(layers, forKey: .layers)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encode(version, forKey: .version)
        try container.encode(metadata, forKey: .metadata)
    }
    
    // MARK: - Layer Management
    
    func addLayer<T: OnionLayer>(_ layer: T) {
        DispatchQueue.main.async {
            let anyLayer = AnyOnionLayer(layer)
            self.layers.append(anyLayer)
            self.markAsModified()
            print("🧅 OnionScene: Added layer '\(layer.name)' (type: \(layer.layerType.displayName))")
        }
    }
    
    func removeLayer(withId id: UUID) {
        DispatchQueue.main.async {
            if let index = self.layers.firstIndex(where: { $0.id == id }) {
                let layer = self.layers.remove(at: index)
                self.selectedLayerIds.remove(id)
                self.markAsModified()
                print("🧅 OnionScene: Removed layer '\(layer.name)'")
            }
        }
    }
    
    func removeSelectedLayers() {
        DispatchQueue.main.async {
            let selectedIds = self.selectedLayerIds
            self.layers.removeAll { selectedIds.contains($0.id) }
            self.selectedLayerIds.removeAll()
            self.markAsModified()
            print("🧅 OnionScene: Removed \(selectedIds.count) selected layers")
        }
    }
    
    func duplicateLayer(withId id: UUID) {
        DispatchQueue.main.async {
            guard let index = self.layers.firstIndex(where: { $0.id == id }) else { return }
            
            let originalLayer = self.layers[index]
            var duplicatedLayer = originalLayer.copy()
            
            // Offset position slightly
            duplicatedLayer.transform.position.x += 20
            duplicatedLayer.transform.position.y += 20
            duplicatedLayer.name += " Copy"
            
            self.layers.insert(duplicatedLayer, at: index + 1)
            self.markAsModified()
            print("🧅 OnionScene: Duplicated layer '\(originalLayer.name)'")
        }
    }
    
    func moveLayer(fromIndex: Int, toIndex: Int) {
        DispatchQueue.main.async {
            guard fromIndex < self.layers.count && toIndex < self.layers.count else { return }
            
            let layer = self.layers.remove(at: fromIndex)
            self.layers.insert(layer, at: toIndex)
            self.markAsModified()
            print("🧅 OnionScene: Moved layer from index \(fromIndex) to \(toIndex)")
        }
    }
    
    func moveLayerToFront(withId id: UUID) {
        DispatchQueue.main.async {
            guard let index = self.layers.firstIndex(where: { $0.id == id }) else { return }
            let layer = self.layers.remove(at: index)
            self.layers.append(layer)
            self.markAsModified()
            print("🧅 OnionScene: Moved layer '\(layer.name)' to front")
        }
    }
    
    func moveLayerToBack(withId id: UUID) {
        DispatchQueue.main.async {
            guard let index = self.layers.firstIndex(where: { $0.id == id }) else { return }
            let layer = self.layers.remove(at: index)
            self.layers.insert(layer, at: 0)
            self.markAsModified()
            print("🧅 OnionScene: Moved layer '\(layer.name)' to back")
        }
    }
    
    func reorderLayersByZOrder() {
        DispatchQueue.main.async {
            self.layers.sort { $0.zOrder < $1.zOrder }
            self.markAsModified()
            print("🧅 OnionScene: Reordered layers by z-order")
        }
    }
    
    // MARK: - Selection Management
    
    func selectLayer(withId id: UUID, addToSelection: Bool = false) {
        DispatchQueue.main.async {
            if addToSelection {
                self.selectedLayerIds.insert(id)
            } else {
                self.selectedLayerIds = [id]
            }
            print("🧅 OnionScene: Selected layer(s), total selected: \(self.selectedLayerIds.count)")
        }
    }
    
    func deselectLayer(withId id: UUID) {
        DispatchQueue.main.async {
            self.selectedLayerIds.remove(id)
            print("🧅 OnionScene: Deselected layer, total selected: \(self.selectedLayerIds.count)")
        }
    }
    
    func deselectAllLayers() {
        DispatchQueue.main.async {
            self.selectedLayerIds.removeAll()
            print("🧅 OnionScene: Deselected all layers")
        }
    }
    
    func selectAllLayers() {
        DispatchQueue.main.async {
            self.selectedLayerIds = Set(self.layers.map { $0.id })
            print("🧅 OnionScene: Selected all \(self.layers.count) layers")
        }
    }
    
    var selectedLayers: [AnyOnionLayer] {
        return layers.filter { selectedLayerIds.contains($0.id) }
    }
    
    // MARK: - Layer Queries
    
    func getLayer(withId id: UUID) -> AnyOnionLayer? {
        return layers.first { $0.id == id }
    }
    
    func getLayers(ofType type: LayerType) -> [AnyOnionLayer] {
        return layers.filter { $0.layerType == type }
    }
    
    func getLayersInBounds(_ bounds: CGRect) -> [AnyOnionLayer] {
        return layers.filter { layer in
            let layerBounds = layer.transform.transformedBounds
            return bounds.intersects(layerBounds)
        }
    }
    
    func getTopLayerAt(point: CGPoint) -> AnyOnionLayer? {
        // Check layers from top to bottom (reverse order)
        for layer in layers.reversed() {
            guard layer.isVisible else { continue }
            
            let layerBounds = layer.transform.transformedBounds
            if layerBounds.contains(point) {
                return layer
            }
        }
        return nil
    }
    
    // MARK: - Layer Transformations
    
    func updateLayerTransform(id: UUID, transform: LayerTransform) {
        DispatchQueue.main.async {
            if let index = self.layers.firstIndex(where: { $0.id == id }) {
                self.layers[index].transform = transform
                self.markAsModified()
            }
        }
    }
    
    func translateSelectedLayers(by offset: CGPoint) {
        DispatchQueue.main.async {
            for i in 0..<self.layers.count {
                if self.selectedLayerIds.contains(self.layers[i].id) {
                    self.layers[i].transform.position.x += offset.x
                    self.layers[i].transform.position.y += offset.y
                }
            }
            if !self.selectedLayerIds.isEmpty {
                self.markAsModified()
            }
        }
    }
    
    func scaleSelectedLayers(by factor: CGFloat, aroundPoint: CGPoint? = nil) {
        DispatchQueue.main.async {
            let center = aroundPoint ?? self.getSelectionCenter()
            
            for i in 0..<self.layers.count {
                if self.selectedLayerIds.contains(self.layers[i].id) {
                    let layer = self.layers[i]
                    
                    // Scale size
                    self.layers[i].transform.size.width *= factor
                    self.layers[i].transform.size.height *= factor
                    
                    // Adjust position to scale around center point
                    let dx = layer.transform.position.x - center.x
                    let dy = layer.transform.position.y - center.y
                    self.layers[i].transform.position.x = center.x + dx * factor
                    self.layers[i].transform.position.y = center.y + dy * factor
                }
            }
            if !self.selectedLayerIds.isEmpty {
                self.markAsModified()
            }
        }
    }
    
    func rotateSelectedLayers(by angle: CGFloat, aroundPoint: CGPoint? = nil) {
        DispatchQueue.main.async {
            let center = aroundPoint ?? self.getSelectionCenter()
            
            for i in 0..<self.layers.count {
                if self.selectedLayerIds.contains(self.layers[i].id) {
                    let layer = self.layers[i]
                    
                    // Rotate the layer
                    self.layers[i].transform.rotation += angle
                    
                    // Rotate position around center point
                    let dx = layer.transform.position.x - center.x
                    let dy = layer.transform.position.y - center.y
                    let rotatedX = dx * cos(angle) - dy * sin(angle)
                    let rotatedY = dx * sin(angle) + dy * cos(angle)
                    self.layers[i].transform.position.x = center.x + rotatedX
                    self.layers[i].transform.position.y = center.y + rotatedY
                }
            }
            if !self.selectedLayerIds.isEmpty {
                self.markAsModified()
            }
        }
    }
    
    // MARK: - Scene Bounds and Layout
    
    func getSceneBounds() -> CGRect {
        return CGRect(origin: .zero, size: size)
    }
    
    func getContentBounds() -> CGRect {
        guard !layers.isEmpty else { return getSceneBounds() }
        
        var minX: CGFloat = .greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude
        
        for layer in layers where layer.isVisible {
            let bounds = layer.transform.transformedBounds
            minX = min(minX, bounds.minX)
            minY = min(minY, bounds.minY)
            maxX = max(maxX, bounds.maxX)
            maxY = max(maxY, bounds.maxY)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    func getSelectionBounds() -> CGRect? {
        let selectedLayerObjects = selectedLayers
        guard !selectedLayerObjects.isEmpty else { return nil }
        
        var minX: CGFloat = .greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude
        
        for layer in selectedLayerObjects {
            let bounds = layer.transform.transformedBounds
            minX = min(minX, bounds.minX)
            minY = min(minY, bounds.minY)
            maxX = max(maxX, bounds.maxX)
            maxY = max(maxY, bounds.maxY)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    func getSelectionCenter() -> CGPoint {
        guard let bounds = getSelectionBounds() else { return CGPoint(x: size.width / 2, y: size.height / 2) }
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    // MARK: - Layer Alignment
    
    func alignSelectedLayers(_ alignment: LayerAlignment) {
        DispatchQueue.main.async {
            guard let selectionBounds = self.getSelectionBounds() else { return }
            
            for i in 0..<self.layers.count {
                if self.selectedLayerIds.contains(self.layers[i].id) {
                    let layer = self.layers[i]
                    let layerBounds = layer.transform.transformedBounds
                    
                    switch alignment {
                    case .left:
                        self.layers[i].transform.position.x = selectionBounds.minX
                    case .right:
                        self.layers[i].transform.position.x = selectionBounds.maxX - layerBounds.width
                    case .top:
                        self.layers[i].transform.position.y = selectionBounds.minY
                    case .bottom:
                        self.layers[i].transform.position.y = selectionBounds.maxY - layerBounds.height
                    case .centerHorizontal:
                        self.layers[i].transform.position.x = selectionBounds.midX - layerBounds.width / 2
                    case .centerVertical:
                        self.layers[i].transform.position.y = selectionBounds.midY - layerBounds.height / 2
                    case .center:
                        self.layers[i].transform.position.x = selectionBounds.midX - layerBounds.width / 2
                        self.layers[i].transform.position.y = selectionBounds.midY - layerBounds.height / 2
                    }
                }
            }
            self.markAsModified()
            print("🧅 OnionScene: Aligned \(self.selectedLayerIds.count) layers: \(alignment)")
        }
    }
    
    // MARK: - Utility
    
    private func markAsModified() {
        modifiedAt = Date()
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.layers.removeAll()
            self.selectedLayerIds.removeAll()
            self.markAsModified()
            print("🧅 OnionScene: Cleared scene '\(self.name)'")
        }
    }
    
    func copy() -> OnionScene {
        let copy = OnionScene(name: name + " Copy", size: size)
        copy.backgroundColor = backgroundColor
        copy.layers = layers.map { $0.copy() }
        copy.metadata = metadata
        return copy
    }
    
    // MARK: - Statistics
    
    var layerCount: Int { layers.count }
    var selectedLayerCount: Int { selectedLayerIds.count }
    var visibleLayerCount: Int { layers.filter { $0.isVisible }.count }
    
    func getLayerCounts() -> [LayerType: Int] {
        var counts: [LayerType: Int] = [:]
        for type in LayerType.allCases {
            counts[type] = layers.filter { $0.layerType == type }.count
        }
        return counts
    }
}

// MARK: - Layer Alignment Enum

enum LayerAlignment: String, CaseIterable {
    case left = "left"
    case right = "right"
    case top = "top"
    case bottom = "bottom"
    case centerHorizontal = "centerHorizontal"
    case centerVertical = "centerVertical"
    case center = "center"
    
    var displayName: String {
        switch self {
        case .left: return "Align Left"
        case .right: return "Align Right"
        case .top: return "Align Top"
        case .bottom: return "Align Bottom"
        case .centerHorizontal: return "Center Horizontally"
        case .centerVertical: return "Center Vertically"
        case .center: return "Center"
        }
    }
    
    var systemImage: String {
        switch self {
        case .left: return "align.horizontal.left"
        case .right: return "align.horizontal.right"
        case .top: return "align.vertical.top"
        case .bottom: return "align.vertical.bottom"
        case .centerHorizontal: return "align.horizontal.center"
        case .centerVertical: return "align.vertical.center"
        case .center: return "align.horizontal.center.fill"
        }
    }
}