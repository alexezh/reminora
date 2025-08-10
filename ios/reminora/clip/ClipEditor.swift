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
    func updateClip(name: String? = nil, duration: TimeInterval? = nil, transition: ClipTransition? = nil) {
        guard var clip = currentClip else { return }
        
        DispatchQueue.main.async {
            if let name = name { clip.name = name }
            if let duration = duration { clip.duration = duration }
            if let transition = transition { clip.transition = transition }
            
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
        
        // Video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1080,
            AVVideoHeightKey: 1080,
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
                targetSize: CGSize(width: 1080, height: 1080),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                defer { dispatchGroup.leave() }
                
                guard let image = image else { return }
                
                // Create pixel buffer from image
                guard let pixelBuffer = self.createPixelBuffer(from: image, size: CGSize(width: 1080, height: 1080)) else {
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
        
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        let rect = CGRect(origin: .zero, size: size)
        context.draw(image.cgImage!, in: rect)
        
        return buffer
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