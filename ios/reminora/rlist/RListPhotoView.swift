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
    let onTap: () -> Void
    
    @Environment(\.selectedAssetService) private var selectedAssetService
    
    init(
        photoStack: RPhotoStack,
        isSelectionMode: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.photoStack = photoStack
        self.isSelectionMode = isSelectionMode
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background stack layers for multi-photo stacks
                if !photoStack.isSinglePhoto {
                    stackBackgroundLayers
                }
                
                // Primary photo
                if let primaryImage = photoStack.primaryImage {
                    Image(uiImage: primaryImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .cornerRadius(8)
                }
                
                // Stack count indicator for multi-photo stacks - positioned absolutely
                if !photoStack.isSinglePhoto {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 24, height: 24)
                        
                        Text("\(photoStack.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .offset(x: 0, y: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(6)
                }
                
                // Selection indicator - positioned absolutely
                if isSelectionMode {
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
                    .offset(x: 0, y: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            setupView()
        }
    }
    
    // MARK: - View Components
    
    
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
        
    // MARK: - Computed Properties
    
    private var isSelected: Bool {
        if photoStack.isSinglePhoto {
            return selectedAssetService.isPhotoSelected(photoStack.primaryAsset.localIdentifier)
        } else {
            return photoStack.isFullySelected(selectedAssets: selectedAssetService.selectedPhotoIdentifiers)
        }
    }
    
    private var isPartiallySelected: Bool {
        return !photoStack.isSinglePhoto && photoStack.isPartiallySelected(selectedAssets: selectedAssetService.selectedPhotoIdentifiers)
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
