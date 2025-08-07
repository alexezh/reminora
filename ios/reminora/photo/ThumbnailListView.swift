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
    let displayAssets: [PHAsset]
    let photoStacks: [RPhotoStack]
    let expandedStacks: Set<String>
    @Binding var currentIndex: Int
    
    let onThumbnailTap: (Int) -> Void
    let onStackExpand: (RPhotoStack?) -> Void
    let onStackCollapse: (RPhotoStack?) -> Void
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) { // Remove default spacing
                    ForEach(Array(displayAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                        let stackInfo = getStackInfo(for: asset)
                        let (leadingSpacing, trailingSpacing) = getThumbnailSpacing(for: asset, at: index)
                        
                        HStack(spacing: 0) {
                            // Leading spacing
                            if leadingSpacing > 0 {
                                Spacer()
                                    .frame(width: leadingSpacing)
                            }
                            
                            ThumbnailView(
                                asset: asset,
                                isSelected: index == currentIndex,
                                stackInfo: stackInfo
                            ) {
                                handleThumbnailTap(index: index, stackInfo: stackInfo)
                            }
                            
                            // Trailing spacing
                            if trailingSpacing > 0 {
                                Spacer()
                                    .frame(width: trailingSpacing)
                            }
                        }
                    }
                }
                .padding(.horizontal, LayoutConstants.thumbnailPadding)
            }
            .frame(height: LayoutConstants.thumbnailHeight)
            .onChange(of: currentIndex) { _, newIndex in
                guard newIndex >= 0 && newIndex < displayAssets.count else { return }
                // Smooth scroll to new thumbnail with spring animation
                withAnimation(.interpolatingSpring(stiffness: 200, damping: 20)) {
                    scrollProxy.scrollTo(displayAssets[newIndex].localIdentifier, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleThumbnailTap(index: Int, stackInfo: (stack: RPhotoStack?, isStack: Bool, count: Int)) {
        // Handle tap - if it's a stack indicator, expand/collapse
        if stackInfo.isStack && stackInfo.count > 1 {
            let stackId = stackInfo.stack!.id
            if expandedStacks.contains(stackId) {
                onStackCollapse(stackInfo.stack)
            } else {
                onStackExpand(stackInfo.stack)
            }
        }
        onThumbnailTap(index)
    }
    
    private func getStackInfo(for asset: PHAsset) -> (stack: RPhotoStack?, isStack: Bool, count: Int) {
        for stack in photoStacks {
            if stack.assets.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                return (stack: stack, isStack: stack.assets.count > 1, count: stack.assets.count)
            }
        }
        return (stack: nil, isStack: false, count: 1)
    }
    
    private func getThumbnailSpacing(for asset: PHAsset, at index: Int) -> (leading: CGFloat, trailing: CGFloat) {
        let stackInfo = getStackInfo(for: asset)
        
        // Half photo width for separation (30px since thumbnail is 60px)
        let halfPhotoSpacing: CGFloat = 30
        let normalSpacing = LayoutConstants.thumbnailSpacing
        let selectedSpacing: CGFloat = 8 // Extra spacing for selected thumbnail (20% bigger)
        
        // Check if this is the selected thumbnail
        let isSelected = index == currentIndex
        
        guard let stack = stackInfo.stack, stack.assets.count > 1 else {
            // Single photo - use normal spacing, add extra for selected
            if isSelected {
                return (normalSpacing + selectedSpacing, normalSpacing + selectedSpacing)
            }
            return (normalSpacing, normalSpacing)
        }
        
        let stackId = stack.id
        let isExpanded = expandedStacks.contains(stackId)
        
        if !isExpanded {
            // Collapsed stack - use normal spacing, add extra for selected
            if isSelected {
                return (normalSpacing + selectedSpacing, normalSpacing + selectedSpacing)
            }
            return (normalSpacing, normalSpacing)
        }
        
        // Expanded stack - add half-photo separation around the stack group
        let isFirstInStack = asset.localIdentifier == stack.assets.first?.localIdentifier
        let isLastInStack = asset.localIdentifier == stack.assets.last?.localIdentifier
        
        var leadingSpacing: CGFloat = normalSpacing
        var trailingSpacing: CGFloat = normalSpacing
        
        if isFirstInStack {
            // First photo in expanded stack - add half-photo spacing before
            leadingSpacing = halfPhotoSpacing
        }
        
        if isLastInStack {
            // Last photo in expanded stack - add half-photo spacing after
            trailingSpacing = halfPhotoSpacing
        }
        
        // Add extra spacing for selected thumbnail
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
            displayAssets: [],
            photoStacks: [],
            expandedStacks: Set<String>(),
            currentIndex: .constant(0),
            onThumbnailTap: { _ in },
            onStackExpand: { _ in },
            onStackCollapse: { _ in }
        )
        .previewLayout(.sizeThatFits)
    }
}