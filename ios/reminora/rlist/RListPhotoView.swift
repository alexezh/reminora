//
//  RListPhotoView.swift
//  reminora
//
//  Created by Claude on 8/4/25.
//

import SwiftUI
import Photos

// MARK: - RListPhotoView
struct RListPhotoView: View {
    @ObservedObject var photoStack: RPhotoStack
    let isSelectionMode: Bool
    let selectedAssets: Set<String>
    let onTap: () -> Void
    let onAspectRatioCalculated: ((CGFloat) -> Void)?
    
    init(
        photoStack: RPhotoStack,
        isSelectionMode: Bool = false,
        selectedAssets: Set<String> = [],
        onTap: @escaping () -> Void,
        onAspectRatioCalculated: ((CGFloat) -> Void)? = nil
    ) {
        self.photoStack = photoStack
        self.isSelectionMode = isSelectionMode
        self.selectedAssets = selectedAssets
        self.onTap = onTap
        self.onAspectRatioCalculated = onAspectRatioCalculated
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background stack layers for multi-photo stacks
                if !photoStack.isSinglePhoto {
                    stackBackgroundLayers
                }
                
                // Primary photo
                primaryPhotoView
                
                // Stack count indicator for multi-photo stacks
                if !photoStack.isSinglePhoto {
                    stackCountIndicator
                }
                
                // Selection indicator
                if isSelectionMode {
                    selectionIndicator
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            setupView()
        }
        .onAppear {
            // Report aspect ratio
            onAspectRatioCalculated?(photoStack.primaryAspectRatio)
        }
    }
    
    // MARK: - View Components
    
    private var primaryPhotoView: some View {
        Group {
            if let primaryImage = photoStack.primaryImage {
                Image(uiImage: primaryImage)
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
                        Group {
                            if photoStack.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                        }
                    )
            }
        }
    }
    
    private var stackBackgroundLayers: some View {
        Group {
            // Second layer
            if photoStack.count > 1 {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(8)
                    .offset(x: 2, y: 2)
            }
            
            // Third layer
            if photoStack.count > 2 {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(8)
                    .offset(x: 4, y: 4)
            }
        }
    }
    
    private var stackCountIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 24, height: 24)
                    
                    Text("\(photoStack.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(6)
            }
        }
    }
    
    private var selectionIndicator: some View {
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
                    
                    Image(systemName: selectionIconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(selectionColor)
                }
                .padding(8)
                Spacer()
            }
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var isSelected: Bool {
        if photoStack.isSinglePhoto {
            return selectedAssets.contains(photoStack.primaryAsset.localIdentifier)
        } else {
            return photoStack.isFullySelected(selectedAssets: selectedAssets)
        }
    }
    
    private var isPartiallySelected: Bool {
        return !photoStack.isSinglePhoto && photoStack.isPartiallySelected(selectedAssets: selectedAssets)
    }
    
    private var selectionIconName: String {
        if isSelected {
            return "checkmark.circle.fill"
        } else if isPartiallySelected {
            return "minus.circle.fill"
        } else {
            return "circle"
        }
    }
    
    private var selectionColor: Color {
        if isSelected {
            return .blue
        } else if isPartiallySelected {
            return .orange
        } else {
            return .gray
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupView() {
        // Load images if not already loaded
        if photoStack.images.allSatisfy({ $0 == nil }) && !photoStack.isLoading {
            photoStack.loadImages()
        }
    }
}

// MARK: - Preview Support
#if DEBUG
struct RListPhotoView_Previews: PreviewProvider {
    static var previews: some View {
        // This would need actual PHAssets for a real preview
        // For now, just show the structure
        VStack {
            Text("RListPhotoView Preview")
            // RListPhotoView(photoStack: RPhotoStack(asset: sampleAsset), onTap: {})
        }
    }
}
#endif