import Foundation
import UIKit
import Photos
import SwiftUI

class PhotoSharingService: NSObject, ObservableObject {
    static let shared = PhotoSharingService()
    
    @Published var isSharing = false
    
    private override init() {
        super.init()
    }
    
    // MARK: - Stock Photo App Style Sharing
    
    func sharePhoto(_ asset: PHAsset, from viewController: UIViewController? = nil) {
        Task { @MainActor in
            isSharing = true
            
            defer {
                isSharing = false
            }
            
            do {
                let image = try await loadImage(from: asset)
                presentShareSheet(for: image, asset: asset, from: viewController)
            } catch {
                print("Failed to load image for sharing: \(error)")
            }
        }
    }
    
    func sharePhotos(_ assets: [PHAsset], from viewController: UIViewController? = nil) {
        Task { @MainActor in
            isSharing = true
            
            defer {
                isSharing = false
            }
            
            do {
                let images = try await loadImages(from: assets)
                presentShareSheet(for: images, assets: assets, from: viewController)
            } catch {
                print("Failed to load images for sharing: \(error)")
            }
        }
    }
    
    // MARK: - SwiftUI Integration
    
    func sharePhoto(_ asset: PHAsset) {
        // Use the standard UIViewController-based sharing
        sharePhoto(asset, from: nil)
    }
    
    // MARK: - Private Methods
    
    private func loadImage(from asset: PHAsset) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let image = image {
                    continuation.resume(returning: image)
                } else if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: PhotoSharingError.imageLoadFailed)
                }
            }
        }
    }
    
    private func loadImages(from assets: [PHAsset]) async throws -> [UIImage] {
        var images: [UIImage] = []
        
        for asset in assets {
            let image = try await loadImage(from: asset)
            images.append(image)
        }
        
        return images
    }
    
    private func presentShareSheet(for image: UIImage, asset: PHAsset, from viewController: UIViewController?) {
        let items: [Any] = [image]
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Exclude some activities that don't make sense for photos
        activityViewController.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks
        ]
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            if let viewController = viewController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            }
            popover.permittedArrowDirections = []
        }
        
        // Present from the appropriate view controller
        let presentingVC = viewController ?? topViewController()
        presentingVC?.present(activityViewController, animated: true)
    }
    
    private func presentShareSheet(for images: [UIImage], assets: [PHAsset], from viewController: UIViewController?) {
        let activityViewController = UIActivityViewController(activityItems: images, applicationActivities: nil)
        
        // Exclude some activities that don't make sense for photos
        activityViewController.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks
        ]
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            if let viewController = viewController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            }
            popover.permittedArrowDirections = []
        }
        
        // Present from the appropriate view controller
        let presentingVC = viewController ?? topViewController()
        presentingVC?.present(activityViewController, animated: true)
    }
    
    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        var topViewController = window.rootViewController
        
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        
        return topViewController
    }
}

enum PhotoSharingError: Error, LocalizedError {
    case imageLoadFailed
    case noViewController
    
    var errorDescription: String? {
        switch self {
        case .imageLoadFailed:
            return "Failed to load image"
        case .noViewController:
            return "No view controller available for presentation"
        }
    }
}

// MARK: - SwiftUI View Extension

extension View {
    func sharePhoto(_ asset: PHAsset) -> some View {
        self.background(
            SharePhotoView(asset: asset)
        )
    }
}

struct SharePhotoView: UIViewControllerRepresentable {
    let asset: PHAsset
    
    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(asset: asset)
    }
    
    class Coordinator: NSObject {
        let asset: PHAsset
        
        init(asset: PHAsset) {
            self.asset = asset
        }
    }
}