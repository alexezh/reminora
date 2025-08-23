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

// main image in swipe photo view with integrated paging
struct SwipePhotoImageView: View {
    let photoStackCollection: RPhotoStackCollection
    @Binding var currentIndex: Int
    @Binding var isLoading: Bool
    let onIndexChanged: ((Int) -> Void)?
    let onVerticalPull: (() -> Void)?
    
    @State private var images: [Int: UIImage] = [:] // Cache for 3 images
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var loadError: Bool = false
    
    // Paging state
    @GestureState private var dragOffset: CGFloat = 0
    @State private var animationOffset: CGFloat = 0
    @State private var verticalOffset: CGFloat = 0
    @State private var isAnimating: Bool = false
    
    private var visibleIndices: [Int] {
        guard !photoStackCollection.isEmpty else { return [] }
        
        let prev = max(currentIndex - 1, 0)
        let next = min(currentIndex + 1, photoStackCollection.count - 1)
        return [prev, currentIndex, next]
    }
    
    init(
        photoStackCollection: RPhotoStackCollection,
        currentIndex: Binding<Int>,
        isLoading: Binding<Bool>,
        onIndexChanged: ((Int) -> Void)? = nil,
        onVerticalPull: (() -> Void)? = nil
    ) {
        self.photoStackCollection = photoStackCollection
        self._currentIndex = currentIndex
        self._isLoading = isLoading
        self.onIndexChanged = onIndexChanged
        self.onVerticalPull = onVerticalPull
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            
            ZStack {
                // Horizontal paging with 3 images (prev, current, next)
                HStack(spacing: 0) {
                    ForEach(visibleIndices, id: \.self) { index in
                        photoView(for: index, geometry: geometry)
                            .frame(width: width)
                    }
                }
                .offset(x: -width + (isAnimating ? animationOffset : dragOffset), y: verticalOffset)
            }
            .clipped()
            .gesture(
                // Combined gesture handling for paging, zoom, and pan
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        let translationX = value.translation.width
                        let translationY = value.translation.height
                        
                        // Only allow horizontal drag for paging if gesture is primarily horizontal
                        // and not zoomed in (when zoomed, pan gesture takes priority)
                        if scale <= 1.0 {
                            state = translationX
                        } else {
                            // When zoomed in, handle pan gesture for current image
                            offset = CGSize(
                                width: lastOffset.width + translationX,
                                height: lastOffset.height + translationY
                            )
                        }
                        
                        // Update vertical offset for pull-down gesture
                        if abs(translationY) > abs(translationX) && translationY > 0 && scale <= 1.0 {
                            verticalOffset = min(translationY * 0.5, 200)
                        }
                    }
                    .onEnded { value in
                        let translationX = value.translation.width
                        let translationY = value.translation.height
                        let velocityY = value.velocity.height
                        
                        // Handle vertical pull-down to dismiss
                        if abs(translationY) > abs(translationX) && (translationY > 150 || velocityY > 800) && scale <= 1.0 {
                            onVerticalPull?()
                            return
                        }
                        
                        // Reset vertical offset if not dismissing
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                            verticalOffset = 0
                        }
                        
                        // Handle pan end when zoomed in
                        if scale > 1.0 {
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
                        // Handle horizontal paging only if not zoomed and gesture was primarily horizontal
                        else if abs(translationX) > abs(translationY) {
                            let velocityX = value.velocity.width
                            let threshold: CGFloat = 50
                            var newIndex = currentIndex
                            let translationX = value.translation.width
                            
                            if abs(translationX) > threshold || abs(velocityX) > 300 {
                                if velocityX < -300 || (translationX < -threshold && velocityX <= 300) {
                                    // Swipe left = next item
                                    newIndex = min(currentIndex + 1, photoStackCollection.count - 1)
                                } else if velocityX > 300 || (translationX > threshold && velocityX >= -300) {
                                    // Swipe right = previous item
                                    newIndex = max(currentIndex - 1, 0)
                                }
                            }
                            
                            let indexChanged = newIndex != currentIndex
                            
                            if indexChanged {
                                
                                //animationOffset = dragOffset;
                                animationOffset = translationX
                                isAnimating = true

                                DispatchQueue.main.async {
                                    // First animate the offset to complete the swipe motion
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                                        // Move offset to final position for smooth transition
                                        if newIndex > currentIndex {
                                            // Swiping to next - move left
                                            animationOffset = -width
                                        } else {
                                            // Swiping to previous - move right
                                            animationOffset = width
                                        }
                                    }
                                    
                                    // After offset animation completes, switch index and reset offset
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        currentIndex = newIndex
                                        animationOffset = 0
                                        isAnimating = false
                                        onIndexChanged?(newIndex)
                                    }
                                }
                            }
                        }
                    }
            )
            .simultaneousGesture(
                // Zoom gesture for current image
                MagnificationGesture()
                    .onChanged { value in
                        scale = lastScale * value
                    }
                    .onEnded { value in
                        lastScale = scale
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
        }
        .onAppear {
            loadVisibleImages()
        }
        .onChange(of: currentIndex) { _, _ in
            loadVisibleImages()
        }
    }
    
    @ViewBuilder
    private func photoView(for index: Int, geometry: GeometryProxy) -> some View {
        ZStack {
            if let image = images[index] {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                    .scaleEffect(index == currentIndex ? scale : 1.0)
                    .offset(index == currentIndex ? offset : .zero)
                
                // Stack count indicator overlay (only for current image)
                if index == currentIndex {
                    let photoStack = photoStackCollection[index]
                    if photoStack.count > 1 {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.8))
                                        .frame(width: 32, height: 32)
                                    
                                    Text("\(photoStack.count)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
                }
                
            } else if let photoStack = photoStackCollection.count > index ? photoStackCollection[index] : nil {
                // Loading state for this index
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        loadImage(for: index)
                    }
            } else {
                // Error or empty state
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Failed to load image")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func loadVisibleImages() {
        for index in visibleIndices {
            if images[index] == nil {
                loadImage(for: index)
            }
        }
        
        // Clean up images not in visible range to save memory
        let indicesToRemove = images.keys.filter { !visibleIndices.contains($0) }
        for index in indicesToRemove {
            images.removeValue(forKey: index)
        }
    }
    
    private func loadImage(for index: Int) {
        guard index >= 0 && index < photoStackCollection.count else { return }
        
        if index == currentIndex {
            isLoading = true
        }
        
        let photoStack = photoStackCollection[index]
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        
        let targetSize = CGSize(width: UIScreen.main.bounds.width * UIScreen.main.scale,
                               height: UIScreen.main.bounds.height * UIScreen.main.scale)
        
        imageManager.requestImage(for: photoStack.primaryAsset, targetSize: targetSize, contentMode: .aspectFit, options: options) { loadedImage, info in
            DispatchQueue.main.async {
                if let loadedImage = loadedImage {
                    images[index] = loadedImage
                    if index == currentIndex {
                        isLoading = false
                        loadError = false
                    }
                    
                    // Check if this is a degraded image and request high quality
                    if let info = info,
                       let degraded = info[PHImageResultIsDegradedKey] as? Bool,
                       degraded {
                        
                        let hqOptions = PHImageRequestOptions()
                        hqOptions.isSynchronous = false
                        hqOptions.deliveryMode = .highQualityFormat
                        hqOptions.resizeMode = .exact
                        hqOptions.isNetworkAccessAllowed = true
                        
                        imageManager.requestImage(for: photoStack.primaryAsset, targetSize: targetSize, contentMode: .aspectFit, options: hqOptions) { hqImage, hqInfo in
                            DispatchQueue.main.async {
                                if let hqImage = hqImage {
                                    images[index] = hqImage
                                }
                            }
                        }
                    }
                } else {
                    if index == currentIndex {
                        isLoading = false
                        loadError = true
                        
                        // Check for specific error information
                        if let info = info {
                            if let error = info[PHImageErrorKey] as? Error {
                                print("Image loading error for asset \(photoStack.primaryAsset.localIdentifier): \(error)")
                            }
                            if let cancelled = info[PHImageCancelledKey] as? Bool, cancelled {
                                print("Image loading cancelled for asset: \(photoStack.primaryAsset.localIdentifier)")
                            }
                            if let inCloud = info[PHImageResultIsInCloudKey] as? Bool, inCloud {
                                print("Image is in iCloud for asset: \(photoStack.primaryAsset.localIdentifier)")
                            }
                        }
                        
                        print("Failed to load image for asset: \(photoStack.primaryAsset.localIdentifier)")
                    }
                }
            }
        }
    }
}
