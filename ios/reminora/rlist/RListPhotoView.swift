//
//  RListPhotoView.swift
//  reminora
//
//  Created by alexezh on 7/29/25.
//


import SwiftUI
import Photos
import CoreData
import CoreLocation
import MapKit

// MARK: - Grid-specific Photo Views
struct RListPhotoGridView: View {
    let asset: PHAsset
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onAspectRatioCalculated: (CGFloat) -> Void
    
    init(asset: PHAsset, isSelectionMode: Bool = false, isSelected: Bool = false, onTap: @escaping () -> Void, onAspectRatioCalculated: @escaping (CGFloat) -> Void) {
        self.asset = asset
        self.isSelectionMode = isSelectionMode
        self.isSelected = isSelected
        self.onTap = onTap
        self.onAspectRatioCalculated = onAspectRatioCalculated
    }
    
    @State private var image: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.7)
                        )
                }
                
                // Selection mode overlay with improved visibility
                if isSelectionMode {
                    VStack {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 28, height: 28)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                
                                Circle()
                                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
                                    .frame(width: 28, height: 28)
                                
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(isSelected ? .blue : .gray)
                            }
                            .padding(8)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadImage()
        }
        .onAppear {
            // Calculate and report aspect ratio
            let aspectRatio = CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
            onAspectRatioCalculated(aspectRatio)
        }
    }
    
    private func loadImage() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        await withCheckedContinuation { continuation in
            var hasResumed = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                
                if !isDegraded {
                    hasResumed = true
                    self.image = image
                    continuation.resume()
                } else if image == nil {
                    hasResumed = true
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - RListPhotoGridItemView
struct RListPhotoGridItemView: View {
    let item: any RListViewItem
    let isSelectionMode: Bool
    let selectedAssets: Set<String>
    let onPhotoTap: (PHAsset) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    let onAspectRatioCalculated: (String, CGFloat) -> Void
    
    var body: some View {
        switch item.itemType {
        case .photo(let asset):
            RListPhotoGridView(
                asset: asset,
                isSelectionMode: isSelectionMode,
                isSelected: selectedAssets.contains(asset.localIdentifier),
                onTap: { onPhotoTap(asset) },
                onAspectRatioCalculated: { aspectRatio in
                    onAspectRatioCalculated(item.id, aspectRatio)
                }
            )
        case .photoStack(let assets):
            RListPhotoStackGridView(
                assets: assets,
                isSelectionMode: isSelectionMode,
                isSelected: assets.allSatisfy { selectedAssets.contains($0.localIdentifier) },
                onTap: { onPhotoStackTap(assets) },
                onAspectRatioCalculated: { aspectRatio in
                    onAspectRatioCalculated(item.id, aspectRatio)
                }
            )
        case .pin(_), .location(_):
            // This shouldn't happen in photo rows, but handle gracefully
            EmptyView()
        }
    }
}

struct RListPhotoStackView: View {
    let assets: [PHAsset]
    let onTap: () -> Void
    
    @State private var images: [UIImage?] = []
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                ForEach(Array(assets.prefix(3).enumerated()), id: \.offset) { index, asset in
                    if index < images.count, let image = images[index] {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 120)
                            .cornerRadius(8)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.7)
                            )
                    }
                }
                if assets.count > 3 {
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .frame(height: 120)
                        .cornerRadius(8)
                        .overlay(
                            Text("+\(assets.count - 3)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadImages()
        }
    }
    
    private func loadImages() async {
        images = Array(repeating: nil, count: min(assets.count, 3))
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        for (index, asset) in assets.prefix(3).enumerated() {
            await withCheckedContinuation { continuation in
                var hasResumed = false
                
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: CGSize(width: 200, height: 200),
                    contentMode: .aspectFill,
                    options: options
                ) { image, info in
                    guard !hasResumed else { return }
                    
                    let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                    
                    if !isDegraded {
                        hasResumed = true
                        DispatchQueue.main.async {
                            if index < self.images.count {
                                self.images[index] = image
                            }
                        }
                        continuation.resume()
                    } else if image == nil {
                        hasResumed = true
                        continuation.resume()
                    }
                }
            }
        }
    }
}

// MARK: - Photo Stack Grid View
struct RListPhotoStackGridView: View {
    let assets: [PHAsset]
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onAspectRatioCalculated: (CGFloat) -> Void
    
    @State private var primaryImage: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background photos (offset for stack effect)
                if assets.count > 1 {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(8)
                        .offset(x: 2, y: 2)
                }
                
                if assets.count > 2 {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(8)
                        .offset(x: 4, y: 4)
                }
                
                // Primary photo
                if let image = primaryImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.7)
                        )
                }
                
                // Stack count indicator
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 24, height: 24)
                            
                            Text("\(assets.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(6)
                    }
                }
                
                // Selection mode overlay with improved visibility
                if isSelectionMode {
                    VStack {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 28, height: 28)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                
                                Circle()
                                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
                                    .frame(width: 28, height: 28)
                                
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(isSelected ? .blue : .gray)
                            }
                            .padding(8)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadPrimaryImage()
        }
        .onAppear {
            // Calculate and report aspect ratio for primary asset
            if let primaryAsset = assets.first {
                let aspectRatio = CGFloat(primaryAsset.pixelWidth) / CGFloat(primaryAsset.pixelHeight)
                onAspectRatioCalculated(aspectRatio)
            }
        }
    }
    
    private func loadPrimaryImage() async {
        guard let primaryAsset = assets.first else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        await withCheckedContinuation { continuation in
            var hasResumed = false
            
            PHImageManager.default().requestImage(
                for: primaryAsset,
                targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                
                if !isDegraded {
                    hasResumed = true
                    self.primaryImage = image
                    continuation.resume()
                } else if image == nil {
                    hasResumed = true
                    continuation.resume()
                }
            }
        }
    }
}


struct RListPhotoView: View {
    let asset: PHAsset
    let onTap: () -> Void
    
    @State private var image: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        await withCheckedContinuation { continuation in
            var hasResumed = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 400, height: 400),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                
                if !isDegraded {
                    hasResumed = true
                    self.image = image
                    continuation.resume()
                } else if image == nil {
                    hasResumed = true
                    continuation.resume()
                }
            }
        }
    }
}
