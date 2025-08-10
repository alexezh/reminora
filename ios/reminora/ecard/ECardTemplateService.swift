//
//  ECardTemplateService.swift
//  reminora
//
//  Created by Claude on 8/2/25.
//

import Foundation
import Photos
import SVGKit
import SwiftUI
import UIKit

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
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat

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
    
    // Default output size for ECards
    private let size = CGSize(width: 800, height: 1000)

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
            ("vacation_paradise", "Vacation", ECardCategory.travel),
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

    private func createTemplateFromFile(_ filename: String, name: String, category: ECardCategory)
        -> ECardTemplate?
    {
        let svgContent = loadSVGFromFile(filename) ?? getFallbackSVG(filename)

        guard !svgContent.isEmpty else {
            print("⚠️ Failed to load SVG file and no fallback available: \(filename)")
            return nil
        }

        // Parse image and text slots from SVG content
        let imageSlots = parseImageSlots(from: svgContent)
        let textSlots = parseTextSlots(from: svgContent)

        print(
            "🎨 Parsed \(imageSlots.count) image slots and \(textSlots.count) text slots from \(filename)"
        )

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
            let domDocument = svgImage.domDocument
        else {
            print("⚠️ Failed to create SVGKImage or get DOM document")
            return imageSlots
        }

        // Look for image elements with IDs starting with "Image"
        for i in 1...10 {  // Support up to 10 image slots
            let imageId = "Image\(i)"
            if let imageElement = domDocument.getElementById(imageId) {
                // Get attributes using string access - more reliable with SVGKit
                let x = Double(imageElement.getAttribute("x") ?? "0") ?? 0
                let y = Double(imageElement.getAttribute("y") ?? "0") ?? 0
                let width = Double(imageElement.getAttribute("width") ?? "0") ?? 0
                let height = Double(imageElement.getAttribute("height") ?? "0") ?? 0

                let imageSlot = ImageSlot(
                    id: imageId,
                    x: x,
                    y: y,
                    width: width,
                    height: height,
                    cornerRadius: 0) // SVG rx/ry could be parsed here if needed
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
            let domDocument = svgImage.domDocument
        else {
            print("⚠️ Failed to create SVGKImage or get DOM document")
            return textSlots
        }

        // Look for text elements with IDs starting with "Text"
        for i in 1...10 {  // Support up to 10 text slots
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
                    x: x,
                    y: y,
                    width: width,
                    height: height,
                    fontSize: fontSize,
                    placeholder: placeholder as String)
                textSlots.append(textSlot)
                print("📝 Found text slot: \(textId) at (\(x), \(y)) text: '\(placeholder)'")
            }
        }

        return textSlots
    }

    // MARK: - SVG DOM Manipulation
    private func loadSVGFromFile(_ filename: String) -> String? {
        // Try loading from bundle first
        if let path = Bundle.main.path(forResource: filename, ofType: "svg"),
            let svgContent = try? String(contentsOfFile: path, encoding: .utf8)
        {
            return svgContent
        }

        // Try loading from ecard subdirectory
        if let path = Bundle.main.path(forResource: filename, ofType: "svg", inDirectory: "ecard"),
            let svgContent = try? String(contentsOfFile: path, encoding: .utf8)
        {
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
        textAssignments: [String: String] = [:]
    ) -> UIImage? {
        print(
            "🎨 ECardTemplateService: Generating ECard with \(imageAssignments.count) images using pure SVG DOM manipulation"
        )

        // Create SVGKImage from template content
        guard let svgData = template.svgContent.data(using: .utf8),
            let svgkImage = SVGKImage(data: svgData)
        else {
            print("⚠️ ECardTemplateService: Failed to create SVGKImage from template content")
            return nil
        }

        // Set the desired output size and ensure proper scaling
        svgkImage.size = size

        // Force SVGKit to scale the content to fit inside the target size
        svgkImage.scaleToFit(inside: size)

        // Get DOM document for manipulation
        guard let domDocument = svgkImage.domDocument else {
            print("⚠️ ECardTemplateService: Failed to get DOM document")
            return nil
        }

        // Calculate aspect ratio adjustment if there's exactly one image
        var yScaleFactor: Double = 1.0
        if imageAssignments.count == 1, 
           let firstImageSlot = template.imageSlots.first,
           let firstImage = imageAssignments[firstImageSlot.id] {
            
            let imageWidth = Double(firstImage.size.width)
            let imageHeight = Double(firstImage.size.height)
            
            // SVG templates are created in 100x100 coordinate system (square)
            // Adjust Y coordinates based on image aspect ratio
            // If image is 800/600 (4:3), Y scale factor should be 600/800 = 0.75
            yScaleFactor = imageHeight / imageWidth
            
            print("🎨 ECardTemplateService: Image aspect ratio adjustment - image: \(imageWidth)x\(imageHeight), Y scale factor: \(yScaleFactor)")
            
            // Apply Y coordinate scaling to all elements in the SVG DOM
            adjustSVGElementYCoordinates(domDocument: domDocument, scaleFactor: yScaleFactor)
        }

        // Update image layers in CALayer tree - works regardless of DOM element type
        if let rootLayer = svgkImage.caLayerTree {
            for slot in template.imageSlots {
                let slotId = slot.id
                if let image = imageAssignments[slotId] {

                    // Convert UIImage to PNG data for consistency
                    guard let pngData = image.pngData(),
                        let pngImage = UIImage(data: pngData)
                    else {
                        print("⚠️ Failed to convert image to PNG for slot \(slotId)")
                        continue
                    }

                    // Find the CALayer for this image slot
                    if let imageLayer = rootLayer.findLayer(byIdentifier: slotId) {
                        // Set the CGImage directly on the layer's contents
                        imageLayer.contents = pngImage.cgImage
                        print(
                            "🎨 ECardTemplateService: Set CGImage contents on CALayer for slot \(slotId)"
                        )
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
            print("🎨 ECardTemplateService: Updating text slot \(slotId) with: '\(text)'")
            
            if let textElement = domDocument.getElementById(slotId) {
                print("🎨 ECardTemplateService: Found text element \(slotId), type: \(type(of: textElement))")
                
                // Use DOM manipulation to update text content
                let elementObj = textElement as AnyObject
                
                // Try multiple approaches to ensure text is updated
                if elementObj.responds(to: Selector(("setTextContent:"))) {
                    let _ = elementObj.perform(Selector(("setTextContent:")), with: text)
                    print("✅ ECardTemplateService: Updated textContent via setTextContent: for \(slotId)")
                } else {
                    // Fallback to setValue for textContent
                    elementObj.setValue?(text, forKey: "textContent")
                    print("✅ ECardTemplateService: Updated textContent via setValue for \(slotId)")
                }
                
                // Also set innerHTML as additional backup
                elementObj.setValue?(text, forKey: "innerHTML")
                
                // Force text content refresh using nodeValue property if available
                if let firstChildValue = elementObj.value(forKey: "firstChild") {
                    (firstChildValue as AnyObject).setValue?(text, forKey: "nodeValue")
                    print("✅ ECardTemplateService: Updated nodeValue for first child of \(slotId)")
                }
                
            } else {
                print("❌ ECardTemplateService: Could not find text element with ID: \(slotId)")
                // Debug: Print all available element IDs
                debugPrintAllElementIds(domDocument: domDocument)
            }
        }
        
        // Force SVGKit to regenerate by clearing its internal caches
        // This ensures DOM changes are reflected in the rendered output
        let svgkImageObj = svgkImage as AnyObject
        
        // Try multiple cache clearing approaches
        if svgkImageObj.responds(to: Selector(("clearCache"))) {
            let _ = svgkImageObj.perform(Selector(("clearCache")))
            print("🎨 ECardTemplateService: Cleared SVGKit cache")
        }
        
        if svgkImageObj.responds(to: Selector(("invalidateCache"))) {
            let _ = svgkImageObj.perform(Selector(("invalidateCache")))
            print("🎨 ECardTemplateService: Invalidated SVGKit cache")
        }
        
        // Force re-creation of the layer tree to ensure fresh rendering
        if svgkImageObj.responds(to: Selector(("clearCALayerTree"))) {
            let _ = svgkImageObj.perform(Selector(("clearCALayerTree")))
            print("🎨 ECardTemplateService: Cleared CALayer tree for fresh rendering")
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
                rootLayer.bounds = CGRect(origin: .zero, size: size)

                // Ensure the layer contents are scaled properly
                rootLayer.contentsGravity = .resizeAspect
                //rootLayer.isGeometryFlipped = true

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

    func generateThumbnail(
        for template: ECardTemplate, size: CGSize = CGSize(width: 120, height: 150)
    ) -> UIImage? {
        print("🎨 ECardTemplateService: Generating thumbnail for template \(template.name) at size \(size)")
        
        // Generate SVG with no images or text assignments for clean template preview
        guard let baseImage = generateECardWithImages(
            template: template,
            imageAssignments: [:],
            textAssignments: [:]
        ) else {
            print("⚠️ ECardTemplateService: Failed to generate base SVG for thumbnail")
            return nil
        }
        
        // Resize the generated SVG to the requested thumbnail size if needed
        if baseImage.size != size {
            let renderer = UIGraphicsImageRenderer(size: size)
            let resizedImage = renderer.image { _ in
                baseImage.draw(in: CGRect(origin: .zero, size: size))
            }
            print("✅ ECardTemplateService: Generated and resized thumbnail to \(size)")
            return resizedImage
        }
        
        print("✅ ECardTemplateService: Generated thumbnail at native size")
        return baseImage
    }

    // MARK: - Debug Helpers
    
    private func debugPrintElementIds(element: Any, level: Int) {
        let elementObj = element as AnyObject
        let indent = String(repeating: "  ", count: level)
        
        if let elementId = elementObj.getAttribute?("id") as? String, !elementId.isEmpty {
            print("\(indent)- \(elementObj.localName ?? "unknown") id=\"\(elementId)\"")
        } else {
            print("\(indent)- \(elementObj.localName ?? "unknown") (no id)")
        }
        
        // Don't traverse children for now to avoid complexity
    }
    
    private func debugPrintAllElementIds(domDocument: Any) {
        print("🔍 ECardTemplateService: Debugging available element IDs in DOM:")
        let domDocumentObj = domDocument as AnyObject
        
        if let rootElement = domDocumentObj.rootElement {
            debugPrintElementIds(element: rootElement as Any, level: 0)
            
            // Try to find all elements with IDs
            for i in 1...10 {
                let textId = "Text\(i)"
                if let element = domDocumentObj.getElementById?(textId) {
                    let elementObj = element as AnyObject
                    let textContent = elementObj.textContent as? String ?? "no content"
                    print("  Found \(textId): '\(textContent)'")
                }
                
                let imageId = "Image\(i)"
                if let element = domDocumentObj.getElementById?(imageId) {
                    print("  Found \(imageId)")
                }
            }
        }
    }

    // MARK: - SVG Coordinate Adjustment
    
    private func adjustSVGElementYCoordinates(domDocument: Any, scaleFactor: Double) {
        // Find all elements with y coordinates and scale them
        // Using Any type for better compatibility with SVGKit's dynamic typing
        if let rootElement = (domDocument as AnyObject).rootElement {
            adjustElementYCoordinates(element: rootElement as Any, scaleFactor: scaleFactor)
        }
    }
    
    private func adjustElementYCoordinates(element: Any, scaleFactor: Double) {
        // Scale Y coordinates for various SVG elements using dynamic method calls
        let elementObj = element as AnyObject
        
        // Try to get and set Y coordinate
        if let yAttr = elementObj.getAttribute?("y") as? String, 
           let yValue = Double(yAttr) {
            let scaledY = yValue * scaleFactor
            elementObj.setAttributeNS?("http://www.w3.org/2000/svg", qualifiedName: "y", value: String(scaledY))
            print("🎨 Scaled Y coordinate: \(yValue) -> \(scaledY)")
        }
        
        // Try to get and set CY coordinate for circles
        if let cyAttr = elementObj.getAttribute?("cy") as? String,
           let cyValue = Double(cyAttr) {
            let scaledCy = cyValue * scaleFactor
            elementObj.setAttributeNS?("http://www.w3.org/2000/svg", qualifiedName: "cy", value: String(scaledCy))
            print("🎨 Scaled CY coordinate: \(cyValue) -> \(scaledCy)")
        }
        
        // Handle transforms that might contain translate Y values
        if let transformAttr = elementObj.getAttribute?("transform") as? String {
            let scaledTransform = adjustTransformYCoordinates(transform: transformAttr, scaleFactor: scaleFactor)
            if scaledTransform != transformAttr {
                elementObj.setAttributeNS?("http://www.w3.org/2000/svg", qualifiedName: "transform", value: scaledTransform)
                print("🎨 Scaled transform: \(transformAttr) -> \(scaledTransform)")
            }
        }
        
        // Skip recursive processing for now to avoid complex reflection
        // TODO: Implement child element traversal if needed for specific templates
        print("🎨 Processed element Y coordinate adjustment")
    }
    
    private func adjustTransformYCoordinates(transform: String, scaleFactor: Double) -> String {
        // Handle translate(x, y) patterns in transform attributes
        let translatePattern = #"translate\(([^,]+),\s*([^)]+)\)"#
        
        do {
            let regex = try NSRegularExpression(pattern: translatePattern, options: [])
            let nsString = transform as NSString
            let results = regex.matches(in: transform, options: [], range: NSRange(location: 0, length: nsString.length))
            
            var adjustedTransform = transform
            
            // Process matches in reverse order to maintain string positions
            for result in results.reversed() {
                if result.numberOfRanges >= 3 {
                    let xRange = result.range(at: 1)
                    let yRange = result.range(at: 2)
                    
                    let xStr = nsString.substring(with: xRange)
                    let yStr = nsString.substring(with: yRange)
                    
                    if let yValue = Double(yStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        let scaledY = yValue * scaleFactor
                        let newTranslate = "translate(\(xStr), \(scaledY))"
                        let fullRange = result.range(at: 0)
                        adjustedTransform = nsString.replacingCharacters(in: fullRange, with: newTranslate)
                    }
                }
            }
            
            return adjustedTransform
        } catch {
            print("⚠️ Error processing transform attribute: \(error)")
            return transform
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
