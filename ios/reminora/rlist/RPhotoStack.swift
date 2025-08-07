//
//  RPhotoStack.swift
//  reminora
//
//  Created by Claude on 8/4/25.
//

import Foundation
import Photos
import UIKit
import SwiftUI

// MARK: - RPhotoStack Class
class RPhotoStack: ObservableObject, Identifiable {
    let id: String
    let assets: [PHAsset]
    let creationDate: Date
    
    @Published var images: [UIImage?] = []
    @Published var isLoading = false
    
    // MARK: - Computed Properties
    
    /// Returns true if this stack contains only one photo
    var isSinglePhoto: Bool {
        return assets.count == 1
    }
    
    /// Returns true if this contains multiple photos (compatibility with PhotoStack)
    var isStack: Bool {
        return assets.count > 1
    }
    
    /// Returns the primary (first) asset in the stack
    var primaryAsset: PHAsset {
        return assets.first!
    }
    
    /// Returns the aspect ratio of the primary asset
    var primaryAspectRatio: CGFloat {
        let asset = primaryAsset
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }
    
    /// Convenience property for aspect ratio (same as primaryAspectRatio)
    var aspectRatio: CGFloat {
        return primaryAspectRatio
    }
    
    /// Returns the total count of photos in this stack
    var count: Int {
        return assets.count
    }
    
    // MARK: - Initializers
    
    init(asset: PHAsset) {
        self.assets = [asset]
        self.id = asset.localIdentifier
        self.creationDate = asset.creationDate ?? Date()
        self.images = [nil] // Initialize with placeholder
    }
    
    init(assets: [PHAsset]) {
        guard !assets.isEmpty else {
            fatalError("RPhotoStack cannot be initialized with empty assets array")
        }
        
        self.assets = assets
        self.id = assets.map { $0.localIdentifier }.joined(separator: "-")
        self.creationDate = assets.first?.creationDate ?? Date()
        self.images = Array(repeating: nil, count: assets.count) // Initialize with placeholders
    }
    
    // MARK: - Public Methods
    
    /// Returns an array of individual RPhotoStack objects for each photo in this stack
    func individualPhotoStacks() -> [RPhotoStack] {
        return assets.map { RPhotoStack(asset: $0) }
    }
    
    /// Loads thumbnail images for all photos in the stack
    /// - Parameters:
    ///   - targetSize: The target size for the thumbnails (default: 200x200)
    ///   - contentMode: The content mode for image loading (default: .aspectFill)
    ///   - completion: Optional completion handler called when all images are loaded
    func loadImages(
        targetSize: CGSize = CGSize(width: 200, height: 200),
        contentMode: PHImageContentMode = .aspectFill,
        completion: (() -> Void)? = nil
    ) {
        guard !isLoading else { return }
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        let dispatchGroup = DispatchGroup()
        var loadedImages: [Int: UIImage] = [:]
        
        for (index, asset) in assets.enumerated() {
            dispatchGroup.enter()
            
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { image, info in
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                
                if !isDegraded, let image = image {
                    loadedImages[index] = image
                }
                
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            // Update images array with loaded images
            for index in 0..<self.assets.count {
                if index < self.images.count {
                    self.images[index] = loadedImages[index]
                }
            }
            
            self.isLoading = false
            completion?()
        }
    }
    
    /// Loads a high-quality image for the primary asset
    /// - Parameters:
    ///   - targetSize: The target size for the image
    ///   - completion: Completion handler with the loaded image
    func loadPrimaryImage(
        targetSize: CGSize = CGSize(width: 400, height: 400),
        completion: @escaping (UIImage?) -> Void
    ) {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        imageManager.requestImage(
            for: primaryAsset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    /// Returns the primary image if already loaded
    var primaryImage: UIImage? {
        return images.first ?? nil
    }
    
    /// Checks if the specified asset identifier is contained in this stack
    func contains(assetId: String) -> Bool {
        return assets.contains { $0.localIdentifier == assetId }
    }
    
    /// Returns true if all assets in this stack are selected
    func isFullySelected(selectedAssets: Set<String>) -> Bool {
        return assets.allSatisfy { selectedAssets.contains($0.localIdentifier) }
    }
    
    /// Returns true if any asset in this stack is selected
    func isPartiallySelected(selectedAssets: Set<String>) -> Bool {
        return assets.contains { selectedAssets.contains($0.localIdentifier) }
    }
}

// MARK: - RPhotoStack Extensions

extension RPhotoStack: Equatable {
    static func == (lhs: RPhotoStack, rhs: RPhotoStack) -> Bool {
        return lhs.id == rhs.id
    }
}

extension RPhotoStack: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Helper Methods

extension RPhotoStack {
    /// Creates photo stacks from an array of PHAssets using time-based grouping
    /// - Parameters:
    ///   - assets: Array of PHAssets to group
    ///   - stackingInterval: Time interval in seconds for grouping (default: 10 minutes)
    ///   - maxStackSize: Maximum number of photos per stack (default: 3)
    /// - Returns: Array of RPhotoStack objects
    static func createStacks(
        from assets: [PHAsset],
        stackingInterval: TimeInterval = 10 * 60, // 10 minutes
        maxStackSize: Int = 3
    ) -> [RPhotoStack] {
        // Sort assets by creation date
        let sortedAssets = assets.sorted {
            ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast)
        }
        
        var stacks: [RPhotoStack] = []
        var currentStackAssets: [PHAsset] = []
        
        for asset in sortedAssets {
            let assetDate = asset.creationDate ?? Date()
            
            if let lastAsset = currentStackAssets.last,
               let lastDate = lastAsset.creationDate {
                let timeDifference = abs(assetDate.timeIntervalSince(lastDate))
                
                if timeDifference <= stackingInterval && currentStackAssets.count < maxStackSize {
                    // Add to current stack
                    currentStackAssets.append(asset)
                } else {
                    // Finalize current stack and start new one
                    if !currentStackAssets.isEmpty {
                        stacks.append(RPhotoStack(assets: currentStackAssets))
                    }
                    currentStackAssets = [asset]
                }
            } else {
                // First asset or no date
                currentStackAssets = [asset]
            }
        }
        
        // Handle remaining stack
        if !currentStackAssets.isEmpty {
            stacks.append(RPhotoStack(assets: currentStackAssets))
        }
        
        return stacks
    }
}