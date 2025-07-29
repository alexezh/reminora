//
//  RListPhotoStackView.swift
//  reminora
//
//  Created by alexezh on 7/29/25.
//


import SwiftUI
import Photos
import CoreData
import CoreLocation
import MapKit

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