//
//  ECardTemplateService.swift
//  reminora
//
//  Created by Claude on 8/2/25.
//

import Foundation
import SwiftUI

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
    
    // MARK: - Template Loading
    
    private func loadBuiltInTemplates() {
        templates = [
            createPolaroidTemplate(),
            createModernFrameTemplate(),
            createVintagePostcardTemplate()
        ]
    }
    
    // MARK: - Built-in Templates
    
    private func createPolaroidTemplate() -> ECardTemplate {
        let svgContent = """
        <svg viewBox="0 0 400 500" xmlns="http://www.w3.org/2000/svg">
            <!-- Polaroid frame background -->
            <rect x="20" y="20" width="360" height="460" rx="8" ry="8" fill="#ffffff" stroke="#e0e0e0" stroke-width="2"/>
            
            <!-- Drop shadow -->
            <defs>
                <filter id="dropshadow" x="-20%" y="-20%" width="140%" height="140%">
                    <feDropShadow dx="2" dy="4" stdDeviation="3" flood-color="#00000020"/>
                </filter>
            </defs>
            
            <!-- Apply shadow to frame -->
            <rect x="20" y="20" width="360" height="460" rx="8" ry="8" fill="#ffffff" filter="url(#dropshadow)"/>
            
            <!-- Photo area background -->
            <rect x="40" y="40" width="320" height="320" rx="4" ry="4" fill="#f5f5f5" stroke="#d0d0d0" stroke-width="1"/>
            
            <!-- Image placeholder -->
            <rect id="Image1" x="40" y="40" width="320" height="320" rx="4" ry="4" fill="#e8e8e8"/>
            
            <!-- Text area background -->
            <rect x="40" y="380" width="320" height="80" fill="transparent"/>
            
            <!-- Text placeholder -->
            <text id="Text1" x="200" y="410" text-anchor="middle" font-family="Arial, sans-serif" font-size="18" font-weight="normal" fill="#333333">Your text here</text>
            <text id="Text2" x="200" y="435" text-anchor="middle" font-family="Arial, sans-serif" font-size="14" font-weight="normal" fill="#666666">Add a subtitle</text>
            
            <!-- Decorative elements -->
            <circle cx="350" cy="50" r="3" fill="#ff6b6b" opacity="0.7"/>
            <circle cx="350" cy="65" r="2" fill="#4ecdc4" opacity="0.7"/>
            <circle cx="350" cy="78" r="2.5" fill="#45b7d1" opacity="0.7"/>
        </svg>
        """
        
        let imageSlots = [
            ImageSlot(id: "Image1", x: 40, y: 40, width: 320, height: 320, cornerRadius: 4, preserveAspectRatio: true)
        ]
        
        let textSlots = [
            TextSlot(id: "Text1", x: 40, y: 400, width: 320, height: 25, fontSize: 18, fontFamily: "Arial", textAlign: .center, maxLines: 1, placeholder: "Your text here"),
            TextSlot(id: "Text2", x: 40, y: 425, width: 320, height: 20, fontSize: 14, fontFamily: "Arial", textAlign: .center, maxLines: 1, placeholder: "Add a subtitle")
        ]
        
        return ECardTemplate(
            id: "polaroid_classic",
            name: "Classic Polaroid",
            svgContent: svgContent,
            thumbnailName: "polaroid_classic_thumb",
            imageSlots: imageSlots,
            textSlots: textSlots,
            category: .polaroid
        )
    }
    
    private func createModernFrameTemplate() -> ECardTemplate {
        let svgContent = """
        <svg viewBox="0 0 400 500" xmlns="http://www.w3.org/2000/svg">
            <!-- Modern frame with gradient background -->
            <defs>
                <linearGradient id="modernGradient" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" style="stop-color:#667eea;stop-opacity:1" />
                    <stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" />
                </linearGradient>
                <filter id="modernShadow" x="-20%" y="-20%" width="140%" height="140%">
                    <feDropShadow dx="0" dy="8" stdDeviation="16" flood-color="#00000030"/>
                </filter>
            </defs>
            
            <!-- Background -->
            <rect x="0" y="0" width="400" height="500" fill="url(#modernGradient)" filter="url(#modernShadow)"/>
            
            <!-- Main photo area -->
            <rect id="Image1" x="30" y="60" width="340" height="340" rx="12" ry="12" fill="#ffffff"/>
            
            <!-- Text area -->
            <rect x="30" y="420" width="340" height="60" fill="rgba(255,255,255,0.9)" rx="8" ry="8"/>
            
            <!-- Text content -->
            <text id="Text1" x="200" y="445" text-anchor="middle" font-family="Helvetica, sans-serif" font-size="20" font-weight="bold" fill="#333333">Modern Title</text>
            <text id="Text2" x="200" y="465" text-anchor="middle" font-family="Helvetica, sans-serif" font-size="14" font-weight="normal" fill="#666666">Elegant subtitle</text>
        </svg>
        """
        
        let imageSlots = [
            ImageSlot(id: "Image1", x: 30, y: 60, width: 340, height: 340, cornerRadius: 12, preserveAspectRatio: true)
        ]
        
        let textSlots = [
            TextSlot(id: "Text1", x: 30, y: 435, width: 340, height: 25, fontSize: 20, fontFamily: "Helvetica", textAlign: .center, maxLines: 1, placeholder: "Modern Title"),
            TextSlot(id: "Text2", x: 30, y: 455, width: 340, height: 20, fontSize: 14, fontFamily: "Helvetica", textAlign: .center, maxLines: 1, placeholder: "Elegant subtitle")
        ]
        
        return ECardTemplate(
            id: "modern_gradient",
            name: "Modern Gradient",
            svgContent: svgContent,
            thumbnailName: "modern_gradient_thumb",
            imageSlots: imageSlots,
            textSlots: textSlots,
            category: .modern
        )
    }
    
    private func createVintagePostcardTemplate() -> ECardTemplate {
        let svgContent = """
        <svg viewBox="0 0 400 500" xmlns="http://www.w3.org/2000/svg">
            <!-- Vintage postcard background -->
            <rect x="0" y="0" width="400" height="500" fill="#f4e9d9"/>
            
            <!-- Aged paper texture -->
            <rect x="0" y="0" width="400" height="500" fill="url(#vintageTexture)" opacity="0.3"/>
            
            <defs>
                <pattern id="vintageTexture" patternUnits="userSpaceOnUse" width="20" height="20">
                    <rect width="20" height="20" fill="#e8dcc0"/>
                    <circle cx="5" cy="5" r="1" fill="#d4c4a8" opacity="0.5"/>
                    <circle cx="15" cy="15" r="0.5" fill="#c9b892" opacity="0.3"/>
                </pattern>
                
                <filter id="vintageShadow" x="-20%" y="-20%" width="140%" height="140%">
                    <feDropShadow dx="2" dy="2" stdDeviation="4" flood-color="#8b4513" flood-opacity="0.3"/>
                </filter>
            </defs>
            
            <!-- Postcard border -->
            <rect x="15" y="15" width="370" height="470" fill="transparent" stroke="#8b4513" stroke-width="3" stroke-dasharray="5,5"/>
            
            <!-- Photo area with vintage frame -->
            <rect x="35" y="35" width="330" height="280" fill="#ffffff" stroke="#8b4513" stroke-width="2"/>
            <rect id="Image1" x="40" y="40" width="320" height="270" fill="#e8e8e8"/>
            
            <!-- Decorative corner elements -->
            <polygon points="35,35 55,35 35,55" fill="#8b4513" opacity="0.7"/>
            <polygon points="365,35 345,35 365,55" fill="#8b4513" opacity="0.7"/>
            <polygon points="35,315 55,315 35,295" fill="#8b4513" opacity="0.7"/>
            <polygon points="365,315 345,315 365,295" fill="#8b4513" opacity="0.7"/>
            
            <!-- Address line -->
            <line x1="50" y1="360" x2="350" y2="360" stroke="#8b4513" stroke-width="1" opacity="0.5"/>
            <line x1="50" y1="385" x2="350" y2="385" stroke="#8b4513" stroke-width="1" opacity="0.5"/>
            
            <!-- Text areas -->
            <text id="Text1" x="200" y="345" text-anchor="middle" font-family="serif" font-size="18" font-weight="bold" fill="#8b4513">Vintage Memory</text>
            <text id="Text2" x="60" y="375" text-anchor="start" font-family="serif" font-size="14" font-style="italic" fill="#8b4513">Dear friend...</text>
            
            <!-- Vintage stamp area -->
            <rect x="320" y="400" width="60" height="80" fill="transparent" stroke="#8b4513" stroke-width="2" stroke-dasharray="3,2"/>
            <text x="350" y="445" text-anchor="middle" font-family="serif" font-size="10" fill="#8b4513">STAMP</text>
        </svg>
        """
        
        let imageSlots = [
            ImageSlot(id: "Image1", x: 40, y: 40, width: 320, height: 270, cornerRadius: 0, preserveAspectRatio: true)
        ]
        
        let textSlots = [
            TextSlot(id: "Text1", x: 50, y: 335, width: 300, height: 25, fontSize: 18, fontFamily: "serif", textAlign: .center, maxLines: 1, placeholder: "Vintage Memory"),
            TextSlot(id: "Text2", x: 50, y: 365, width: 250, height: 20, fontSize: 14, fontFamily: "serif", textAlign: .left, maxLines: 1, placeholder: "Dear friend...")
        ]
        
        return ECardTemplate(
            id: "vintage_postcard",
            name: "Vintage Postcard",
            svgContent: svgContent,
            thumbnailName: "vintage_postcard_thumb",
            imageSlots: imageSlots,
            textSlots: textSlots,
            category: .vintage
        )
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