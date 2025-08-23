//
//  ECardModels.swift
//  reminora
//
//  Created by Claude on 8/2/25.
//

import Foundation
import Photos
import SwiftUI

// MARK: - ECard Template
struct ECardTemplate: Identifiable, Codable {
    let id: String
    let name: String
    let svgContent: String
    let thumbnailName: String?
    let imageSlots: [ImageSlot]
    let textSlots: [TextSlot]
    let category: ECardCategory
    let sceneBuilderName: String?
    
    // Computed properties
    var aspectRatio: Double {
        return svgDimensions.width / svgDimensions.height
    }
    
    var svgDimensions: CGSize {
        // Default SVG viewbox size - templates are assumed to be created in 100x100 coordinate system
        return CGSize(width: 100, height: 100)
    }

    init(
        id: String, name: String, svgContent: String, thumbnailName: String? = nil,
        imageSlots: [ImageSlot], textSlots: [TextSlot] = [], category: ECardCategory = .general,
        sceneBuilderName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.svgContent = svgContent
        self.thumbnailName = thumbnailName
        self.imageSlots = imageSlots
        self.textSlots = textSlots
        self.category = category
        self.sceneBuilderName = sceneBuilderName
    }
}

// MARK: - Image Slot
struct ImageSlot: Identifiable, Codable {
    let id: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let cornerRadius: Double

    init(id: String, x: Double = 0, y: Double = 0, width: Double = 100, height: Double = 100, cornerRadius: Double = 0) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
}

// MARK: - Text Slot
struct TextSlot: Identifiable, Codable {
    let id: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let fontSize: Double
    let placeholder: String

    init(
        id: String, x: Double = 0, y: Double = 0, width: Double = 100, height: Double = 20, 
        fontSize: Double = 16, placeholder: String = "Text here"
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.fontSize = fontSize
        self.placeholder = placeholder
    }
}

enum TextAlignment: String, Codable {
    case left = "start"
    case center = "middle"
    case right = "end"
}

// MARK: - ECard Category
enum ECardCategory: String, Codable, CaseIterable {
    case general = "General"
    case polaroid = "Polaroid"
    case vintage = "Vintage"
    case modern = "Modern"
    case holiday = "Holiday"
    case travel = "Travel"

    var displayName: String {
        return rawValue
    }

    var icon: String {
        switch self {
        case .general: return "rectangle.stack"
        case .polaroid: return "camera.viewfinder"
        case .vintage: return "camera.on.rectangle"
        case .modern: return "rectangle.portrait"
        case .holiday: return "gift"
        case .travel: return "airplane"
        }
    }
}

// MARK: - ECard Instance
struct ECard: Identifiable, Codable {
    let id: String
    let templateId: String
    let imageAssignments: [String: String]  // ImageSlot ID -> PHAsset localIdentifier
    let textAssignments: [String: String]  // TextSlot ID -> Text content
    let createdAt: Date
    let updatedAt: Date

    init(
        templateId: String, imageAssignments: [String: String] = [:],
        textAssignments: [String: String] = [:]
    ) {
        self.id = UUID().uuidString
        self.templateId = templateId
        self.imageAssignments = imageAssignments
        self.textAssignments = textAssignments
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func updated(
        imageAssignments: [String: String]? = nil, textAssignments: [String: String]? = nil
    ) -> ECard {
        return ECard(
            id: self.id,
            templateId: self.templateId,
            imageAssignments: imageAssignments ?? self.imageAssignments,
            textAssignments: textAssignments ?? self.textAssignments,
            createdAt: self.createdAt,
            updatedAt: Date()
        )
    }

    private init(
        id: String, templateId: String, imageAssignments: [String: String],
        textAssignments: [String: String], createdAt: Date, updatedAt: Date
    ) {
        self.id = id
        self.templateId = templateId
        self.imageAssignments = imageAssignments
        self.textAssignments = textAssignments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - ECard Size
enum ECardSize: String, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case custom = "Custom"

    var dimensions: CGSize {
        switch self {
        case .small: return CGSize(width: 300, height: 400)
        case .medium: return CGSize(width: 400, height: 500)
        case .large: return CGSize(width: 500, height: 650)
        case .custom: return CGSize(width: 400, height: 500)  // Default for custom
        }
    }
}
