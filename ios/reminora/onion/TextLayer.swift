//
//  TextLayer.swift
//  reminora
//
//  Created by alexezh on 8/18/25.
//


import Foundation
import UIKit
import CoreGraphics

struct TextLayer: OnionLayer {
    let id: UUID
    var name: String
    var transform: LayerTransform
    var filters: [LayerFilter]
    var isVisible: Bool
    var zOrder: Int
    
    // Text-specific properties
    var text: String
    var fontName: String
    var fontSize: CGFloat
    var textColor: String // hex color string
    var textAlignment: TextAlignment
    var lineSpacing: CGFloat
    var letterSpacing: CGFloat
    var maxLines: Int? // nil for unlimited
    
    let layerType: LayerType = .text
    
    enum TextAlignment: String, Codable, CaseIterable {
        case left = "left"
        case center = "center"
        case right = "right"
        case justified = "justified"
        
        var displayName: String {
            switch self {
            case .left: return "Left"
            case .center: return "Center"
            case .right: return "Right"
            case .justified: return "Justified"
            }
        }
        
        var nsTextAlignment: NSTextAlignment {
            switch self {
            case .left: return .left
            case .center: return .center
            case .right: return .right
            case .justified: return .justified
            }
        }
    }
    
    init(id: UUID = UUID(), name: String = "Text Layer", transform: LayerTransform = LayerTransform()) {
        self.id = id
        self.name = name
        self.transform = transform
        self.filters = []
        self.isVisible = true
        self.zOrder = 0
        self.text = "Your text here"
        self.fontName = "Helvetica"
        self.fontSize = 24
        self.textColor = "#000000"
        self.textAlignment = .left
        self.lineSpacing = 0
        self.letterSpacing = 0
        self.maxLines = nil
    }
    
    func render(in context: CGContext, bounds: CGRect) throws {
        guard isVisible, !text.isEmpty else { return }
        
        context.saveGState()
        defer { context.restoreGState() }
        
        // Apply transform
        context.concatenate(transform.transformMatrix)
        
        // Apply opacity
        context.setAlpha(transform.opacity)
        
        // Fix text coordinate system - Core Text uses flipped coordinates
        context.translateBy(x: 0, y: transform.size.height)
        context.scaleBy(x: 1, y: -1)
        
        // Create attributed string
        let attributedString = createAttributedString()
        
        // Calculate text bounds
        let textBounds = CGRect(origin: .zero, size: transform.size)
        
        // Draw text using Core Text
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGPath(rect: textBounds, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        
        CTFrameDraw(frame, context)
    }
    
    func naturalSize() -> CGSize {
        let attributedString = createAttributedString()
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRangeMake(0, 0),
            nil,
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            nil
        )
        return size
    }
    
    func copy() -> TextLayer {
        var copy = TextLayer(
            id: UUID(),
            name: name,
            transform: transform
        )
        copy.filters = filters
        copy.isVisible = isVisible
        copy.zOrder = zOrder
        copy.text = text
        copy.fontName = fontName
        copy.fontSize = fontSize
        copy.textColor = textColor
        copy.textAlignment = textAlignment
        copy.lineSpacing = lineSpacing
        copy.letterSpacing = letterSpacing
        copy.maxLines = maxLines
        return copy
    }
    
    private func createAttributedString() -> CFAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [:]
        
        // Font
        if let font = UIFont(name: fontName, size: fontSize) {
            attributes[.font] = font
        } else {
            attributes[.font] = UIFont.systemFont(ofSize: fontSize)
        }
        
        // Color
        if let color = UIColor(hex: textColor) {
            attributes[.foregroundColor] = color
        }
        
        // Alignment (handled via paragraph style)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment.nsTextAlignment
        paragraphStyle.lineSpacing = lineSpacing
        
        if maxLines != nil {
            paragraphStyle.lineBreakMode = .byTruncatingTail
        }
        
        attributes[.paragraphStyle] = paragraphStyle
        
        // Letter spacing
        if letterSpacing != 0 {
            attributes[.kern] = letterSpacing
        }
        
        return NSAttributedString(string: text, attributes: attributes) as CFAttributedString
    }
}