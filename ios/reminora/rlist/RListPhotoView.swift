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
                        .onAppear {
                            print("🖼️ RListPhotoView: Primary image displayed for stack \(photoStack.id)")
                        }
                } else {
                    // Show loading state or placeholder
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(8)
                        .overlay(
                            Group {
                                if photoStack.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                        .onAppear {
                                            print("🖼️ RListPhotoView: Showing loading state for stack \(photoStack.id)")
                                        }
                                } else {
                                    VStack(spacing: 4) {
                                        Image(systemName: "photo")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                        Text("No Image")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .onAppear {
                                        print("🖼️ RListPhotoView: Showing 'No Image' placeholder for stack \(photoStack.id)")
                                        print("🖼️ Images state: \(photoStack.images.map { $0 == nil ? "nil" : "loaded" })")
                                        print("🖼️ Primary image: \(photoStack.primaryImage != nil ? "available" : "nil")")
                                    }
                                }
                            }
                        )
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
                        // Background circle
                        Circle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        // Checkbox design
                        if isSelected {
                            // Filled checkbox
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 20, height: 20)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        } else if isPartiallySelected {
                            // Partially selected (orange with minus)
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 20, height: 20)
                            
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            // Empty checkbox
                            Circle()
                                .stroke(Color.gray, lineWidth: 2)
                                .frame(width: 20, height: 20)
                        }
                    }
                    .offset(x: 0, y: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                    .id("selection-\(photoStack.id)-\(selectedAssetService.selectedPhotoCount)")  // Force refresh
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
    
    
    // MARK: - Helper Methods
    
    private func setupView() {
        // Debug logging
        print("🖼️ RListPhotoView setupView: stack id=\(photoStack.id), assets=\(photoStack.assets.count), images=\(photoStack.images.count), isLoading=\(photoStack.isLoading)")
        print("🖼️ Images state: \(photoStack.images.map { $0 == nil ? "nil" : "loaded" })")
        
        // Load images if not already loaded
        if photoStack.images.allSatisfy({ $0 == nil }) && !photoStack.isLoading {
            print("🖼️ Starting image load for stack \(photoStack.id)")
            photoStack.loadImages {
                print("🖼️ Image load completed for stack \(photoStack.id)")
            }
        } else if !photoStack.images.allSatisfy({ $0 == nil }) {
            print("🖼️ Images already loaded for stack \(photoStack.id)")
        } else if photoStack.isLoading {
            print("🖼️ Images already loading for stack \(photoStack.id)")
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
