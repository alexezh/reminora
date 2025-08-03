//
//  SwipePhotoImageView.swift
//  reminora
//
//  Created by alexezh on 7/14/25.
//


import SwiftUI
import Photos
import PhotosUI
import UIKit
import CoreData
import MapKit
import CoreLocation

struct SwipePhotoImageView: View {
    let asset: PHAsset
    @Binding var isLoading: Bool
    let stackInfo: (stack: PhotoStack?, isStack: Bool, count: Int)?
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var loadError: Bool = false
    
    init(asset: PHAsset, isLoading: Binding<Bool>, stackInfo: (stack: PhotoStack?, isStack: Bool, count: Int)? = nil) {
        self.asset = asset
        self._isLoading = isLoading
        self.stackInfo = stackInfo
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { value in
                                    lastScale = scale
                                    // Limit zoom between 1x and 4x
                                    if scale < 1 {
                                        withAnimation(.spring()) {
                                            scale = 1
                                            lastScale = 1
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    } else if scale > 4 {
                                        withAnimation(.spring()) {
                                            scale = 4
                                            lastScale = 4
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            // Only enable pan gesture when zoomed in
                            DragGesture()
                                .onChanged { value in
                                    // Only allow panning when zoomed in
                                    if scale > 1 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { value in
                                    // Only handle pan end when zoomed in
                                    if scale > 1 {
                                        lastOffset = offset
                                        
                                        // Bounce back if panned too far
                                        let maxOffsetX = (geometry.size.width * (scale - 1)) / 2
                                        let maxOffsetY = (geometry.size.height * (scale - 1)) / 2
                                        
                                        var newOffset = offset
                                        if abs(offset.width) > maxOffsetX {
                                            newOffset.width = offset.width > 0 ? maxOffsetX : -maxOffsetX
                                        }
                                        if abs(offset.height) > maxOffsetY {
                                            newOffset.height = offset.height > 0 ? maxOffsetY : -maxOffsetY
                                        }
                                        
                                        if newOffset != offset {
                                            withAnimation(.spring()) {
                                                offset = newOffset
                                                lastOffset = newOffset
                                            }
                                        }
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            // Double tap to zoom
                            withAnimation(.spring()) {
                                if scale > 1 {
                                    scale = 1
                                    lastScale = 1
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2
                                    lastScale = 2
                                }
                            }
                        }
                
                // Stack count indicator overlay (top-right corner)
                if let stackInfo = stackInfo, stackInfo.isStack, stackInfo.count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.8))
                                    .frame(width: 32, height: 32)
                                
                                Text("\(stackInfo.count)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                } else if loadError {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.white)
                        Text("Failed to load image")
                            .foregroundColor(.white)
                            .font(.caption)
                        Button("Retry") {
                            loadError = false
                            loadImage()
                        }
                        .foregroundColor(.blue)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .clipped()
        .onAppear {
            if image == nil && !loadError {
                loadImage()
            }
        }
        .onChange(of: asset.localIdentifier) { _, _ in
            // Reset state and load new image when asset changes
            image = nil
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
            loadError = false
            loadImage()
        }
    }
    
    private func loadImage() {
        isLoading = true
        loadError = false
        
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        
        let targetSize = CGSize(width: UIScreen.main.bounds.width * UIScreen.main.scale,
                               height: UIScreen.main.bounds.height * UIScreen.main.scale)
        
        print("Loading image for asset: \(asset.localIdentifier)")
        
        // Request image with error handling
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { loadedImage, info in
            DispatchQueue.main.async {
                
                if let loadedImage = loadedImage {
                    image = loadedImage
                    isLoading = false
                    loadError = false
                    print("Successfully loaded image for asset: \(asset.localIdentifier)")
                    
                    // Check if this is a degraded image and request high quality
                    if let info = info,
                       let degraded = info[PHImageResultIsDegradedKey] as? Bool,
                       degraded {
                        print("Loading high quality version for asset: \(asset.localIdentifier)")
                        
                        let hqOptions = PHImageRequestOptions()
                        hqOptions.isSynchronous = false
                        hqOptions.deliveryMode = .highQualityFormat
                        hqOptions.resizeMode = .exact
                        hqOptions.isNetworkAccessAllowed = true
                        
                        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: hqOptions) { hqImage, hqInfo in
                            DispatchQueue.main.async {
                                if let hqImage = hqImage {
                                    image = hqImage
                                    print("High quality image loaded for asset: \(asset.localIdentifier)")
                                }
                            }
                        }
                    }
                } else {
                    // Handle loading failure
                    isLoading = false
                    loadError = true
                    
                    // Check for specific error information
                    if let info = info {
                        if let error = info[PHImageErrorKey] as? Error {
                            print("Image loading error for asset \(asset.localIdentifier): \(error)")
                        }
                        if let cancelled = info[PHImageCancelledKey] as? Bool, cancelled {
                            print("Image loading cancelled for asset: \(asset.localIdentifier)")
                        }
                        if let inCloud = info[PHImageResultIsInCloudKey] as? Bool, inCloud {
                            print("Image is in iCloud for asset: \(asset.localIdentifier)")
                        }
                    }
                    
                    print("Failed to load image for asset: \(asset.localIdentifier)")
                }
            }
        }
    }
}
