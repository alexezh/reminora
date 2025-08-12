//
//  ThumbnailListView.swift
//  reminora
//
//  Created by Claude on 8/7/25.
//

import SwiftUI
import Photos

/// A horizontal scrollable list of photo thumbnails with stack expansion support
struct ThumbnailListView: View {
    @ObservedObject var photoStackCollection: RPhotoStackCollection
    @Binding var currentIndex: Int
    
    let onThumbnailTap: (Int) -> Void
    let onStackExpand: (RPhotoStack?) -> Void
    let onStackCollapse: (RPhotoStack?) -> Void
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) { // Remove default spacing
                    ForEach(Array(photoStackCollection.enumerated()), id: \.element.localIdentifier) { index, stack in
                        let (leadingSpacing, trailingSpacing) = getThumbnailSpacing(for: stack, at: index)
                        ThumbnailView(
                            photoStack: stack,
                            isSelected: index == currentIndex,
                            onTap: {
                                handleThumbnailTap(index: index, stack: stack)
                            }
                        )
                        .padding(.horizontal, trailingSpacing)
                    }
                }
                .padding(.horizontal, LayoutConstants.thumbnailPadding)
                .background(Color.black)
            }
            .frame(height: LayoutConstants.thumbnailHeight)
            .onChange(of: currentIndex) { _, newIndex in
                let allAssets = photoStackCollection.allAssets()
                guard newIndex >= 0 && newIndex < allAssets.count else { return }
                // Smooth scroll to new thumbnail with spring animation
                withAnimation(.interpolatingSpring(stiffness: 200, damping: 20)) {
                    scrollProxy.scrollTo(allAssets[newIndex].localIdentifier, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleThumbnailTap(index: Int, stack: RPhotoStack) {
        // Handle tap - if it's a stack indicator, expand/collapse
        if stack.isStack && stack.count > 1 {
            // Toggle stack expansion - collection handles the logic internally
            if photoStackCollection.toggleStackExpansion(stack.id) {
                onStackExpand(stack)
            } else {
                onStackCollapse(stack)
            }
        }
        onThumbnailTap(index)
    }
    
    private func getThumbnailSpacing(for stack: RPhotoStack, at index: Int) -> (leading: CGFloat, trailing: CGFloat) {
        
        // Half photo width for separation (30px since thumbnail is 60px)
        let halfPhotoSpacing: CGFloat = 30
        let normalSpacing = LayoutConstants.thumbnailSpacing
        let selectedSpacing: CGFloat = 20 // Extra spacing for selected thumbnail only
        
        // Check if this is the selected thumbnail
        let isSelected = index == currentIndex
        
        let stackId = stack.id
        let isExpanded = photoStackCollection.isStackExpanded(stackId)
        
        if !isExpanded {
            // Collapsed stack - only selected thumbnail gets extra spacing
            if isSelected {
                return (selectedSpacing, selectedSpacing)
            }
            return (0, 0) // No extra spacing for non-selected thumbnails
        }
        
        // Expanded stack - add half-photo separation around the stack group
        let isFirstInStack = stack.primaryAsset.localIdentifier == stack.assets.first?.localIdentifier
        let isLastInStack = stack.primaryAsset.localIdentifier == stack.assets.last?.localIdentifier
        
        var leadingSpacing: CGFloat = 0
        var trailingSpacing: CGFloat = 0
        
        if isFirstInStack {
            // First photo in expanded stack - add half-photo spacing before
            leadingSpacing = halfPhotoSpacing
        }
        
        if isLastInStack {
            // Last photo in expanded stack - add half-photo spacing after
            trailingSpacing = halfPhotoSpacing
        }
        
        // Add extra spacing only for selected thumbnail
        if isSelected {
            leadingSpacing += selectedSpacing
            trailingSpacing += selectedSpacing
        }
        
        return (leadingSpacing, trailingSpacing)
    }
}

// MARK: - Preview

struct ThumbnailListView_Previews: PreviewProvider {
    static var previews: some View {
        ThumbnailListView(
            photoStackCollection: RPhotoStackCollection(),
            currentIndex: .constant(0),
            onThumbnailTap: { _ in },
            onStackExpand: { _ in },
            onStackCollapse: { _ in }
        )
        .previewLayout(.sizeThatFits)
    }
}
