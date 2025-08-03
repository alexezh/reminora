//
//  ECardTemplateService.swift
//  reminora
//
//  Created by Claude on 8/2/25.
//

import Foundation
import SwiftUI
import Photos

// MARK: - ECard Template Service
class ECardTemplateService: ObservableObject {
    static let shared = ECardTemplateService()
    
    @Published private var templates: [ECardTemplate] = []
    
    private init() {
        loadBuiltInTemplates()
    }
    
    // MARK: - Public Interface
    
    func getAllTemplates() -> [ECardTemplate] {
        return templates
    }
    
    func getTemplate(id: String) -> ECardTemplate? {
        return templates.first { $0.id == id }
    }
    
    func getTemplates(for category: ECardCategory) -> [ECardTemplate] {
        return templates.filter { $0.category == category }
    }
    
    func getTemplateForAssets(_ assets: [PHAsset]) -> ECardTemplate? {
        guard let firstAsset = assets.first else { return templates.first }
        
        let isLandscape = firstAsset.pixelWidth > firstAsset.pixelHeight
        let templateSuffix = isLandscape ? "_landscape" : ""
        
        // Try to find orientation-specific template, fallback to default
        let preferredId = "polaroid_classic\(templateSuffix)"
        return getTemplate(id: preferredId) ?? templates.first
    }
    
    // MARK: - Template Loading
    
    private func loadBuiltInTemplates() {
        templates = [
            // Portrait templates
            createTemplateFromFile("polaroid_classic", name: "Classic Polaroid", category: .polaroid),
            createTemplateFromFile("modern_gradient", name: "Modern Gradient", category: .modern),
            createTemplateFromFile("vintage_postcard", name: "Vintage Postcard", category: .vintage),
            createTemplateFromFile("restaurant_dining", name: "Restaurant", category: .general),
            createTemplateFromFile("vacation_paradise", name: "Vacation", category: .travel),
            
            // Landscape templates
            createTemplateFromFile("polaroid_classic_landscape", name: "Classic Polaroid", category: .polaroid),
            createTemplateFromFile("modern_gradient_landscape", name: "Modern Gradient", category: .modern),
            createTemplateFromFile("vintage_postcard_landscape", name: "Vintage Postcard", category: .vintage),
            createTemplateFromFile("restaurant_dining_landscape", name: "Restaurant", category: .general),
            createTemplateFromFile("vacation_paradise_landscape", name: "Vacation", category: .travel)
        ].compactMap { $0 }
    }
    
