//
//  AddToListPickerView.swift
//  reminora
//
//  Created by alexezh on 7/14/25.
//

import SwiftUI
import CoreData

struct AddToListPickerView: View {
    let context: NSManagedObjectContext
    let userId: String
    let onListSelected: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var userLists: [UserList] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading Lists...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if userLists.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Lists Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Create your first list to add items to it")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(userLists, id: \.id) { list in
                            Button(action: {
                                if let listId = list.id {
                                    onListSelected(listId)
                                }
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(list.name ?? "Untitled List")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if let createdAt = list.createdAt {
                                        Text("Created \(createdAt, style: .relative)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .navigationTitle("Add to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .task {
            await loadUserLists()
        }
    }
    
    private func loadUserLists() async {
        isLoading = true
        
        do {
            let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "userId == %@ AND name != %@", userId, QuickListService.quickListName)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            
            let lists = try context.fetch(fetchRequest)
            
            await MainActor.run {
                self.userLists = lists
                self.isLoading = false
            }
        } catch {
            print("❌ Failed to load user lists: \(error)")
            await MainActor.run {
                self.userLists = []
                self.isLoading = false
            }
        }
    }
}

#Preview {
    AddToListPickerView(
        context: PersistenceController.shared.container.viewContext,
        userId: "test",
        onListSelected: { _ in },
        onDismiss: { }
    )
}