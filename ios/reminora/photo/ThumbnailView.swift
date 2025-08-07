//
//  ThumbnailView.swift
//  reminora
//
//  Created by alexezh on 8/5/25.
//


import SwiftUI
import Photos
import PhotosUI
import UIKit
import CoreData
import MapKit
import CoreLocation

// MARK: - ThumbnailView
struct ThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool
    let stackInfo: (stack: RPhotoStack?, isStack: Bool, count: Int)
    let onTap: () -> Void
    
    @State private var image: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                        .cornerRadius(8)
                        .scaleEffect(isSelected ? 1.2 : 1.0) // Scale selected thumbnail 20% bigger
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.white : Color.clear, lineWidth: isSelected ? 3 : 0)
                                .shadow(color: isSelected ? Color.white.opacity(0.5) : Color.clear, radius: isSelected ? 4 : 0)
                        )
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.5)
                        )
                }
                
                // Stack indicator
                if stackInfo.isStack {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.8))
                                    .frame(width: 16, height: 16)
                                
                                Text("\(stackInfo.count)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                        }
                        Spacer()
                    }
                    .padding(2)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        await withCheckedContinuation { continuation in
            var hasResumed = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 120, height: 120),
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
