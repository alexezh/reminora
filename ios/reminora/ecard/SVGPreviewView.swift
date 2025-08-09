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
            print("🎨 SVGPreviewView: onAppear - imageAssignments count: \(imageAssignments.count)")
            renderPreview()
        }
        .onChange(of: template.id) { _, _ in
            print("🎨 SVGPreviewView: template changed")
            renderPreview()
        }
        .onChange(of: imageAssignments) { oldValue, newValue in
            print("🎨 SVGPreviewView: imageAssignments changed from \(oldValue.count) to \(newValue.count)")
            renderPreview()
        }
        .onChange(of: textAssignments) { _, _ in
            print("🎨 SVGPreviewView: textAssignments changed")
            renderPreview()
        }
    }
    
    private func renderPreview() {
        isLoading = true
        print("🎨 SVGPreviewView: Starting preview render for template \(template.name)")
        print("🎨 SVGPreviewView: Image assignments count: \(imageAssignments.count)")
        print("🎨 SVGPreviewView: Image assignment keys: \(imageAssignments.keys)")
        print("🎨 SVGPreviewView: Template image slots: \(template.imageSlots.map { $0.id })")
        
        // If no image assignments, still try to render the base template
        if imageAssignments.isEmpty {
            print("🎨 SVGPreviewView: No image assignments - rendering template only")
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Pre-load assigned images for preview
            var loadedImages: [String: UIImage] = [:]
            let dispatchGroup = DispatchGroup()
            
            // Load images asynchronously
            for (slotId, asset) in self.imageAssignments {
                dispatchGroup.enter()
                print("🎨 SVGPreviewView: Loading image for slot \(slotId), asset: \(asset.localIdentifier)")
                
                // Verify the asset still exists before trying to load it
                let verifyFetch = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil)
                if verifyFetch.count == 0 {
                    print("❌ SVGPreviewView: Asset \(asset.localIdentifier) no longer exists in photo library")
                    dispatchGroup.leave()
                    continue
                }
                
                let imageManager = PHImageManager.default()
                let options = PHImageRequestOptions()
                options.deliveryMode = .opportunistic // Try fast first, then high quality
                options.resizeMode = .fast
                options.isSynchronous = false
                options.isNetworkAccessAllowed = false // All photos should be local
                options.version = .current
                
                imageManager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: 600, height: 600),
                    contentMode: .aspectFill,
                    options: options
                ) { image, info in
                    // Check if this is the final result (not degraded)
                    let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                    
                    if let image = image {
                        loadedImages[slotId] = image
                        print("✅ SVGPreviewView: Successfully loaded image for slot \(slotId) (degraded: \(isDegraded))")
                    } else {
                        print("❌ SVGPreviewView: Failed to load image for slot \(slotId)")
                        if let info = info {
                            print("   Error info: \(info)")
                            if let error = info[PHImageErrorKey] as? Error {
                                print("   Specific error: \(error.localizedDescription)")
                            }
                            if let cancelled = info[PHImageCancelledKey] as? Bool, cancelled {
                                print("   Request was cancelled")
                            }
                        }
                    }
                    
                    // Only leave the dispatch group for the final result
                    if !isDegraded {
                        print("🎯 SVGPreviewView: Final result received for slot \(slotId), leaving dispatch group")
                        dispatchGroup.leave()
                    } else {
                        print("⏳ SVGPreviewView: Degraded result for slot \(slotId), waiting for final result")
                    }
                }
            }
            
            // Once images are loaded, render the preview using SVG image resolution
            dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
                print("🎨 SVGPreviewView: All images loaded (\(loadedImages.count)), using SVG image resolution")
                print("🎨 SVGPreviewView: Loaded image keys: \(loadedImages.keys)")
                
                // Use dynamic size based on template aspect ratio
                let templateSize = self.template.svgDimensions
                let maxSize: CGFloat = 320
                let aspectRatio = templateSize.width / templateSize.height
                
                let targetSize: CGSize
                if aspectRatio > 1 {
                    targetSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
                } else {
                    targetSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
                }
                
                print("🎨 SVGPreviewView: Template size: \(templateSize), Target size: \(targetSize)")
                print("🎨 SVGPreviewView: About to call generateECardWithImages...")
                
                // Use the new image resolution approach
                let templateService = ECardTemplateService.shared
                if let svgImage = templateService.generateECardWithImages(
                    template: self.template,
                    imageAssignments: loadedImages,
                    textAssignments: self.textAssignments,
                    size: targetSize
                ) {
                    print("✅ SVGPreviewView: SVG image resolution completed successfully")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.renderedImage = svgImage
                    }
                } else {
                    print("⚠️ SVGPreviewView: SVG image resolution failed, trying basic thumbnail")
                    // Fallback to basic thumbnail if image resolution fails
                    if let basicSvgImage = templateService.generateThumbnail(for: self.template, size: targetSize) {
                        print("✅ SVGPreviewView: Basic SVG thumbnail succeeded")
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.renderedImage = basicSvgImage
                        }
                    } else {
                        print("⚠️ SVGPreviewView: All SVG rendering failed, creating fallback")
                        // Final fallback
                        let renderer = UIGraphicsImageRenderer(size: targetSize)
                        let fallbackImage = renderer.image { context in
                            let cgContext = context.cgContext
                            
                            // White background
                            cgContext.setFillColor(UIColor.white.cgColor)
                            cgContext.fill(CGRect(origin: .zero, size: targetSize))
                            
                            // Draw template name
                            let text = self.template.name
                            let font = UIFont.systemFont(ofSize: 16, weight: .medium)
                            let attributes: [NSAttributedString.Key: Any] = [
                                .font: font,
                                .foregroundColor: UIColor.systemGray,
                            ]
                            let textSize = text.size(withAttributes: attributes)
                            let textRect = CGRect(
                                x: targetSize.width/2 - textSize.width/2,
                                y: targetSize.height/2 - textSize.height/2,
                                width: textSize.width,
                                height: textSize.height
                            )
                            text.draw(in: textRect, withAttributes: attributes)
                        }
                        
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.renderedImage = fallbackImage
                            print("✅ SVGPreviewView: Fallback preview completed")
                        }
                    }
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
