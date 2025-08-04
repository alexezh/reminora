//
//  ECardTemplateService.swift
//  reminora
//
//  Created by Claude on 8/2/25.
//

import Foundation
import SwiftUI
import Photos
import UIKit

// MARK: - UIColor Extension for Hex Colors
extension UIColor {
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat
        
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            
            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    a = 1.0
                    
                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }
        
        return nil
    }
}

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
        
        // Parse image and text slots from SVG content
        let imageSlots = parseImageSlots(from: svgContent)
        let textSlots = parseTextSlots(from: svgContent)
        
        print("🎨 Parsed \(imageSlots.count) image slots and \(textSlots.count) text slots from \(filename)")
        
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
    
    // MARK: - SVG Parsing
    
    private func parseImageSlots(from svgContent: String) -> [ImageSlot] {
        var imageSlots: [ImageSlot] = []
        
        // Parse rect elements with id starting with "Image"
        let imagePattern = #"<rect\s+id="(Image\d+)"\s+x="(\d+)"\s+y="(\d+)"\s+width="(\d+)"\s+height="(\d+)"(?:\s+rx="(\d+)")?"#
        
        let regex = try? NSRegularExpression(pattern: imagePattern, options: [])
        let nsString = svgContent as NSString
        let results = regex?.matches(in: svgContent, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for result in results {
            if result.numberOfRanges >= 6 {
                let id = nsString.substring(with: result.range(at: 1))
                let x = Double(nsString.substring(with: result.range(at: 2))) ?? 0
                let y = Double(nsString.substring(with: result.range(at: 3))) ?? 0
                let width = Double(nsString.substring(with: result.range(at: 4))) ?? 0
                let height = Double(nsString.substring(with: result.range(at: 5))) ?? 0
                let cornerRadius = result.numberOfRanges > 6 && result.range(at: 6).location != NSNotFound 
                    ? Double(nsString.substring(with: result.range(at: 6))) ?? 0 
                    : 0
                
                let imageSlot = ImageSlot(
                    id: id,
                    x: x, y: y,
                    width: width, height: height,
                    cornerRadius: cornerRadius,
                    preserveAspectRatio: true
                )
                imageSlots.append(imageSlot)
            }
        }
        
        return imageSlots
    }
    
    private func parseTextSlots(from svgContent: String) -> [TextSlot] {
        var textSlots: [TextSlot] = []
        
        // Parse text elements with id starting with "Text"
        let textPattern = #"<text\s+id="(Text\d+)"\s+x="(\d+)"\s+y="(\d+)"[^>]*font-size="(\d+)"[^>]*>([^<]+)</text>"#
        
        let regex = try? NSRegularExpression(pattern: textPattern, options: [])
        let nsString = svgContent as NSString
        let results = regex?.matches(in: svgContent, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for result in results {
            if result.numberOfRanges >= 6 {
                let id = nsString.substring(with: result.range(at: 1))
                let x = Double(nsString.substring(with: result.range(at: 2))) ?? 0
                let y = Double(nsString.substring(with: result.range(at: 3))) ?? 0
                let fontSize = Int(nsString.substring(with: result.range(at: 4))) ?? 16
                let placeholder = nsString.substring(with: result.range(at: 5))
                
                // Estimate text dimensions based on font size
                let width = Double(fontSize * placeholder.count + 50)
                let height = Double(fontSize + 10)
                
                let textSlot = TextSlot(
                    id: id,
                    x: x - width/2, y: y - Double(fontSize), // Adjust for text-anchor="middle"
                    width: width, height: height,
                    fontSize: Double(fontSize),
                    fontFamily: "Arial", // Default fallback
                    textAlign: .center,
                    maxLines: 1,
                    placeholder: placeholder
                )
                textSlots.append(textSlot)
            }
        }
        
        return textSlots
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
        // Return empty string - we should always load from actual SVG files
        print("⚠️ Using fallback SVG for \(filename) - this should not happen in production")
        return ""
    }
    
    // MARK: - SVG Thumbnail Generation
    
    func generateThumbnail(for template: ECardTemplate, size: CGSize = CGSize(width: 120, height: 150)) -> UIImage? {
        return renderSVGToImage(svgContent: template.svgContent, size: size)
    }
    
    private func renderSVGToImage(svgContent: String, size: CGSize) -> UIImage? {
        // Create a simple renderer using UIGraphicsImageRenderer
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Set background color
            cgContext.setFillColor(UIColor.systemBackground.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Parse basic SVG elements and render them
            renderBasicSVGElements(svgContent: svgContent, context: cgContext, targetSize: size)
        }
    }
    
    private func renderBasicSVGElements(svgContent: String, context: CGContext, targetSize: CGSize) {
        // Extract viewBox to calculate scale
        let viewBoxPattern = #"viewBox="([^"]+)""#
        if let viewBoxMatch = svgContent.range(of: viewBoxPattern, options: .regularExpression) {
            let viewBoxString = String(svgContent[viewBoxMatch])
            let values = viewBoxString.replacingOccurrences(of: "viewBox=\"", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .split(separator: " ")
                .compactMap { Double($0) }
            
            if values.count >= 4 {
                let svgWidth = values[2]
                let svgHeight = values[3]
                let scaleX = targetSize.width / svgWidth
                let scaleY = targetSize.height / svgHeight
                let scale = min(scaleX, scaleY)
                
                context.scaleBy(x: scale, y: scale)
            }
        }
        
        // Render rectangles (background, frames, image placeholders)
        renderSVGRectangles(svgContent: svgContent, context: context)
        
        // Render circles (decorative elements)
        renderSVGCircles(svgContent: svgContent, context: context)
        
        // Render gradients and filters (simplified)
        renderSVGGradients(svgContent: svgContent, context: context)
    }
    
    private func renderSVGRectangles(svgContent: String, context: CGContext) {
        let rectPattern = #"<rect[^>]*x="(\d+)"[^>]*y="(\d+)"[^>]*width="(\d+)"[^>]*height="(\d+)"[^>]*fill="([^"]*)"[^>]*/?>"#
        
        let regex = try? NSRegularExpression(pattern: rectPattern, options: [])
        let results = regex?.matches(in: svgContent, options: [], range: NSRange(location: 0, length: svgContent.count)) ?? []
        
        for result in results {
            if result.numberOfRanges >= 6 {
                let nsString = svgContent as NSString
                let x = Double(nsString.substring(with: result.range(at: 1))) ?? 0
                let y = Double(nsString.substring(with: result.range(at: 2))) ?? 0
                let width = Double(nsString.substring(with: result.range(at: 3))) ?? 0
                let height = Double(nsString.substring(with: result.range(at: 4))) ?? 0
                let fillColor = nsString.substring(with: result.range(at: 5))
                
                let rect = CGRect(x: x, y: y, width: width, height: height)
                
                if let color = parseColor(fillColor) {
                    context.setFillColor(color)
                    context.fill(rect)
                }
            }
        }
    }
    
    private func renderSVGCircles(svgContent: String, context: CGContext) {
        let circlePattern = #"<circle[^>]*cx="(\d+)"[^>]*cy="(\d+)"[^>]*r="([^"]*)"[^>]*fill="([^"]*)"[^>]*/?>"#
        
        let regex = try? NSRegularExpression(pattern: circlePattern, options: [])
        let results = regex?.matches(in: svgContent, options: [], range: NSRange(location: 0, length: svgContent.count)) ?? []
        
        for result in results {
            if result.numberOfRanges >= 5 {
                let nsString = svgContent as NSString
                let cx = Double(nsString.substring(with: result.range(at: 1))) ?? 0
                let cy = Double(nsString.substring(with: result.range(at: 2))) ?? 0
                let r = Double(nsString.substring(with: result.range(at: 3))) ?? 0
                let fillColor = nsString.substring(with: result.range(at: 4))
                
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                
                if let color = parseColor(fillColor) {
                    context.setFillColor(color)
                    context.fillEllipse(in: rect)
                }
            }
        }
    }
    
    private func renderSVGGradients(svgContent: String, context: CGContext) {
        // Simplified gradient rendering - just render as solid colors for thumbnails
        if svgContent.contains("linearGradient") {
            // For modern gradient template, use a simple blue background
            context.setFillColor(UIColor.systemBlue.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 500))
        }
    }
    
    private func parseColor(_ colorString: String) -> CGColor? {
        if colorString.hasPrefix("#") {
            return UIColor(hex: colorString)?.cgColor
        } else if colorString == "transparent" {
            return UIColor.clear.cgColor
        } else {
            // Handle named colors
            switch colorString {
            case "#ffffff", "white": return UIColor.white.cgColor
            case "#000000", "black": return UIColor.black.cgColor
            case "#e8e8e8": return UIColor.systemGray5.cgColor
            case "#f5f5f5": return UIColor.systemGray6.cgColor
            case "#8b4513": return UIColor.brown.cgColor
            case "#ff6b6b": return UIColor.systemRed.cgColor
            case "#4ecdc4": return UIColor.systemTeal.cgColor
            case "#45b7d1": return UIColor.systemBlue.cgColor
            case "#ffd700": return UIColor.systemYellow.cgColor
            default: return UIColor.gray.cgColor
            }
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