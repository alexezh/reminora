//
//  OnionRenderer.swift
//  reminora
//
//  Created by Claude on 8/17/25.
//

import Foundation
import UIKit
import CoreGraphics
import CoreImage
import SwiftUI

// MARK: - Rendering Configuration

struct OnionRenderConfig {
    let size: CGSize
    let scale: CGFloat
    let backgroundColor: UIColor
    let quality: RenderQuality
    let format: RenderFormat
    
    enum RenderQuality: String, CaseIterable {
        case preview = "preview"     // Low quality, fast rendering
        case standard = "standard"   // Standard quality
        case high = "high"          // High quality, slower rendering
        case print = "print"        // Print quality, highest resolution
        
        var displayName: String {
            switch self {
            case .preview: return "Preview"
            case .standard: return "Standard"
            case .high: return "High Quality"
            case .print: return "Print Quality"
            }
        }
        
        var scaleFactor: CGFloat {
            switch self {
            case .preview: return 0.5
            case .standard: return 1.0
            case .high: return 2.0
            case .print: return 3.0
            }
        }
        
        var compressionQuality: CGFloat {
            switch self {
            case .preview: return 0.6
            case .standard: return 0.8
            case .high: return 0.9
            case .print: return 0.95
            }
        }
    }
    
    enum RenderFormat: String, CaseIterable {
        case jpeg = "jpeg"
        case png = "png"
        case heic = "heic"
        
        var displayName: String {
            switch self {
            case .jpeg: return "JPEG"
            case .png: return "PNG"
            case .heic: return "HEIC"
            }
        }
        
        var supportsTransparency: Bool {
            switch self {
            case .jpeg, .heic: return false
            case .png: return true
            }
        }
    }
    
    init(scene: OnionScene, quality: RenderQuality = .standard, format: RenderFormat = .jpeg) {
        self.size = scene.size
        self.scale = quality.scaleFactor * UIScreen.main.scale
        self.backgroundColor = UIColor(hex: scene.backgroundColor) ?? .white
        self.quality = quality
        self.format = format
    }
    
    init(size: CGSize, quality: RenderQuality = .standard, format: RenderFormat = .jpeg, backgroundColor: UIColor = .white) {
        self.size = size
        self.scale = quality.scaleFactor * UIScreen.main.scale
        self.backgroundColor = backgroundColor
        self.quality = quality
        self.format = format
    }
    
    var renderSize: CGSize {
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

// MARK: - Rendering Result

struct OnionRenderResult {
    let image: UIImage
    let data: Data
    let config: OnionRenderConfig
    let renderTime: TimeInterval
    let statistics: RenderStatistics
    
    struct RenderStatistics {
        let totalLayers: Int
        var visibleLayers: Int
        var skippedLayers: Int
        var filterApplications: Int
        var memoryUsage: Int64 // bytes
        let renderSize: CGSize
    }
}

// MARK: - Rendering Errors

enum OnionRenderError: LocalizedError {
    case invalidScene
    case invalidLayer(UUID)
    case renderingFailed(String)
    case imageConversionFailed
    case insufficientMemory
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidScene:
            return "Invalid scene configuration"
        case .invalidLayer(let id):
            return "Invalid layer: \(id)"
        case .renderingFailed(let message):
            return "Rendering failed: \(message)"
        case .imageConversionFailed:
            return "Failed to convert rendered image"
        case .insufficientMemory:
            return "Insufficient memory for rendering"
        case .cancelled:
            return "Rendering was cancelled"
        }
    }
}

// MARK: - Onion Renderer

class OnionRenderer: ObservableObject {
    static let shared = OnionRenderer()
    
    @Published var isRendering: Bool = false
    @Published var renderProgress: Float = 0.0
    @Published var currentOperation: String = ""
    
    private var renderTasks: [UUID: Task<OnionRenderResult, Error>] = [:]
    private let renderQueue = DispatchQueue(label: "com.reminora.onion.render", qos: .userInitiated)
    private let taskLock = NSLock()
    
    private init() {}
    
    // MARK: - Public Rendering Interface
    
    /// Render scene to UIImage for preview
    func renderPreview(scene: OnionScene) async throws -> UIImage {
        let config = OnionRenderConfig(scene: scene, quality: .preview)
        let result = try await render(scene: scene, config: config)
        return result.image
    }
    
