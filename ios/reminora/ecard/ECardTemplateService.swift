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
        print("🎨 ECardTemplateService: Loading built-in templates...")
        
        let templateDefinitions = [
            // Portrait templates
            ("polaroid_classic", "Classic Polaroid", ECardCategory.polaroid),
            ("modern_gradient", "Modern Gradient", ECardCategory.modern),
            ("vintage_postcard", "Vintage Postcard", ECardCategory.vintage),
            ("restaurant_dining", "Restaurant", ECardCategory.general),
            ("vacation_paradise", "Vacation", ECardCategory.travel),
            
            // Landscape templates
            ("polaroid_classic_landscape", "Classic Polaroid Landscape", ECardCategory.polaroid),
            ("modern_gradient_landscape", "Modern Gradient Landscape", ECardCategory.modern),
            ("vintage_postcard_landscape", "Vintage Postcard Landscape", ECardCategory.vintage),
            ("restaurant_dining_landscape", "Restaurant Landscape", ECardCategory.general),
            ("vacation_paradise_landscape", "Vacation Landscape", ECardCategory.travel)
        ]
        
        templates = templateDefinitions.compactMap { (filename, name, category) in
            print("🎨 Loading template: \(filename)")
            let template = createTemplateFromFile(filename, name: name, category: category)
            if template != nil {
                print("✅ Successfully loaded: \(filename)")
            } else {
                print("❌ Failed to load: \(filename)")
            }
            return template
        }
        
        print("🎨 ECardTemplateService: Loaded \(templates.count) templates")
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
    
    private func getFallbackSVG(_ filename: String) -> String {
        switch filename {
        case "polaroid_classic":
            return """
            <svg viewBox="0 0 400 500" xmlns="http://www.w3.org/2000/svg">
                <rect x="20" y="20" width="360" height="460" rx="8" ry="8" fill="#ffffff" stroke="#e0e0e0" stroke-width="2"/>
                <defs>
                    <filter id="dropshadow" x="-20%" y="-20%" width="140%" height="140%">
                        <feDropShadow dx="2" dy="4" stdDeviation="3" flood-color="#00000020"/>
                    </filter>
                </defs>
                <rect x="20" y="20" width="360" height="460" rx="8" ry="8" fill="#ffffff" filter="url(#dropshadow)"/>
                <rect x="40" y="40" width="320" height="320" rx="4" ry="4" fill="#f5f5f5" stroke="#d0d0d0" stroke-width="1"/>
                <rect id="Image1" x="40" y="40" width="320" height="320" rx="4" ry="4" fill="#e8e8e8"/>
                <rect x="40" y="380" width="320" height="80" fill="transparent"/>
                <text id="Text1" x="200" y="410" text-anchor="middle" font-family="Arial, sans-serif" font-size="18" font-weight="normal" fill="#333333">Your text here</text>
                <text id="Text2" x="200" y="435" text-anchor="middle" font-family="Arial, sans-serif" font-size="14" font-weight="normal" fill="#666666">Add a subtitle</text>
                <circle cx="350" cy="50" r="3" fill="#ff6b6b" opacity="0.7"/>
                <circle cx="350" cy="65" r="2" fill="#4ecdc4" opacity="0.7"/>
                <circle cx="350" cy="78" r="2.5" fill="#45b7d1" opacity="0.7"/>
            </svg>
            """
            
        case "polaroid_classic_landscape":
            return """
            <svg viewBox="0 0 500 400" xmlns="http://www.w3.org/2000/svg">
                <rect x="20" y="20" width="460" height="300" rx="8" ry="8" fill="#ffffff" stroke="#e0e0e0" stroke-width="2"/>
                <defs>
                    <filter id="dropshadow" x="-20%" y="-20%" width="140%" height="140%">
                        <feDropShadow dx="2" dy="4" stdDeviation="3" flood-color="#00000020"/>
                    </filter>
                </defs>
                <rect x="20" y="20" width="460" height="300" rx="8" ry="8" fill="#ffffff" filter="url(#dropshadow)"/>
                <rect x="40" y="40" width="420" height="210" rx="4" ry="4" fill="#f5f5f5" stroke="#d0d0d0" stroke-width="1"/>
                <rect id="Image1" x="40" y="40" width="420" height="210" rx="4" ry="4" fill="#e8e8e8"/>
                <rect x="40" y="270" width="420" height="30" fill="transparent"/>
                <text id="Text1" x="250" y="290" text-anchor="middle" font-family="Arial, sans-serif" font-size="16" font-weight="normal" fill="#333333">Your caption here</text>
                <circle cx="450" cy="50" r="3" fill="#ff6b6b" opacity="0.7"/>
                <circle cx="450" cy="65" r="2" fill="#4ecdc4" opacity="0.7"/>
                <circle cx="450" cy="78" r="2.5" fill="#45b7d1" opacity="0.7"/>
            </svg>
            """
            
        case "modern_gradient":
            return """
            <svg viewBox="0 0 400 500" xmlns="http://www.w3.org/2000/svg">
                <defs>
                    <linearGradient id="modernGradient" x1="0%" y1="0%" x2="100%" y2="100%">
                        <stop offset="0%" style="stop-color:#667eea;stop-opacity:1" />
                        <stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" />
                    </linearGradient>
                    <filter id="modernShadow" x="-20%" y="-20%" width="140%" height="140%">
                        <feDropShadow dx="0" dy="8" stdDeviation="16" flood-color="#00000030"/>
                    </filter>
                </defs>
                <rect x="0" y="0" width="400" height="500" fill="url(#modernGradient)" filter="url(#modernShadow)"/>
                <rect id="Image1" x="30" y="60" width="340" height="340" rx="12" ry="12" fill="#ffffff"/>
                <rect x="30" y="420" width="340" height="60" fill="rgba(255,255,255,0.9)" rx="8" ry="8"/>
                <text id="Text1" x="200" y="445" text-anchor="middle" font-family="Helvetica, sans-serif" font-size="20" font-weight="bold" fill="#333333">Caption</text>
                <text id="Text2" x="200" y="465" text-anchor="middle" font-family="Helvetica, sans-serif" font-size="14" font-weight="normal" fill="#666666">Subtitle</text>
            </svg>
            """
            
        default:
            return """
            <svg viewBox="0 0 400 500" xmlns="http://www.w3.org/2000/svg">
                <rect x="0" y="0" width="400" height="500" fill="#f0f0f0"/>
                <rect id="Image1" x="50" y="50" width="300" height="300" fill="#e0e0e0" rx="8"/>
                <text id="Text1" x="200" y="400" text-anchor="middle" font-family="Arial" font-size="18" fill="#333">Template</text>
            </svg>
            """
        }
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