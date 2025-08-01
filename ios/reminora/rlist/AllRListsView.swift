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
    let onPinTap: ((PinData) -> Void)?
    let onPhotoStackTap: (([PHAsset]) -> Void)?
    
    @Environment(\.toolbarManager) private var toolbarManager
    
    init(context: NSManagedObjectContext, userId: String, onPhotoTap: ((PHAsset) -> Void)? = nil, onPinTap: ((PinData) -> Void)? = nil, onPhotoStackTap: (([PHAsset]) -> Void)? = nil) {
        self.context = context
        self.userId = userId
        self.onPhotoTap = onPhotoTap
        self.onPinTap = onPinTap
        self.onPhotoStackTap = onPhotoStackTap
    }
    
    @State private var userLists: [RListData] = []
    @State private var isLoading = true
    @State private var refreshTrigger = UUID()
    
    var body: some View {
        NavigationView {
            listContent
                .refreshable {
                    await loadRListDatas()
                }
        }
        .task {
            await loadRListDatas()
        }
        .task(id: refreshTrigger) {
            await loadRListDatas()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RListDatasChanged"))) { _ in
            print("🔍 AllRListsView received RListDatasChanged notification")
            refreshTrigger = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshLists"))) { _ in
            print("🔄 AllRListsView received RefreshLists notification")
            Task {
                await loadRListDatas()
            }
        }
        .onAppear {
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
    
    private func listItemView(for userList: RListData) -> some View {
        NavigationLink(destination: RListDetailView(list: userList)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(userList.name ?? "Unnamed List")
                        .font(.headline)
                    
//                    if userList.name == RListService.quickListName {
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
    
    private func loadRListDatas() async {
        isLoading = true
        
        // Ensure Quick and Shared lists exist
        await ensureSystemLists()
        
        // Fetch all user lists for this user
        let fetchRequest: NSFetchRequest<RListData> = RListData.fetchRequest()
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
        // Check if they already exist first
        let fetchRequest: NSFetchRequest<RListData> = RListData.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@ AND (name == %@ OR name == %@)", userId, "Quick", "Shared")
        
        do {
            let existingLists = try context.fetch(fetchRequest)
            let existingNames = Set(existingLists.compactMap { $0.name })
            
            var needsSave = false
            
            // Create Quick List if it doesn't exist
            if !existingNames.contains("Quick") {
                let quickList = RListData(context: context)
                quickList.id = UUID().uuidString
                quickList.name = "Quick"
                quickList.createdAt = Date()
                quickList.userId = userId
                needsSave = true
                print("📝 Creating Quick List for user: \(userId)")
            }
            
            // Create Shared List if it doesn't exist
            if !existingNames.contains("Shared") {
                let sharedList = RListData(context: context)
                sharedList.id = UUID().uuidString
                sharedList.name = "Shared"
                sharedList.createdAt = Date()
                sharedList.userId = userId
                needsSave = true
                print("📝 Creating Shared List for user: \(userId)")
            }
            
            if needsSave {
                try context.save()
                print("✅ Created missing system lists for user: \(userId)")
            } else {
                print("✅ System lists already exist for user: \(userId) - Quick: \(existingNames.contains("Quick")), Shared: \(existingNames.contains("Shared"))")
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
    
    // MARK: - Toolbar Setup
    
    private func setupToolbar() {
        let toolbarButtons = [
            ToolbarButtonConfig(
                id: "photos",
                title: "Photos",
                systemImage: "photo",
                action: { 
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: 0)
                },
                color: .blue
            ),
            ToolbarButtonConfig(
                id: "map",
                title: "Map",
                systemImage: "map",
                action: { 
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: 1)
                },
                color: .green
            ),
            ToolbarButtonConfig(
                id: "pins",
                title: "Pins",
                systemImage: "mappin.and.ellipse",
                action: { 
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: 2)
                },
                color: .red
            ),
            ToolbarButtonConfig(
                id: "profile",
                title: "Profile",
                systemImage: "person.circle",
                action: { 
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: 4)
                },
                color: .purple
            )
        ]
        
        toolbarManager.setCustomToolbar(buttons: toolbarButtons)
    }
}