    /// Render scene to high-quality image data
    func renderHighQuality(scene: OnionScene, format: OnionRenderConfig.RenderFormat = .jpeg) async throws -> OnionRenderResult {
        let config = OnionRenderConfig(scene: scene, quality: .high, format: format)
        return try await render(scene: scene, config: config)
    }
    
    /// Render scene with custom configuration
    func render(scene: OnionScene, config: OnionRenderConfig) async throws -> OnionRenderResult {
        let taskId = UUID()
        
        return try await withTaskCancellationHandler {
            let task = Task {
                return try await performRender(scene: scene, config: config, taskId: taskId)
            }
            
            taskLock.lock()
            renderTasks[taskId] = task
            taskLock.unlock()
            
            defer {
                taskLock.lock()
                renderTasks.removeValue(forKey: taskId)
                taskLock.unlock()
            }
            
            return try await task.value
        } onCancel: {
            Task {
                taskLock.lock()
                renderTasks[taskId]?.cancel()
                renderTasks.removeValue(forKey: taskId)
                taskLock.unlock()
            }
        }
    }
    
    /// Cancel all ongoing renders
    func cancelAllRenders() {
        DispatchQueue.main.async {
            self.taskLock.lock()
            for task in self.renderTasks.values {
                task.cancel()
            }
            self.renderTasks.removeAll()
            self.taskLock.unlock()
            self.isRendering = false
            self.renderProgress = 0.0
            self.currentOperation = ""
        }
    }
    
    // MARK: - Core Rendering Implementation
    
    private func performRender(scene: OnionScene, config: OnionRenderConfig, taskId: UUID) async throws -> OnionRenderResult {
        let startTime = Date()
        
        await updateProgress(0.0, operation: "Preparing render...")
        
        // Validate scene
        guard !scene.layers.isEmpty else {
            throw OnionRenderError.invalidScene
        }
        
        // Check for cancellation
        try Task.checkCancellation()
        
        await updateProgress(0.1, operation: "Creating render context...")
        
        // Create graphics context
        let renderSize = config.renderSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = config.scale
        format.opaque = !config.format.supportsTransparency
        format.preferredRange = .extended
        
        let renderer = UIGraphicsImageRenderer(size: config.size, format: format)
        
        // Prepare statistics
        var statistics = OnionRenderResult.RenderStatistics(
            totalLayers: scene.layers.count,
            visibleLayers: 0,
            skippedLayers: 0,
            filterApplications: 0,
            memoryUsage: 0,
            renderSize: renderSize
        )
        
        await updateProgress(0.2, operation: "Rendering layers...")
        
        // Render image
        let image = try renderer.image { context in
            let cgContext = context.cgContext
            
            // Set background
            cgContext.setFillColor(config.backgroundColor.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: config.size))
            
            // Sort layers by z-order
            let sortedLayers = scene.layers.sorted { $0.zOrder < $1.zOrder }
            
            // Render each layer
            for (index, layer) in sortedLayers.enumerated() {
                do {
                    if Task.isCancelled {
                        throw OnionRenderError.cancelled
                    }
                    
                    if layer.isVisible {
                        try self.renderLayer(layer, in: cgContext, bounds: CGRect(origin: .zero, size: config.size), config: config)
                        statistics.visibleLayers += 1
                        statistics.filterApplications += layer.filters.count
                    } else {
                        statistics.skippedLayers += 1
                    }
                    
                    // Update progress
                    let progress = 0.2 + (0.6 * Float(index + 1) / Float(sortedLayers.count))
                    Task {
                        await self.updateProgress(progress, operation: "Rendering layer \(index + 1) of \(sortedLayers.count)")
                    }
                    
                } catch {
                    print("⚠️ OnionRenderer: Failed to render layer \(layer.id): \(error)")
                    statistics.skippedLayers += 1
                }
            }
        }
        
        await updateProgress(0.8, operation: "Converting to output format...")
        
