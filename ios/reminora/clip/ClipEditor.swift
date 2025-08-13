//
//  ClipEditor.swift
//  reminora
//
//  Created by Claude on 8/10/25.
//

import Foundation
import Photos
import SwiftUI
import AVFoundation

// MARK: - Clip Editor State Manager

class ClipEditor: ObservableObject {
    @Published var isActive: Bool = false
    @Published var currentClip: Clip?
    @Published var currentAssets: [PHAsset] = []
    @Published var isGenerating: Bool = false
    @Published var generationProgress: Float = 0.0
    
    static let shared = ClipEditor()
    
    private let userDefaults = UserDefaults.standard
    private let currentClipIdKey = "ClipEditor.currentClipId"
    private let isActiveKey = "ClipEditor.isActive"
    
    private init() {
        loadPersistedState()
    }
    
    // MARK: - Public Interface
    
    /// Start clip editing session with assets
    func startEditing(with assets: [PHAsset]) {
        DispatchQueue.main.async {
            let clipName = ClipManager.shared.createClipName(from: assets)
            let newClip = Clip(name: clipName, assets: assets)
            
            self.currentClip = newClip
            self.currentAssets = assets
            self.isActive = true
            self.persistState()
            
            // Set the current editor in ActionSheet model
            UniversalActionSheetModel.shared.setCurrentEditor(.clip)
            
            print("📹 ClipEditor: Started editing with \(assets.count) assets")
        }
    }
    
    /// Continue editing existing clip
    func startEditing(clip: Clip) {
        DispatchQueue.main.async {
            self.currentClip = clip
            self.currentAssets = clip.getAssets()
            self.isActive = true
            self.persistState()
            
            // Set the current editor in ActionSheet model
            UniversalActionSheetModel.shared.setCurrentEditor(.clip)
            
            print("📹 ClipEditor: Started editing existing clip '\(clip.name)'")
        }
    }
    
    /// End clip editing session
    func endEditing() {
        DispatchQueue.main.async {
            self.currentClip = nil
            self.currentAssets = []
            self.isActive = false
            self.isGenerating = false
            self.generationProgress = 0.0
            self.clearPersistedState()
            
            // Clear the current editor in ActionSheet model
            UniversalActionSheetModel.shared.setCurrentEditor(nil)
            
            print("📹 ClipEditor: Ended editing session")
        }
    }
    
    /// Check if currently editing
    var hasActiveSession: Bool {
        return isActive && currentClip != nil
    }
    
    /// Save current clip
    func saveClip() {
        guard var clip = currentClip else { return }
        
        DispatchQueue.main.async {
            clip.assetIdentifiers = self.currentAssets.map { $0.localIdentifier }
            clip.markAsModified()
            
            ClipManager.shared.updateClip(clip)
            self.currentClip = clip
            self.persistState()
            
            print("📹 ClipEditor: Saved clip '\(clip.name)'")
        }
    }
    
    /// Update clip settings
    func updateClip(name: String? = nil, duration: TimeInterval? = nil, transition: ClipTransition? = nil, orientation: ClipOrientation? = nil, effect: ClipEffect? = nil, audioTrack: AudioTrack? = nil) {
        guard var clip = currentClip else { return }
        
        DispatchQueue.main.async {
            if let name = name { clip.name = name }
            if let duration = duration { clip.duration = duration }
            if let transition = transition { clip.transition = transition }
            if let orientation = orientation { clip.orientation = orientation }
            if let effect = effect { clip.effect = effect }
            if let audioTrack = audioTrack { clip.audioTrack = audioTrack }
            
            clip.markAsModified()
            self.currentClip = clip
            self.saveClip()
        }
    }
    
    /// Add assets to current clip
    func addAssets(_ assets: [PHAsset]) {
        DispatchQueue.main.async {
            self.currentAssets.append(contentsOf: assets)
            self.saveClip()
            print("📹 ClipEditor: Added \(assets.count) assets to clip")
        }
    }
    
