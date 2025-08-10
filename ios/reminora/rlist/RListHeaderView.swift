//
//  RListHeaderView.swift
//  reminora
//
//  Created by Claude on 8/10/25.
//

import SwiftUI

// MARK: - RListHeaderItem
struct RListHeaderItem: RListViewItem {
    let id: String
    let date: Date
    let itemType: RRListItemDataType
    let title: String
    
    init(date: Date, title: String) {
        self.id = "header_\(title)"
        self.date = date
        self.title = title
        self.itemType = .header(title)
    }
}

// MARK: - RListHeaderView
struct RListHeaderView: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    VStack {
        RListHeaderView(title: "Today")
        RListHeaderView(title: "Yesterday")
        RListHeaderView(title: "Apr 15")
    }
}