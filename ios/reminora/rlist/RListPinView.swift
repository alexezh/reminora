//
//  RListPinView.swift
//  reminora
//
//  Created by alexezh on 7/29/25.
//


import SwiftUI
import Photos
import CoreData
import CoreLocation
import MapKit

// MARK: - RRListItemDataView (Pin and Location rows only)
struct RRListPinView: View {
    let item: any RListViewItem
    let onPinTap: (PinData) -> Void
    let onLocationTap: ((LocationInfo) -> Void)?
    let onDeleteItem: ((any RListViewItem) -> Void)?
    let onUserTap: ((String, String) -> Void)?
    
    init(
        item: any RListViewItem,
        onPinTap: @escaping (PinData) -> Void,
        onLocationTap: ((LocationInfo) -> Void)? = nil,
        onDeleteItem: ((any RListViewItem) -> Void)? = nil,
        onUserTap: ((String, String) -> Void)? = nil
    ) {
        self.item = item
        self.onPinTap = onPinTap
        self.onLocationTap = onLocationTap
        self.onDeleteItem = onDeleteItem
        self.onUserTap = onUserTap
    }
    
    var body: some View {
        switch item.itemType {
        case .pin(let place):
            VStack(spacing: 0) {
                PinCardView(
                    place: place,
                    cardHeight: 200,
                    onPhotoTap: { onPinTap(place) },
                    onTitleTap: { onPinTap(place) },
                    onMapTap: { onPinTap(place) },
                    onUserTap: { userId, userName in
                        onUserTap?(userId, userName)
                    }
                )
                
                // Add delete button if delete is supported
                if let onDeleteItem = onDeleteItem {
                    HStack {
                        Spacer()
                        Button(action: { onDeleteItem(item) }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove")
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        case .location(let location):
            RListLocationView(location: location, onTap: { onLocationTap?(location) }, onDelete: onDeleteItem != nil ? { onDeleteItem!(item) } : nil)
        case .photoStack(_):
            // This should never happen in pin rows - photos are handled by RListPhotoView in photo rows
            EmptyView()
        case .header(_):
            // Headers should be handled by RListHeaderView in header rows
            EmptyView()
        }
    }
}
