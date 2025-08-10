//
//  RListRowView.swift
//  reminora
//
//  Created by alexezh on 8/3/25.
//


import SwiftUI
import Photos
import CoreData
import CoreLocation
import MapKit

// MARK: - RListRowView
struct RListRowView: View {
    let row: RListRow
    let isSelectionMode: Bool
    let onPhotoTap: (PHAsset) -> Void
    let onPinTap: (PinData) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    let onLocationTap: ((LocationInfo) -> Void)?
    let onDeleteItem: ((any RListViewItem) -> Void)?
    let onUserTap: ((String, String) -> Void)?
    
    
    var body: some View {
        switch row.type {
        case .headerRow:
            if let firstItem = row.items.first, case .header(let title) = firstItem.itemType {
                RListHeaderView(title: title)
            }
            
        case .photoRow:
            if row.items.count == 1, case .photoStack(let photoStack) = row.items[0].itemType {
                // Single photo row - limit width to 1/2 and scale preserving aspect ratio
                HStack {
                    RListPhotoView(
                        photoStack: photoStack,
                        isSelectionMode: isSelectionMode,
                        onTap: {
                            if photoStack.isSinglePhoto {
                                onPhotoTap(photoStack.primaryAsset)
                            } else {
                                onPhotoStackTap(photoStack.assets)
                            }
                        }
                    )
                    .aspectRatio(photoStack.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.5) // Limit to 1/2 width
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            } else {
                // Multiple photos row - use proportional layout without height restrictions
                GeometryReader { geometry in
                    let spacing: CGFloat = 4
                    let totalSpacing = spacing * CGFloat(max(0, row.items.count - 1))
                    let availableWidth = geometry.size.width - totalSpacing
                    
                    // Calculate widths based on aspect ratios
                    let widths = calculatePhotoWidths(availableWidth: availableWidth)
                    
                    HStack(spacing: spacing) {
                        ForEach(Array(row.items.enumerated()), id: \.offset) { index, item in
                            let width = widths.indices.contains(index) ? widths[index] : availableWidth / CGFloat(row.items.count)
                            
                            if case .photoStack(let photoStack) = item.itemType {
                                RListPhotoView(
                                    photoStack: photoStack,
                                    isSelectionMode: isSelectionMode,
                                    onTap: {
                                        if photoStack.isSinglePhoto {
                                            onPhotoTap(photoStack.primaryAsset)
                                        } else {
                                            onPhotoStackTap(photoStack.assets)
                                        }
                                    }
                                )
                                .aspectRatio(photoStack.aspectRatio, contentMode: .fit)
                                .frame(width: width)
                                .clipped()
                            }
                        }
                        
                        Spacer(minLength: 0)
                    }
                }
                .aspectRatio(calculateRowAspectRatio(), contentMode: .fit)
            }
            
        case .pinRow:
            ForEach(row.items, id: \.id) { item in
                RRListPinView(
                    item: item,
                    onPinTap: onPinTap,
                    onLocationTap: onLocationTap,
                    onDeleteItem: onDeleteItem,
                    onUserTap: onUserTap
                )
            }
        }
    }
    
    private func calculatePhotoWidths(availableWidth: CGFloat) -> [CGFloat] {
        var widths: [CGFloat] = []
        var totalAspectRatio: CGFloat = 0
        
        // Calculate total aspect ratio
        for item in row.items {
            if case .photoStack(let photoStack) = item.itemType {
                totalAspectRatio += photoStack.aspectRatio
            } else {
                totalAspectRatio += 1.0 // Default aspect ratio for non-photo items
            }
        }
        
        // If no aspect ratios calculated yet, use equal widths
        guard totalAspectRatio > 0 else {
            let equalWidth = availableWidth / CGFloat(row.items.count)
            return Array(repeating: equalWidth, count: row.items.count)
        }
        
        // Calculate individual widths based on aspect ratios
        for item in row.items {
            let aspectRatio: CGFloat
            if case .photoStack(let photoStack) = item.itemType {
                aspectRatio = photoStack.aspectRatio
            } else {
                aspectRatio = 1.0 // Default aspect ratio for non-photo items
            }
            let proportionalWidth = (aspectRatio / totalAspectRatio) * availableWidth
            widths.append(proportionalWidth)
        }
        
        return widths
    }
    
    private func calculateRowAspectRatio() -> CGFloat {
        // Calculate total aspect ratio for photo stacks in this row
        var totalAspectRatio: CGFloat = 0
        for item in row.items {
            if case .photoStack(let photoStack) = item.itemType {
                totalAspectRatio += photoStack.aspectRatio
            } else {
                // For non-photo items, use square aspect ratio
                totalAspectRatio += 1.0
            }
        }
        
        // Return total aspect ratio, or default if no valid ratios
        return totalAspectRatio > 0 ? totalAspectRatio : CGFloat(row.items.count)
    }
}
