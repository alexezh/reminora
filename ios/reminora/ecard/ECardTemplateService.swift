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
import SVGKit

// MARK: - CALayer Extension for finding layers by identifier
extension CALayer {
    func findLayer(byIdentifier id: String) -> CALayer? {
        if name == id { return self }
        for sub in sublayers ?? [] {
            if let match = sub.findLayer(byIdentifier: id) {
                return match
            }
        }
        return nil
    }
}

// MARK: - Image Assignment Helper
private class ECardImageAssignmentHelper {
    private var imageAssignments: [String: UIImage] = [:]
    
    func setImageAssignments(_ assignments: [String: UIImage]) {
        imageAssignments = assignments
        print("🎨 ECardImageAssignmentHelper: Updated image assignments for \(assignments.keys)")
    }
    
    func getImage(for slotId: String) -> UIImage? {
        return imageAssignments[slotId]
    }
}

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
    private var templatesLoaded = false
    private let imageHelper = ECardImageAssignmentHelper()
    
    private init() {
        // Templates will be loaded lazily on first access
    }
    
    // MARK: - Public Interface
    
    func getAllTemplates() -> [ECardTemplate] {
        loadTemplatesIfNeeded()
        return templates
    }
    
    func getTemplate(id: String) -> ECardTemplate? {
        loadTemplatesIfNeeded()
        return templates.first { $0.id == id }
    }
    
    func getTemplates(for category: ECardCategory) -> [ECardTemplate] {
        loadTemplatesIfNeeded()
        return templates.filter { $0.category == category }
    }
    
    func getTemplateForAssets(_ assets: [PHAsset]) -> ECardTemplate? {
        loadTemplatesIfNeeded()
        // Return default template since all templates now handle both orientations
        return getTemplate(id: "polaroid_classic") ?? templates.first
    }
    
    // MARK: - Template Loading
    
    private func loadTemplatesIfNeeded() {
        guard !templatesLoaded else { return }
        loadBuiltInTemplates()
        templatesLoaded = true
    }
    
    private func loadBuiltInTemplates() {
        print("🎨 ECardTemplateService: Loading built-in templates...")
        
        let templateDefinitions = [
            ("polaroid_classic", "Classic Polaroid", ECardCategory.polaroid),
            ("modern_gradient", "Modern Gradient", ECardCategory.modern),
            ("vintage_postcard", "Vintage Postcard", ECardCategory.vintage),
            ("restaurant_dining", "Restaurant", ECardCategory.general),
            ("vacation_paradise", "Vacation", ECardCategory.travel)
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
        
        // Use SVGKit's DOM to find image elements
        guard let svgImage = SVGKImage(data: svgContent.data(using: .utf8)),
              let domDocument = svgImage.domDocument else {
            print("⚠️ Failed to create SVGKImage or get DOM document")
            return imageSlots
        }
        
        // Look for image elements with IDs starting with "Image"
        for i in 1...10 { // Support up to 10 image slots
            let imageId = "Image\(i)"
            if let imageElement = domDocument.getElementById(imageId) {
                // Get attributes using string access - more reliable with SVGKit
                let x = Double(imageElement.getAttribute("x") ?? "0") ?? 0
                let y = Double(imageElement.getAttribute("y") ?? "0") ?? 0
                let width = Double(imageElement.getAttribute("width") ?? "0") ?? 0
                let height = Double(imageElement.getAttribute("height") ?? "0") ?? 0
                
                let imageSlot = ImageSlot(
                    id: imageId,
                    x: x, y: y,
                    width: width, height: height,
                    cornerRadius: 0, // Image elements don't have corner radius in SVG
                    preserveAspectRatio: true
                )
                imageSlots.append(imageSlot)
                print("📍 Found image slot: \(imageId) at (\(x), \(y)) size \(width)x\(height)")
            }
        }
        
        return imageSlots
    }
    
    private func parseTextSlots(from svgContent: String) -> [TextSlot] {
        var textSlots: [TextSlot] = []
        
        // Use SVGKit's DOM to find text elements
        guard let svgImage = SVGKImage(data: svgContent.data(using: .utf8)),
              let domDocument = svgImage.domDocument else {
            print("⚠️ Failed to create SVGKImage or get DOM document")
            return textSlots
        }
        
        // Look for text elements with IDs starting with "Text"
        for i in 1...10 { // Support up to 10 text slots
            let textId = "Text\(i)"
            if let textElement = domDocument.getElementById(textId) {
                // Get coordinate attributes - SVGKit may have different API
                let x = Double(textElement.getAttribute("x") ?? "0") ?? 0
                let y = Double(textElement.getAttribute("y") ?? "0") ?? 0
                let fontSize = Double(textElement.getAttribute("font-size") ?? "16") ?? 16
                let placeholder = textElement.textContent ?? "Text here"
                
                // Estimate text dimensions based on font size
                let charWidth = fontSize * 0.6
                let estimatedWidth = charWidth * Double((placeholder as String).count) + 20
                let width = estimatedWidth
                let height = Double(fontSize + 10)
                
                let textSlot = TextSlot(
                    id: textId,
                    x: x - width/2, y: y - fontSize, // Adjust for text-anchor="middle"
                    width: width, height: height,
                    fontSize: fontSize,
                    fontFamily: textElement.getAttribute("font-family") ?? "Arial",
                    textAlign: .center,
                    maxLines: 1,
                    placeholder: placeholder as String
                )
                textSlots.append(textSlot)
                print("📝 Found text slot: \(textId) at (\(x), \(y)) text: '\(placeholder)'")
            }
        }
        
        return textSlots
    }
    
    // MARK: - SVG DOM Manipulation
    
    func updateSVGWithImages(_ svgContent: String, imageAssignments: [String: UIImage]) -> String? {
        guard let svgImage = SVGKImage(data: svgContent.data(using: .utf8)),
              let _ = svgImage.domDocument else {
            print("⚠️ Failed to create SVGKImage or get DOM document for image updates")
            return svgContent
        }
        
        // TODO: Implement proper DOM image updates
        print("📝 Image assignments received: \(imageAssignments.keys)")
        // for (slotId, image) in imageAssignments {
        //     if let imageElement = domDocument.getElementById(slotId) {
        //         // Convert UIImage to base64 data URL
        //         if let imageData = image.jpegData(compressionQuality: 0.8) {
        //             let base64String = imageData.base64EncodedString()
        //             let dataURL = "data:image/jpeg;base64,\(base64String)"
        //             
        //             // Update the image element's href attribute
        //             imageElement.setAttribute("href", value: dataURL)
        //             print("🖼️ Updated image slot \(slotId) with base64 image data")
        //         }
        //     }
        // }
        
        // Return the updated SVG content
        // For now, return the original content since DOM manipulation is complex
        // TODO: Implement proper SVG string generation from DOM
        return svgContent
    }
    
    func updateSVGWithText(_ svgContent: String, textAssignments: [String: String]) -> String? {
        guard let svgImage = SVGKImage(data: svgContent.data(using: .utf8)),
              let _ = svgImage.domDocument else {
            print("⚠️ Failed to create SVGKImage or get DOM document for text updates")
            return svgContent
        }
        
        // TODO: Implement proper DOM text updates
        print("📝 Text assignments received: \(textAssignments)")
        // for (slotId, text) in textAssignments {
        //     if let textElement = domDocument.getElementById(slotId) {
        //         // Update text using setAttribute since textContent is read-only
        //         if let firstChild = textElement.firstChild {
        //             firstChild.nodeValue = text
        //         } else {
        //             // Create a new text node if none exists
        //             let textNode = domDocument.createTextNode(text)
        //             textElement.appendChild(textNode)
        //         }
        //         print("📝 Updated text slot \(slotId) with text: '\(text)'")
        //     }
        // }
        
        // Return the updated SVG content
        // For now, return the original content since DOM manipulation is complex
        // TODO: Implement proper SVG string generation from DOM
        return svgContent
    }
    
    func generateECardWithDOMUpdates(template: ECardTemplate, imageAssignments: [String: UIImage], textAssignments: [String: String], size: CGSize = CGSize(width: 800, height: 1000)) -> UIImage? {
        var updatedSVGContent = template.svgContent
        
        // Update images using DOM manipulation
        if !imageAssignments.isEmpty {
            updatedSVGContent = updateSVGWithImages(updatedSVGContent, imageAssignments: imageAssignments) ?? updatedSVGContent
        }
        
        // Update text using DOM manipulation
        if !textAssignments.isEmpty {
            updatedSVGContent = updateSVGWithText(updatedSVGContent, textAssignments: textAssignments) ?? updatedSVGContent
        }
        
        // Render the final SVG to image
        return renderSVGWithSVGKit(svgContent: updatedSVGContent, size: size)
    }
    
    
    private func loadSVGFromFile(_ filename: String) -> String? {
        // Try loading from bundle first
        if let path = Bundle.main.path(forResource: filename, ofType: "svg"),
           let svgContent = try? String(contentsOfFile: path, encoding: .utf8) {
            return svgContent
        }
        
        // Try loading from ecard subdirectory
        if let path = Bundle.main.path(forResource: filename, ofType: "svg", inDirectory: "ecard"),
           let svgContent = try? String(contentsOfFile: path, encoding: .utf8) {
            return svgContent
        }
        
        // Try loading directly from filesystem (development)
        let projectPath = "/Users/alexezh/prj/wahi/ios/reminora/ecard/\(filename).svg"
        if let svgContent = try? String(contentsOfFile: projectPath, encoding: .utf8) {
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
    
    // MARK: - SVG Rendering with Image Resolution
    
    /// Generate ECard with assigned images using pure SVG DOM manipulation
    func generateECardWithImages(
        template: ECardTemplate,
        imageAssignments: [String: UIImage],
        textAssignments: [String: String] = [:],
        size: CGSize = CGSize(width: 800, height: 1000)
    ) -> UIImage? {
        print("🎨 ECardTemplateService: Generating ECard with \(imageAssignments.count) images using pure SVG DOM manipulation")
        
        // Create SVGKImage from template content
        guard let svgData = template.svgContent.data(using: .utf8),
              let svgkImage = SVGKImage(data: svgData) else {
            print("⚠️ ECardTemplateService: Failed to create SVGKImage from template content")
            return renderSVGWithSVGKit(svgContent: template.svgContent, size: size)
        }
        
        // Set the desired output size and ensure proper scaling
        svgkImage.size = size
        
        // Force SVGKit to scale the content to fit inside the target size
        svgkImage.scaleToFit(inside: size)
        
        // Get DOM document for manipulation
        guard let domDocument = svgkImage.domDocument else {
            print("⚠️ ECardTemplateService: Failed to get DOM document")
            return renderSVGWithSVGKit(svgContent: template.svgContent, size: size)
        }
        
        // Update image layers in CALayer tree - works regardless of DOM element type
        if let rootLayer = svgkImage.caLayerTree {
            for slot in template.imageSlots {
                let slotId = slot.id
                if let image = imageAssignments[slotId] {
                    
                    // Convert UIImage to PNG data for consistency
                    guard let pngData = image.pngData(),
                          let pngImage = UIImage(data: pngData) else {
                        print("⚠️ Failed to convert image to PNG for slot \(slotId)")
                        continue
                    }
                    
                    // Find the CALayer for this image slot
                    if let imageLayer = rootLayer.findLayer(byIdentifier: slotId) {
                        // Set the CGImage directly on the layer's contents
                        imageLayer.contents = pngImage.cgImage
                        print("🎨 ECardTemplateService: Set CGImage contents on CALayer for slot \(slotId)")
                    } else {
                        print("⏭️ ECardTemplateService: Could not find CALayer for slot \(slotId)")
                    }
                }
            }
        } else {
            print("⚠️ ECardTemplateService: Could not access caLayerTree from SVGKImage")
        }
        
        // Update text elements in DOM
        for (slotId, text) in textAssignments {
            if let textElement = domDocument.getElementById(slotId) as? SVGTextElement {
                // For SVG text elements, we need to clear existing content and add new text node
                // Remove all child nodes first
                while let child = textElement.firstChild {
                    textElement.removeChild(child)
                }
                // Add new text node
                let textNode = domDocument.createTextNode(text)
                textElement.appendChild(textNode)
                print("🎨 ECardTemplateService: Updated text element \(slotId) with: '\(text)'")
            } else if let textElement = domDocument.getElementById(slotId) {
                // For other elements, try to update via attribute or similar
                print("🎨 ECardTemplateService: Element \(slotId) is not SVGTextElement, type: \(type(of: textElement))")
            }
        }
        
        // Render the final SVG using CALayer approach to ensure proper scaling and positioning
        if let rootLayer = svgkImage.caLayerTree {
            print("🎨 ECardTemplateService: Using CALayer rendering for final image")
            
            let scale = UIScreen.main.scale
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            format.opaque = false
            
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let renderedImage = renderer.image { context in
                let cgContext = context.cgContext
                
                // Clear background to white for ECard
                cgContext.setFillColor(UIColor.white.cgColor)
                cgContext.fill(CGRect(origin: .zero, size: size))
                
                // Set the layer frame to match our target size and position at origin
                rootLayer.frame = CGRect(origin: .zero, size: size)
                
                // Ensure the layer contents are scaled properly
                rootLayer.contentsGravity = .resizeAspect
                
                // Render the layer directly
                rootLayer.render(in: cgContext)
            }
            
            print("✅ ECardTemplateService: CALayer rendering completed with size \(size)")
            return renderedImage
        }
        
        // Fallback to UIImage property
        let finalImage = svgkImage.uiImage
        
        // Resize if needed
        if let finalImage = finalImage, finalImage.size != size {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                finalImage.draw(in: CGRect(origin: .zero, size: size))
            }
        }
        
        return finalImage
    }
    
    // MARK: - SVG Thumbnail Generation
    
    func generateThumbnail(for template: ECardTemplate, size: CGSize = CGSize(width: 120, height: 150)) -> UIImage? {
        return renderSVGToImageWithWebView(svgContent: template.svgContent, size: size)
    }
    
    private func renderSVGToImageWithWebView(svgContent: String, size: CGSize) -> UIImage? {
        // Use SVGKit for proper SVG rendering
        return renderSVGWithSVGKit(svgContent: svgContent, size: size)
    }
    
    private func renderSVGWithSVGKit(svgContent: String, size: CGSize) -> UIImage? {
        print("🎨 ECardTemplateService: Attempting SVGKit rendering with size \(size)")
        
        // Create SVGKImage from SVG content
        guard let svgkImage = SVGKImage(data: svgContent.data(using: .utf8)) else {
            print("⚠️ Failed to create SVGKImage from content, falling back to basic rendering")
            return renderSVGToImageBasic(svgContent: svgContent, size: size)
        }
        
        // Set the desired size to match the control
        svgkImage.size = size
        print("🎨 ECardTemplateService: SVGKImage created successfully, size set to \(size)")
        
        // Try to use CALayer rendering (most reliable approach)
        if let caLayer = svgkImage.caLayerTree {
            print("🎨 ECardTemplateService: Using CALayer rendering approach")
            
            // Create a bitmap context with proper scale
            let scale = UIScreen.main.scale
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            format.opaque = false
            
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            let renderedImage = renderer.image { context in
                let cgContext = context.cgContext
                
                // Clear background to white for better visibility
                cgContext.setFillColor(UIColor.white.cgColor)
                cgContext.fill(CGRect(origin: .zero, size: size))
                
                // Set the layer frame to match our target size
                caLayer.frame = CGRect(origin: .zero, size: size)
                
                // Render the layer directly without complex scaling transforms
                caLayer.render(in: cgContext)
            }
            
            print("✅ ECardTemplateService: CALayer rendering completed")
            return renderedImage
        }
        
        // Fallback to UIImage property if CALayer fails
        print("🎨 ECardTemplateService: CALayer not available, using UIImage property")
        if let uiImage = svgkImage.uiImage {
            // Resize the image to match our target size if needed
            if uiImage.size != size {
                let renderer = UIGraphicsImageRenderer(size: size)
                let resizedImage = renderer.image { _ in
                    uiImage.draw(in: CGRect(origin: .zero, size: size))
                }
                print("✅ ECardTemplateService: UIImage resized to target size")
                return resizedImage
            }
            print("✅ ECardTemplateService: Using UIImage directly")
            return uiImage
        }
        
        // Final fallback to basic rendering if SVGKit completely fails
        print("⚠️ ECardTemplateService: SVGKit failed completely, using basic rendering")
        return renderSVGToImageBasic(svgContent: svgContent, size: size)
    }
    
    private func renderSVGToImageBasic(svgContent: String, size: CGSize) -> UIImage? {
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
