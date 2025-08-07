//
//  SVGPreviewView.swift
//  reminora
//
//  Created by alexezh on 8/7/25.
//


import SwiftUI
import Photos
import WebKit

// MARK: - SVG Preview View
struct SVGPreviewView: View {
    let template: ECardTemplate
    let imageAssignments: [String: PHAsset]
    let textAssignments: [String: String]
    let onImageSlotTapped: (ImageSlot) -> Void
    let onTextSlotTapped: (TextSlot) -> Void
    
    @State private var renderedImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            if let renderedImage = renderedImage {
                // Show the actual rendered SVG
                Image(uiImage: renderedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onTapGesture { coordinate in
                        handleTap(at: coordinate)
                    }
            } else {
                // Loading state
                Rectangle()
                    .fill(Color.white)
                    .overlay(
                        VStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Rendering...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.top, 8)
                            } else {
                                Text(template.name)
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        }
                    )
            }
        }
        .onAppear {
            renderPreview()
        }
        .onChange(of: template.id) { _, _ in
            renderPreview()
        }
        .onChange(of: imageAssignments) { _, _ in
            renderPreview()
        }
        .onChange(of: textAssignments) { _, _ in
            renderPreview()
        }
    }
    
    private func renderPreview() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Pre-load assigned images for preview
            var loadedImages: [String: UIImage] = [:]
            let dispatchGroup = DispatchGroup()
            
            // Load images asynchronously
            for (slotId, asset) in self.imageAssignments {
                dispatchGroup.enter()
                
                let imageManager = PHImageManager.default()
                let options = PHImageRequestOptions()
                options.deliveryMode = .fastFormat
                options.resizeMode = .fast
                options.isSynchronous = false
                
                imageManager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: 400, height: 300),
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    if let image = image {
                        loadedImages[slotId] = image
                    }
                    dispatchGroup.leave()
                }
            }
            
            // Once images are loaded, render the preview
            dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
                let targetSize = CGSize(width: 320, height: 400) // Preview size
                
                // Use manual rendering for preview (more reliable than SVGKit for preview)
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                let previewImage = renderer.image { context in
                    let cgContext = context.cgContext
                    
                    // White background
                    cgContext.setFillColor(UIColor.white.cgColor)
                    cgContext.fill(CGRect(origin: .zero, size: targetSize))
                    
                    // Calculate scale factor from template dimensions to preview size
                    let templateSize = self.template.svgDimensions
                    let scaleX = targetSize.width / templateSize.width
                    let scaleY = targetSize.height / templateSize.height
                    let scale = min(scaleX, scaleY)
                    
                    // Center the content
                    let scaledWidth = templateSize.width * scale
                    let scaledHeight = templateSize.height * scale
                    let offsetX = (targetSize.width - scaledWidth) / 2
                    let offsetY = (targetSize.height - scaledHeight) / 2
                    
                    cgContext.translateBy(x: offsetX, y: offsetY)
                    cgContext.scaleBy(x: scale, y: scale)
                    
                    // Draw assigned images
                    for slot in self.template.imageSlots {
                        if let image = loadedImages[slot.id] {
                            let imageRect = CGRect(x: slot.x, y: slot.y, width: slot.width, height: slot.height)
                            
                            // Save context for clipping
                            cgContext.saveGState()
                            if slot.cornerRadius > 0 {
                                let path = UIBezierPath(roundedRect: imageRect, cornerRadius: slot.cornerRadius)
                                cgContext.addPath(path.cgPath)
                                cgContext.clip()
                            }
                            
                            // Draw image with aspect fill
                            image.draw(in: imageRect)
                            cgContext.restoreGState()
                        } else {
                            // Draw placeholder
                            let imageRect = CGRect(x: slot.x, y: slot.y, width: slot.width, height: slot.height)
                            cgContext.setFillColor(UIColor.systemGray5.cgColor)
                            cgContext.fill(imageRect)
                            
                            // Draw placeholder icon
                            let iconSize: CGFloat = min(imageRect.width, imageRect.height) * 0.3
                            let iconRect = CGRect(
                                x: imageRect.midX - iconSize/2,
                                y: imageRect.midY - iconSize/2,
                                width: iconSize,
                                height: iconSize
                            )
                            
                            // Draw simple camera icon placeholder
                            cgContext.setFillColor(UIColor.systemGray3.cgColor)
                            cgContext.fillEllipse(in: iconRect)
                        }
                    }
                    
                    // Draw text slots
                    for slot in self.template.textSlots {
                        let text = self.textAssignments[slot.id] ?? slot.placeholder
                        let textRect = CGRect(x: slot.x, y: slot.y, width: slot.width, height: slot.height)
                        
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.alignment = slot.textAlign == .center ? .center : (slot.textAlign == .right ? .right : .left)
                        
                        text.draw(in: textRect, withAttributes: [
                            .font: UIFont.systemFont(ofSize: slot.fontSize),
                            .foregroundColor: UIColor.black,
                            .paragraphStyle: paragraphStyle
                        ])
                    }
                }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.renderedImage = previewImage
                }
            }
        }
    }
    
    private func handleTap(at location: CGPoint) {
        // Convert tap coordinates to SVG coordinates and find the appropriate slot
        // This is a simplified implementation - in a real app you'd need proper coordinate transformation
        
        // For now, just trigger the first image slot when tapped in the upper area
        // and text slot when tapped in the lower area
        let normalizedY = location.y / 375.0 // Assuming 375 height
        
        if normalizedY < 0.7 { // Upper area - image slots
            if let firstImageSlot = template.imageSlots.first {
                onImageSlotTapped(firstImageSlot)
            }
        } else { // Lower area - text slots
            if let firstTextSlot = template.textSlots.first {
                onTextSlotTapped(firstTextSlot)
            }
        }
    }
}
