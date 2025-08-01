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

struct RListPhotoStackGridView: View {
    let assets: [PHAsset]
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    
    init(assets: [PHAsset], isSelectionMode: Bool = false, isSelected: Bool = false, onTap: @escaping () -> Void) {
        self.assets = assets
        self.isSelectionMode = isSelectionMode
        self.isSelected = isSelected
        self.onTap = onTap
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
                
                // Stack indicator overlay
                if assets.count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: "rectangle.stack.fill")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                            .padding(6)
                        }
                        Spacer()
                    }
                }
                
                // Selection mode overlay
                if isSelectionMode {
                    VStack {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.caption)
                                    .foregroundColor(isSelected ? .blue : .white)
                            }
                            .padding(6)
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
    }
    
    private func loadImage() async {
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