    private func createTemplateFromFile(_ filename: String, name: String, category: ECardCategory) -> ECardTemplate? {
        let svgContent = loadSVGFromFile(filename) ?? getFallbackSVG(filename)
        
        guard !svgContent.isEmpty else {
            print("⚠️ Failed to load SVG file and no fallback available: \(filename)")
            return nil
        }
        
        let imageSlots: [ImageSlot]
        let textSlots: [TextSlot]
        
        // Configure slots based on template type and orientation
        let isLandscape = filename.contains("_landscape")
        
        switch filename {
        case let x where x.contains("polaroid_classic"):
            if isLandscape {
                imageSlots = [ImageSlot(id: "Image1", x: 40, y: 40, width: 420, height: 210, cornerRadius: 4, preserveAspectRatio: true)]
                textSlots = [TextSlot(id: "Text1", x: 40, y: 280, width: 420, height: 25, fontSize: 16, fontFamily: "Arial", textAlign: .center, maxLines: 1, placeholder: "Your caption here")]
            } else {
                imageSlots = [ImageSlot(id: "Image1", x: 40, y: 40, width: 320, height: 320, cornerRadius: 4, preserveAspectRatio: true)]
                textSlots = [
                    TextSlot(id: "Text1", x: 40, y: 400, width: 320, height: 25, fontSize: 18, fontFamily: "Arial", textAlign: .center, maxLines: 1, placeholder: "Your text here"),
                    TextSlot(id: "Text2", x: 40, y: 425, width: 320, height: 20, fontSize: 14, fontFamily: "Arial", textAlign: .center, maxLines: 1, placeholder: "Add a subtitle")
                ]
            }
            
        case let x where x.contains("modern_gradient"):
            if isLandscape {
                imageSlots = [ImageSlot(id: "Image1", x: 30, y: 30, width: 440, height: 280, cornerRadius: 12, preserveAspectRatio: true)]
                textSlots = [TextSlot(id: "Text1", x: 30, y: 345, width: 440, height: 25, fontSize: 18, fontFamily: "Helvetica", textAlign: .center, maxLines: 1, placeholder: "Caption")]
            } else {
                imageSlots = [ImageSlot(id: "Image1", x: 30, y: 60, width: 340, height: 340, cornerRadius: 12, preserveAspectRatio: true)]
                textSlots = [
                    TextSlot(id: "Text1", x: 30, y: 435, width: 340, height: 25, fontSize: 20, fontFamily: "Helvetica", textAlign: .center, maxLines: 1, placeholder: "Caption"),
                    TextSlot(id: "Text2", x: 30, y: 455, width: 340, height: 20, fontSize: 14, fontFamily: "Helvetica", textAlign: .center, maxLines: 1, placeholder: "Subtitle")
                ]
            }
            
        case let x where x.contains("vintage_postcard"):
            if isLandscape {
                imageSlots = [ImageSlot(id: "Image1", x: 40, y: 40, width: 420, height: 190, cornerRadius: 0, preserveAspectRatio: true)]
                textSlots = [TextSlot(id: "Text1", x: 50, y: 265, width: 300, height: 20, fontSize: 16, fontFamily: "serif", textAlign: .center, maxLines: 1, placeholder: "Memory")]
            } else {
                imageSlots = [ImageSlot(id: "Image1", x: 40, y: 40, width: 320, height: 270, cornerRadius: 0, preserveAspectRatio: true)]
                textSlots = [
                    TextSlot(id: "Text1", x: 50, y: 335, width: 300, height: 25, fontSize: 18, fontFamily: "serif", textAlign: .center, maxLines: 1, placeholder: "Memory"),
                    TextSlot(id: "Text2", x: 50, y: 365, width: 250, height: 20, fontSize: 14, fontFamily: "serif", textAlign: .left, maxLines: 1, placeholder: "Dear friend...")
                ]
            }
            
        case let x where x.contains("restaurant_dining"):
            if isLandscape {
                imageSlots = [ImageSlot(id: "Image1", x: 35, y: 35, width: 430, height: 210, cornerRadius: 3, preserveAspectRatio: true)]
                textSlots = [TextSlot(id: "Text1", x: 30, y: 295, width: 440, height: 22, fontSize: 18, fontFamily: "serif", textAlign: .center, maxLines: 1, placeholder: "Dining Experience")]
            } else {
                imageSlots = [ImageSlot(id: "Image1", x: 35, y: 55, width: 330, height: 270, cornerRadius: 3, preserveAspectRatio: true)]
                textSlots = [
                    TextSlot(id: "Text1", x: 30, y: 370, width: 340, height: 25, fontSize: 20, fontFamily: "serif", textAlign: .center, maxLines: 1, placeholder: "Dining Experience"),
                    TextSlot(id: "Text2", x: 30, y: 395, width: 340, height: 20, fontSize: 14, fontFamily: "serif", textAlign: .center, maxLines: 1, placeholder: "Delicious memories")
                ]
            }
            
        case let x where x.contains("vacation_paradise"):
            if isLandscape {
                imageSlots = [ImageSlot(id: "Image1", x: 30, y: 35, width: 440, height: 230, cornerRadius: 8, preserveAspectRatio: true)]
                textSlots = [TextSlot(id: "Text1", x: 25, y: 315, width: 450, height: 25, fontSize: 20, fontFamily: "Arial", textAlign: .center, maxLines: 1, placeholder: "Paradise Memories")]
            } else {
                imageSlots = [ImageSlot(id: "Image1", x: 30, y: 65, width: 340, height: 270, cornerRadius: 8, preserveAspectRatio: true)]
                textSlots = [
                    TextSlot(id: "Text1", x: 25, y: 380, width: 350, height: 28, fontSize: 22, fontFamily: "Arial", textAlign: .center, maxLines: 1, placeholder: "Paradise Memories"),
                    TextSlot(id: "Text2", x: 25, y: 405, width: 350, height: 20, fontSize: 14, fontFamily: "Arial", textAlign: .center, maxLines: 1, placeholder: "Under the sun")
                ]
            }
            
        default:
            imageSlots = [ImageSlot(id: "Image1", x: 30, y: 30, width: 340, height: 280, cornerRadius: 8, preserveAspectRatio: true)]
            textSlots = [TextSlot(id: "Text1", x: 30, y: 330, width: 340, height: 25, fontSize: 18, fontFamily: "Arial", textAlign: .center, maxLines: 1, placeholder: "Caption")]
        }
        
        return ECardTemplate(
            id: filename,
            name: name,
            svgContent: svgContent,
            thumbnailName: "\(filename)_thumb",
            imageSlots: imageSlots,
            textSlots: textSlots,
            category: category
        )
    }
    
    private func loadSVGFromFile(_ filename: String) -> String? {
        // Try loading from bundle first
        if let path = Bundle.main.path(forResource: filename, ofType: "svg"),
           let svgContent = try? String(contentsOfFile: path) {
            return svgContent
        }
        
        // Try loading from ecard subdirectory
        if let path = Bundle.main.path(forResource: filename, ofType: "svg", inDirectory: "ecard"),
           let svgContent = try? String(contentsOfFile: path) {
            return svgContent
        }
        
        // Try loading directly from filesystem (development)
        let projectPath = "/Users/alexezh/prj/wahi/ios/reminora/ecard/\(filename).svg"
        if let svgContent = try? String(contentsOfFile: projectPath) {
            return svgContent
        }
        
        print("⚠️ Could not find SVG file: \(filename)")
        return nil
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