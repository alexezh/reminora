//
//  RListPhotoStackGridView.swift
//  reminora
//
//  Created by alexezh on 7/29/25.
//


import SwiftUI
import Photos
import CoreData
import CoreLocation
import MapKit

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

