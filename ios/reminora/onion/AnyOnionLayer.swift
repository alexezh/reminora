//
//  AnyOnionLayer.swift
//  reminora
//
//  Created by alexezh on 8/18/25.
//


import Foundation
import UIKit
import CoreGraphics

enum AnyOnionLayer: OnionLayer, Codable {
    case image(ImageLayer)
    case text(TextLayer)
    case geometry(GeometryLayer)
    case group(GroupLayer)
    
    init<T: OnionLayer>(_ layer: T) {
        switch layer.layerType {
        case .image:
            self = .image(layer as! ImageLayer)
        case .text:
            self = .text(layer as! TextLayer)
        case .geometry:
            self = .geometry(layer as! GeometryLayer)
        case .group:
            self = .group(layer as! GroupLayer)
        }
    }
    
    var id: UUID {
        switch self {
        case .image(let layer): return layer.id
        case .text(let layer): return layer.id
        case .geometry(let layer): return layer.id
        case .group(let layer): return layer.id
        }
    }
    
    var name: String {
        get {
            switch self {
            case .image(let layer): return layer.name
            case .text(let layer): return layer.name
            case .geometry(let layer): return layer.name
            case .group(let layer): return layer.name
            }
        }
        set {
            switch self {
            case .image(var layer):
                layer.name = newValue
                self = .image(layer)
            case .text(var layer):
                layer.name = newValue
                self = .text(layer)
            case .geometry(var layer):
                layer.name = newValue
                self = .geometry(layer)
            case .group(var layer):
                layer.name = newValue
                self = .group(layer)
            }
        }
    }
    
    var transform: LayerTransform {
        get {
            switch self {
            case .image(let layer): return layer.transform
            case .text(let layer): return layer.transform
            case .geometry(let layer): return layer.transform
            case .group(let layer): return layer.transform
            }
        }
        set {
            switch self {
            case .image(var layer):
                layer.transform = newValue
                self = .image(layer)
            case .text(var layer):
                layer.transform = newValue
                self = .text(layer)
            case .geometry(var layer):
                layer.transform = newValue
                self = .geometry(layer)
            case .group(var layer):
                layer.transform = newValue
                self = .group(layer)
            }
        }
    }
    
    var filters: [LayerFilter] {
        get {
            switch self {
            case .image(let layer): return layer.filters
            case .text(let layer): return layer.filters
            case .geometry(let layer): return layer.filters
            case .group(let layer): return layer.filters
            }
        }
        set {
            switch self {
            case .image(var layer):
                layer.filters = newValue
                self = .image(layer)
            case .text(var layer):
                layer.filters = newValue
                self = .text(layer)
            case .geometry(var layer):
                layer.filters = newValue
                self = .geometry(layer)
            case .group(var layer):
                layer.filters = newValue
                self = .group(layer)
            }
        }
    }
    
    var isVisible: Bool {
        get {
            switch self {
            case .image(let layer): return layer.isVisible
            case .text(let layer): return layer.isVisible
            case .geometry(let layer): return layer.isVisible
            case .group(let layer): return layer.isVisible
            }
        }
        set {
            switch self {
            case .image(var layer):
                layer.isVisible = newValue
                self = .image(layer)
            case .text(var layer):
                layer.isVisible = newValue
                self = .text(layer)
            case .geometry(var layer):
                layer.isVisible = newValue
                self = .geometry(layer)
            case .group(var layer):
                layer.isVisible = newValue
                self = .group(layer)
            }
        }
    }
    
    var zOrder: Int {
        get {
            switch self {
            case .image(let layer): return layer.zOrder
            case .text(let layer): return layer.zOrder
            case .geometry(let layer): return layer.zOrder
            case .group(let layer): return layer.zOrder
            }
        }
        set {
            switch self {
            case .image(var layer):
                layer.zOrder = newValue
                self = .image(layer)
            case .text(var layer):
                layer.zOrder = newValue
                self = .text(layer)
            case .geometry(var layer):
                layer.zOrder = newValue
                self = .geometry(layer)
            case .group(var layer):
                layer.zOrder = newValue
                self = .group(layer)
            }
        }
    }
    
    var layerType: LayerType {
        switch self {
        case .image: return .image
        case .text: return .text
        case .geometry: return .geometry
        case .group: return .group
        }
    }
    
    func render(in context: CGContext, bounds: CGRect) throws {
        switch self {
        case .image(let layer): try layer.render(in: context, bounds: bounds)
        case .text(let layer): try layer.render(in: context, bounds: bounds)
        case .geometry(let layer): try layer.render(in: context, bounds: bounds)
        case .group(let layer): try layer.render(in: context, bounds: bounds)
        }
    }
    
    func naturalSize() -> CGSize {
        switch self {
        case .image(let layer): return layer.naturalSize()
        case .text(let layer): return layer.naturalSize()
        case .geometry(let layer): return layer.naturalSize()
        case .group(let layer): return layer.naturalSize()
        }
    }
    
    func copy() -> AnyOnionLayer {
        switch self {
        case .image(let layer): return .image(layer.copy())
        case .text(let layer): return .text(layer.copy())
        case .geometry(let layer): return .geometry(layer.copy())
        case .group(let layer): return .group(layer.copy())
        }
    }
    
    static func == (lhs: AnyOnionLayer, rhs: AnyOnionLayer) -> Bool {
        return lhs.id == rhs.id
    }
}