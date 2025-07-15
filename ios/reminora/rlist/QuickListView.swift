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
    @State private var showingMenu = false
    @State private var showingCreateList = false
    @State private var showingAddToList = false
    @State private var showingClearConfirmation = false
    @State private var newListName = ""
    @State private var selectedListId: String?
    
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
                        onPhotoTap: onPhotoTap,
                        onPinTap: onPinTap,
                        onPhotoStackTap: onPhotoStackTap
                    )
                }
            }
            .navigationTitle("Quick List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingMenu = true
                    }) {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(items.isEmpty)
                }
            }
        }
        .task {
            await loadItems()
        }
        .confirmationDialog("Quick List Actions", isPresented: $showingMenu, titleVisibility: .visible) {
            Button("Create List") {
                showingCreateList = true
            }
            
            Button("Add to List") {
                showingAddToList = true
            }
            
            Button("Clear Quick") {
                showingClearConfirmation = true
            }
            
            Button("Cancel", role: .cancel) { }
        }
        .alert("Create New List", isPresented: $showingCreateList) {
            TextField("List name", text: $newListName)
            Button("Create") {
                createNewList()
            }
            .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {
                newListName = ""
            }
        } message: {
            Text("Enter a name for the new list. All items from Quick List will be moved to this list.")
        }
        .alert("Clear Quick List", isPresented: $showingClearConfirmation) {
            Button("Clear", role: .destructive) {
                clearQuickList()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to clear all items from Quick List? This action cannot be undone.")
        }
        .sheet(isPresented: $showingAddToList) {
            AddToListPickerView(
                context: context,
                userId: userId,
                onListSelected: { listId in
                    selectedListId = listId
                    addToExistingList()
                },
                onDismiss: {
                    showingAddToList = false
                }
            )
        }
    }
    
    private func loadItems() async {
        isLoading = true
        let loadedItems = await QuickListService.shared.getQuickListItems(context: context, userId: userId)
        print("🔍 QuickListView loaded \(loadedItems.count) items")
        await MainActor.run {
            self.items = loadedItems
            self.isLoading = false
        }
    }
    
    // MARK: - Quick List Actions
    
    private func createNewList() {
        let trimmedName = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        Task {
            let success = await QuickListService.shared.createListFromQuickList(
                newListName: trimmedName,
                context: context,
                userId: userId
            )
            
            await MainActor.run {
                if success {
                    // Reload items to reflect the cleared Quick List
                    Task {
                        await loadItems()
                    }
                    newListName = ""
                    
                    // Show success feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                } else {
                    // Handle error - could show an alert
                    print("❌ Failed to create new list")
                }
            }
        }
    }
    
    private func addToExistingList() {
        guard let listId = selectedListId else { return }
        
        Task {
            let success = await QuickListService.shared.moveQuickListToExistingList(
                targetListId: listId,
                context: context,
                userId: userId
            )
            
            await MainActor.run {
                if success {
                    // Reload items to reflect the cleared Quick List
                    Task {
                        await loadItems()
                    }
                    selectedListId = nil
                    showingAddToList = false
                    
                    // Show success feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                } else {
                    // Handle error
                    print("❌ Failed to add to existing list")
                    showingAddToList = false
                }
            }
        }
    }
    
    private func clearQuickList() {
        Task {
            let success = await QuickListService.shared.clearQuickList(
                context: context,
                userId: userId
            )
            
            await MainActor.run {
                if success {
                    // Reload items to show empty state
                    Task {
                        await loadItems()
                    }
                    
                    // Show success feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                } else {
                    // Handle error
                    print("❌ Failed to clear Quick List")
                }
            }
        }
    }
}
