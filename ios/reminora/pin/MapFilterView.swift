//
//  MapFilterView.swift
//  reminora
//
//  Created by Claude on 7/26/25.
//

import SwiftUI

struct MapFilterView: View {
    @Binding var selectedCategory: String
    
    let categories: [String]
    
    var body: some View {
        VStack(spacing: 0) {
            // Category filter dropdown
            HStack {
                Text("Category:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Menu {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            selectedCategory = category
                        }) {
                            HStack {
                                Text(category)
                                if selectedCategory == category {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedCategory)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
}