    /// Remove asset from current clip
    func removeAsset(at index: Int) {
        DispatchQueue.main.async {
            guard index < self.currentAssets.count else { return }
            self.currentAssets.remove(at: index)
            self.saveClip()
            print("📹 ClipEditor: Removed asset at index \(index)")
        }
    }
    
    /// Reorder assets in current clip
    func moveAsset(from sourceIndex: Int, to destinationIndex: Int) {
        DispatchQueue.main.async {
            guard sourceIndex < self.currentAssets.count && destinationIndex < self.currentAssets.count else { return }
            let asset = self.currentAssets.remove(at: sourceIndex)
            self.currentAssets.insert(asset, at: destinationIndex)
            self.saveClip()
            print("📹 ClipEditor: Moved asset from \(sourceIndex) to \(destinationIndex)")
        }
    }
    
    // MARK: - Video Generation
    
    /// Generate video from current clip
    func generateVideo(completion: @escaping (Result<URL, Error>) -> Void) {
        guard let clip = currentClip else {
            completion(.failure(ClipError.noClip))
            return
        }
        
        guard !currentAssets.isEmpty else {
            completion(.failure(ClipError.noAssets))
            return
        }
        
        DispatchQueue.main.async {
            self.isGenerating = true
            self.generationProgress = 0.0
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.createVideoFromAssets(clip: clip, completion: completion)
        }
    }
    
    private func createVideoFromAssets(clip: Clip, completion: @escaping (Result<URL, Error>) -> Void) {
        // Create temporary output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip_\(clip.id.uuidString).mp4")
        
        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: outputURL)
        
