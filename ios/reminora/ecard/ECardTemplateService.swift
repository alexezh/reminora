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
                    id: imageId)
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
                    id: textId)
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
        textAssignments: [String: String] = [:],
        size: CGSize = CGSize(width: 800, height: 1000)
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
                print(
                    "🎨 ECardTemplateService: Element \(slotId) is not SVGTextElement, type: \(type(of: textElement))"
                )
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
        // Use the same improved rendering approach as ECard generation
        return generateECardWithImages(
            template: template,
            imageAssignments: [:],
            textAssignments: [:],
            size: size
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