        // Convert to data
        let imageData: Data
        switch config.format {
        case .jpeg:
            guard let data = image.jpegData(compressionQuality: config.quality.compressionQuality) else {
                throw OnionRenderError.imageConversionFailed
            }
            imageData = data
            
        case .png:
            guard let data = image.pngData() else {
                throw OnionRenderError.imageConversionFailed
            }
            imageData = data
            
        case .heic:
            // HEIC conversion would require additional implementation
            guard let data = image.jpegData(compressionQuality: config.quality.compressionQuality) else {
                throw OnionRenderError.imageConversionFailed
            }
            imageData = data
        }
        
        await updateProgress(0.9, operation: "Finalizing...")
        
        // Calculate memory usage estimate
        statistics.memoryUsage = Int64(renderSize.width * renderSize.height * 4) // 4 bytes per pixel
        
        let renderTime = Date().timeIntervalSince(startTime)
        
        await updateProgress(1.0, operation: "Complete")
        
        print("🧅 OnionRenderer: Rendered scene '\(scene.name)' in \(String(format: "%.2f", renderTime))s")
        print("🧅 OnionRenderer: \(statistics.visibleLayers) visible layers, \(statistics.skippedLayers) skipped")
        print("🧅 OnionRenderer: Output size: \(renderSize), Memory: \(statistics.memoryUsage / 1024 / 1024)MB")
        
        return OnionRenderResult(
            image: image,
            data: imageData,
            config: config,
            renderTime: renderTime,
            statistics: statistics
        )
    }
    
    // MARK: - Layer Rendering
    
    private func renderLayer(_ layer: AnyOnionLayer, in context: CGContext, bounds: CGRect, config: OnionRenderConfig) throws {
        context.saveGState()
        defer { context.restoreGState() }
        
        try layer.render(in: context, bounds: bounds)
        
        // Apply filters if any
        if !layer.filters.isEmpty {
            // Filter application would require additional Core Image integration
            // For now, we skip filter application in the renderer
        }
    }
    
    // MARK: - Progress Tracking
    
    @MainActor
    private func updateProgress(_ progress: Float, operation: String) {
        isRendering = progress < 1.0
        renderProgress = progress
        currentOperation = operation
    }
    
    // MARK: - Utility Functions
    
    /// Get recommended render size for target use case
    static func recommendedSize(for useCase: RenderUseCase, baseSize: CGSize) -> CGSize {
        let scale = useCase.recommendedScale
        return CGSize(width: baseSize.width * scale, height: baseSize.height * scale)
    }
    
    /// Get memory estimate for rendering configuration
    static func estimateMemoryUsage(config: OnionRenderConfig) -> Int64 {
        let renderSize = config.renderSize
        return Int64(renderSize.width * renderSize.height * 4) // 4 bytes per pixel (RGBA)
    }
    
    /// Check if device can handle rendering configuration
    static func canRender(config: OnionRenderConfig) -> Bool {
        let estimatedMemory = estimateMemoryUsage(config: config)
        let availableMemory = ProcessInfo.processInfo.physicalMemory / 4 // Use 25% of device memory as limit
        return estimatedMemory < Int64(availableMemory)
    }
}

// MARK: - Render Use Cases

enum RenderUseCase: String, CaseIterable {
    case thumbnail = "thumbnail"
    case preview = "preview"
    case share = "share"
    case export = "export"
    case print = "print"
    
    var displayName: String {
        switch self {
        case .thumbnail: return "Thumbnail"
        case .preview: return "Preview"
        case .share: return "Share"
        case .export: return "Export"
        case .print: return "Print"
        }
    }
    
    var recommendedScale: CGFloat {
        switch self {
        case .thumbnail: return 0.25
        case .preview: return 0.5
        case .share: return 1.0
        case .export: return 2.0
        case .print: return 3.0
        }
    }
    
    var recommendedQuality: OnionRenderConfig.RenderQuality {
        switch self {
        case .thumbnail, .preview: return .preview
        case .share: return .standard
        case .export: return .high
        case .print: return .print
        }
    }
    
    var recommendedFormat: OnionRenderConfig.RenderFormat {
        switch self {
        case .thumbnail, .preview, .share: return .jpeg
        case .export, .print: return .png
        }
    }
}

// MARK: - Environment Integration

private struct OnionRendererKey: EnvironmentKey {
    static let defaultValue = OnionRenderer.shared
}

extension EnvironmentValues {
    var onionRenderer: OnionRenderer {
        get { self[OnionRendererKey.self] }
        set { self[OnionRendererKey.self] = newValue }
    }
}