        // Create AVAssetWriter
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            DispatchQueue.main.async {
                self.isGenerating = false
                completion(.failure(ClipError.videoCreationFailed))
            }
            return
        }
        
        // Video settings based on orientation
        let videoSize = clip.orientation.videoSize
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2000000
            ]
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
            ]
        )
        
        writer.add(writerInput)
        
        // TODO: Add audio track if present
        if let audioTrack = clip.audioTrack {
            // Placeholder for audio mixing
            // Full implementation would require AVMutableComposition
            // and AVAssetWriter with multiple inputs
            print("📹 Audio track will be added: \(audioTrack.displayName)")
        }
        
        // Start writing
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        let dispatchGroup = DispatchGroup()
        var currentTime = CMTime.zero
        let frameDuration = CMTime(seconds: clip.duration, preferredTimescale: 600)
        
        for (index, asset) in currentAssets.enumerated() {
            dispatchGroup.enter()
            
            // Load image from asset
            let imageManager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = true
            
            imageManager.requestImage(
                for: asset,
                targetSize: videoSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                defer { dispatchGroup.leave() }
                
                guard let image = image else { return }
                
                // Apply effects to image if needed
                let processedImage = self.applyEffect(to: image, effect: clip.effect)
                
                // Create pixel buffer from image with proper orientation
                guard let pixelBuffer = self.createPixelBuffer(from: processedImage, size: videoSize) else {
                    return
                }
                
                // Wait for writer input to be ready
                while !writerInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.01)
                }
                
                // Append pixel buffer
                adaptor.append(pixelBuffer, withPresentationTime: currentTime)
                currentTime = CMTimeAdd(currentTime, frameDuration)
                
                DispatchQueue.main.async {
                    self.generationProgress = Float(index + 1) / Float(self.currentAssets.count)
                }
            }
        }
        
        dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
            // Finish writing
            writerInput.markAsFinished()
            writer.finishWriting {
                DispatchQueue.main.async {
                    self.isGenerating = false
                    self.generationProgress = 0.0
                    
                    if writer.status == .completed {
                        completion(.success(outputURL))
                    } else {
                        completion(.failure(writer.error ?? ClipError.videoCreationFailed))
                    }
                }
            }
        }
    }
    
    private func createPixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }
        
        // Set proper orientation - NO FLIPPING for correct video orientation
        // Just draw the image directly without transformations
        
        // Calculate aspect fit/crop rectangle to preserve aspect ratio
        let imageSize = image.size
        let imageAspectRatio = imageSize.width / imageSize.height
        let targetAspectRatio = size.width / size.height
        
        let drawRect: CGRect
        if imageAspectRatio > targetAspectRatio {
            // Image is wider than target - crop sides
            let newWidth = size.height * imageAspectRatio
            let xOffset = (size.width - newWidth) / 2
            drawRect = CGRect(x: xOffset, y: 0, width: newWidth, height: size.height)
        } else {
            // Image is taller than target - crop top/bottom
            let newHeight = size.width / imageAspectRatio
            let yOffset = (size.height - newHeight) / 2
            drawRect = CGRect(x: 0, y: yOffset, width: size.width, height: newHeight)
        }
        
        // Draw image with proper orientation handling
        if let cgImage = image.cgImage {
            // Handle image orientation properly
            context.saveGState()
            
            // Apply transformations based on image orientation
            switch image.imageOrientation {
            case .up:
                break // No transformation needed
            case .down:
                context.translateBy(x: size.width, y: size.height)
                context.rotate(by: .pi)
            case .left:
                context.translateBy(x: size.width, y: 0)
                context.rotate(by: .pi / 2)
            case .right:
                context.translateBy(x: 0, y: size.height)
                context.rotate(by: -.pi / 2)
            case .upMirrored:
                context.translateBy(x: size.width, y: 0)
                context.scaleBy(x: -1, y: 1)
            case .downMirrored:
                context.translateBy(x: 0, y: size.height)
                context.scaleBy(x: -1, y: 1)
            case .leftMirrored:
                context.translateBy(x: size.width, y: size.height)
                context.rotate(by: -.pi / 2)
                context.scaleBy(x: -1, y: 1)
            case .rightMirrored:
                context.rotate(by: .pi / 2)
                context.scaleBy(x: -1, y: 1)
            @unknown default:
                break
            }
            
            context.draw(cgImage, in: drawRect)
            context.restoreGState()
        }
        
        return buffer
    }
    
    private func applyEffect(to image: UIImage, effect: ClipEffect) -> UIImage {
        guard effect != .none else { return image }
        
        guard let ciImage = CIImage(image: image) else { return image }
        
        let context = CIContext()
        var filteredImage = ciImage
        
        switch effect {
        case .none:
            break
            
        case .blackAndWhite:
            if let filter = CIFilter(name: "CIColorMonochrome") {
                filter.setValue(filteredImage, forKey: kCIInputImageKey)
                filter.setValue(CIColor.gray, forKey: kCIInputColorKey)
                filter.setValue(1.0, forKey: kCIInputIntensityKey)
                filteredImage = filter.outputImage ?? filteredImage
            }
            
        case .sepia:
            if let filter = CIFilter(name: "CISepiaTone") {
                filter.setValue(filteredImage, forKey: kCIInputImageKey)
                filter.setValue(0.8, forKey: kCIInputIntensityKey)
                filteredImage = filter.outputImage ?? filteredImage
            }
            
        case .vintage:
            // Apply multiple filters for vintage look
            if let sepiaFilter = CIFilter(name: "CISepiaTone") {
                sepiaFilter.setValue(filteredImage, forKey: kCIInputImageKey)
                sepiaFilter.setValue(0.5, forKey: kCIInputIntensityKey)
                filteredImage = sepiaFilter.outputImage ?? filteredImage
            }
            
            if let vignetteFilter = CIFilter(name: "CIVignette") {
                vignetteFilter.setValue(filteredImage, forKey: kCIInputImageKey)
                vignetteFilter.setValue(0.8, forKey: kCIInputIntensityKey)
                vignetteFilter.setValue(1.5, forKey: kCIInputRadiusKey)
                filteredImage = vignetteFilter.outputImage ?? filteredImage
            }
            
        case .dramatic:
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(filteredImage, forKey: kCIInputImageKey)
                filter.setValue(1.3, forKey: kCIInputContrastKey)
                filter.setValue(0.1, forKey: kCIInputBrightnessKey)
                filter.setValue(1.2, forKey: kCIInputSaturationKey)
                filteredImage = filter.outputImage ?? filteredImage
            }
            
        case .vivid:
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(filteredImage, forKey: kCIInputImageKey)
                filter.setValue(1.0, forKey: kCIInputContrastKey)
                filter.setValue(0.1, forKey: kCIInputBrightnessKey)
                filter.setValue(1.5, forKey: kCIInputSaturationKey)
                filteredImage = filter.outputImage ?? filteredImage
            }
            
        case .noir:
            if let monoFilter = CIFilter(name: "CIColorMonochrome") {
                monoFilter.setValue(filteredImage, forKey: kCIInputImageKey)
                monoFilter.setValue(CIColor.black, forKey: kCIInputColorKey)
                monoFilter.setValue(1.0, forKey: kCIInputIntensityKey)
                filteredImage = monoFilter.outputImage ?? filteredImage
            }
            
            if let contrastFilter = CIFilter(name: "CIColorControls") {
                contrastFilter.setValue(filteredImage, forKey: kCIInputImageKey)
                contrastFilter.setValue(1.5, forKey: kCIInputContrastKey)
                contrastFilter.setValue(-0.2, forKey: kCIInputBrightnessKey)
                filteredImage = contrastFilter.outputImage ?? filteredImage
            }
            
        case .warm:
            if let filter = CIFilter(name: "CITemperatureAndTint") {
                filter.setValue(filteredImage, forKey: kCIInputImageKey)
                filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                filter.setValue(CIVector(x: 7000, y: 200), forKey: "inputTargetNeutral")
                filteredImage = filter.outputImage ?? filteredImage
            }
            
        case .cool:
            if let filter = CIFilter(name: "CITemperatureAndTint") {
                filter.setValue(filteredImage, forKey: kCIInputImageKey)
                filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
                filter.setValue(CIVector(x: 5500, y: -200), forKey: "inputTargetNeutral")
                filteredImage = filter.outputImage ?? filteredImage
            }
        }
        
        // Convert back to UIImage
        guard let cgImage = context.createCGImage(filteredImage, from: filteredImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Persistence
    
    private func persistState() {
        userDefaults.set(isActive, forKey: isActiveKey)
        if let clipId = currentClip?.id {
            userDefaults.set(clipId.uuidString, forKey: currentClipIdKey)
        } else {
            userDefaults.removeObject(forKey: currentClipIdKey)
        }
    }
    
    private func loadPersistedState() {
        let wasActive = userDefaults.bool(forKey: isActiveKey)
        guard wasActive else { return }
        
        guard let clipIdString = userDefaults.string(forKey: currentClipIdKey),
              let clipId = UUID(uuidString: clipIdString),
              let clip = ClipManager.shared.getClip(id: clipId) else {
            clearPersistedState()
            return
        }
        
        DispatchQueue.main.async {
            self.currentClip = clip
            self.currentAssets = clip.getAssets()
            self.isActive = true
            
            // Restore editor state in ActionSheet model
            UniversalActionSheetModel.shared.setCurrentEditor(.clip)
            
            print("📹 ClipEditor: Restored editing session for clip '\(clip.name)'")
        }
    }
    
    private func clearPersistedState() {
        userDefaults.removeObject(forKey: currentClipIdKey)
        userDefaults.removeObject(forKey: isActiveKey)
    }
}

// MARK: - Clip Errors

enum ClipError: LocalizedError {
    case noClip
    case noAssets
    case videoCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .noClip:
            return "No clip selected"
        case .noAssets:
            return "No images in clip"
        case .videoCreationFailed:
            return "Failed to create video"
        }
    }
}

// MARK: - Environment Integration

private struct ClipEditorKey: EnvironmentKey {
    static let defaultValue = ClipEditor.shared
}

extension EnvironmentValues {
    var clipEditor: ClipEditor {
        get { self[ClipEditorKey.self] }
        set { self[ClipEditorKey.self] = newValue }
    }
}