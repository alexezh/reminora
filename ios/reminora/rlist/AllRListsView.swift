//
//  AllRListsView.swift
//  reminora
//
//  Created by alexezh on 7/14/25.
//


import Foundation
import CoreData
import Photos
import SwiftUI

// MARK: - All RLists View
struct AllRListsView: View {
    let context: NSManagedObjectContext
    let userId: String
    let onPhotoTap: ((PHAsset) -> Void)?
    let onPinTap: ((Place) -> Void)?
    let onPhotoStackTap: (([PHAsset]) -> Void)?
    
    init(context: NSManagedObjectContext, userId: String, onPhotoTap: ((PHAsset) -> Void)? = nil, onPinTap: ((Place) -> Void)? = nil, onPhotoStackTap: (([PHAsset]) -> Void)? = nil) {
        self.context = context
        self.userId = userId
        self.onPhotoTap = onPhotoTap
        self.onPinTap = onPinTap
        self.onPhotoStackTap = onPhotoStackTap
    }
    
    @State private var userLists: [UserList] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            listContent
        }
        .task {
            await loadUserLists()
        }
    }
    
    @ViewBuilder
    private var listContent: some View {
        if isLoading {
            ProgressView("Loading Lists...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if userLists.isEmpty {
            emptyStateView
        } else {
            listView
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Lists Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first list to organize photos and pins")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var listView: some View {
        List {
            ForEach(userLists, id: \.id) { userList in
                listItemView(for: userList)
            }
        }
    }
    
    private func listItemView(for userList: UserList) -> some View {
        NavigationLink(destination: RListDetailView(list: userList)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(userList.name ?? "Unnamed List")
                        .font(.headline)
                    
//                    if userList.name == QuickListService.quickListName {
//                        Image(systemName: "star.fill")
//                            .foregroundColor(.yellow)
//                            .font(.caption)
//                    }
                    
                    Spacer()
                }
                
                Text("Created \(formatDate(userList.createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
        }
    }
    
    private func loadUserLists() async {
        isLoading = true
        
        // Ensure Quick and Shared lists exist
        await ensureSystemLists()
        
        // Fetch all user lists for this user
        let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]
        
        do {
            let lists = try context.fetch(fetchRequest)
            
            // Sort lists with Quick List first, then Shared, then others
            let sortedLists = lists.sorted { list1, list2 in
                let isQuickList1 = list1.name == "Quick"
                let isQuickList2 = list2.name == "Quick"
                let isSharedList1 = list1.name == "Shared"
                let isSharedList2 = list2.name == "Shared"
                
                if isQuickList1 && !isQuickList2 {
                    return true // Quick List comes first
                } else if !isQuickList1 && isQuickList2 {
                    return false // Quick List comes first
                } else if isSharedList1 && !isSharedList2 && !isQuickList2 {
                    return true // Shared List comes second
                } else if !isSharedList1 && isSharedList2 && !isQuickList1 {
                    return false // Shared List comes second
                } else {
                    // Both are system lists or neither are system lists, sort by creation date
                    return (list1.createdAt ?? Date.distantPast) > (list2.createdAt ?? Date.distantPast)
                }
            }
            
            await MainActor.run {
                self.userLists = sortedLists
                self.isLoading = false
            }
        } catch {
            print("❌ Failed to fetch user lists: \(error)")
            await MainActor.run {
                self.userLists = []
                self.isLoading = false
            }
        }
    }
    
    private func ensureSystemLists() async {
        // Create Quick List if it doesn't exist
        let quickList = UserList(context: context)
        quickList.id = UUID().uuidString
        quickList.name = "Quick"
        quickList.createdAt = Date()
        quickList.userId = userId
        
        // Create Shared List if it doesn't exist
        let sharedList = UserList(context: context)
        sharedList.id = UUID().uuidString
        sharedList.name = "Shared"
        sharedList.createdAt = Date()
        sharedList.userId = userId
        
        // Check if they already exist and only save new ones
        let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@ AND (name == %@ OR name == %@)", userId, "Quick", "Shared")
        
        do {
            let existingLists = try context.fetch(fetchRequest)
            let existingNames = Set(existingLists.compactMap { $0.name })
            
            var needsSave = false
            
            if !existingNames.contains("Quick") {
                needsSave = true
                // quickList is already created above
            } else {
                context.delete(quickList) // Remove the temporary one
            }
            
            if !existingNames.contains("Shared") {
                needsSave = true
                // sharedList is already created above
            } else {
                context.delete(sharedList) // Remove the temporary one
            }
            
            if needsSave {
                try context.save()
                print("✅ Created missing system lists")
            }
        } catch {
            print("❌ Failed to ensure system lists: \(error)")
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
