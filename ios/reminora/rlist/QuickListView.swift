//
//  QuickListView.swift
//  reminora
//
//  Created by alexezh on 7/14/25.
//


import Foundation
import CoreData
import Photos
import SwiftUI

// MARK: - Quick List View
struct QuickListView: View {
    let context: NSManagedObjectContext
    let userId: String
    let onPhotoTap: (PHAsset) -> Void
    let onPinTap: (Place) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    
    @State private var items: [any RListViewItem] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading Quick List...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Quick List is Empty")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Add photos and pins to your Quick List to see them here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    RListView(
                        dataSource: .mixed(items),
                        onPhotoTap: onPhotoTap,
                        onPinTap: onPinTap,
                        onPhotoStackTap: onPhotoStackTap
                    )
                }
            }
            .navigationTitle("Quick List")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await loadItems()
        }
    }
    
    private func loadItems() async {
        isLoading = true
        let loadedItems = await QuickListService.shared.getQuickListItems(context: context, userId: userId)
        await MainActor.run {
            self.items = loadedItems
            self.isLoading = false
        }
    }
}
