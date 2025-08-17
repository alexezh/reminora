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
    let onPhotoStackTap: (RPhotoStack) -> Void
    let onPinTap: (PinData) -> Void
    let onLocationTap: ((LocationInfo) -> Void)?
    
    @State private var items: [any RListViewItem] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if items.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Quick List is Empty")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Add photos and pins to see them here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    RListView(
                        dataSource: .mixed(items),
                        onPhotoStackTap: onPhotoStackTap,
                        onPinTap: onPinTap,
                        onLocationTap: onLocationTap,
                        onDeleteItem: { item in
                            // Handle delete from Quick List
                            deleteItemFromQuickList(item)
                        }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await loadItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("QuickListChanged"))) { _ in
            Task {
                await loadItems()
            }
        }
    }
    
    private func loadItems() async {
        isLoading = true
        let loadedItems = await RListService.shared.getQuickListItems(context: context)
        print("🔍 QuickListView loaded \(loadedItems.count) items")
        await MainActor.run {
            self.items = loadedItems
            self.isLoading = false
        }
    }
    
    private func deleteItemFromQuickList(_ item: any RListViewItem) {
        Task {
            switch item.itemType {
            case .photoStack(let photoStack):
                // For photo stacks, process each individual photo
                var allSuccess = true
                for asset in photoStack.assets {
                    let success = RListService.shared.togglePhotoInQuickList(asset, context: context)
                    if !success {
                        allSuccess = false
                    }
                }
                if allSuccess {
                    await MainActor.run {
                        items.removeAll { $0.id == item.id }
                    }
                }
            case .pin(_):
                // For pins, remove from Quick List by toggling
                // This assumes RListService has a method to remove pins from Quick List
                print("TODO: Implement pin deletion from Quick List")
            case .header(_):
                // Headers cannot be deleted
                break
            case .location(_):
                print("Location deletion not yet implemented")
            }
        }
    }
}
