import SwiftUI
import CoreData

struct ListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var showingCreateList = false
    @State private var newListName = ""
    @State private var selectedList: UserList?
    @State private var showingListDetail = false
    
    @FetchRequest private var userLists: FetchedResults<UserList>
    @FetchRequest private var listItems: FetchedResults<ListItem>
    
    init() {
        self._userLists = FetchRequest<UserList>(
            sortDescriptors: [NSSortDescriptor(keyPath: \UserList.createdAt, ascending: false)],
            predicate: NSPredicate(format: "userId == %@", AuthenticationService.shared.currentAccount?.id ?? ""),
            animation: .default
        )
        
        self._listItems = FetchRequest<ListItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \ListItem.addedAt, ascending: false)],
            animation: .default
        )
    }
    
    var orderedLists: [UserList] {
        let lists = Array(userLists)
        var ordered: [UserList] = []
        
        // Add Shared list first
        if let sharedList = lists.first(where: { $0.name == "Shared" }) {
            ordered.append(sharedList)
        }
        
        // Add Quick list second
        if let quickList = lists.first(where: { $0.name == "Quick" }) {
            ordered.append(quickList)
        }
        
        // Add all other lists
        let otherLists = lists.filter { $0.name != "Shared" && $0.name != "Quick" }
            .sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
        ordered.append(contentsOf: otherLists)
        
        return ordered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Lists")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        showingCreateList = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Ordered lists with Shared and Quick at top
                        ForEach(orderedLists, id: \.id) { list in
                            ListCard(
                                title: list.name ?? "Untitled List",
                                subtitle: "\(itemCount(for: list)) items",
                                icon: iconForList(list.name ?? ""),
                                isSpecialList: (list.name == "Shared" || list.name == "Quick"),
                                onTap: {
                                    selectedList = list
                                    showingListDetail = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCreateList) {
            CreateListView(isPresented: $showingCreateList)
        }
        .sheet(isPresented: $showingListDetail) {
            if let selectedList = selectedList {
                ListDetailView(list: selectedList)
            }
        }
    }
    
    private func iconForList(_ name: String) -> String {
        switch name {
        case "Shared":
            return "shared.with.you"
        case "Quick":
            return "bolt.fill"
        default:
            return "list.bullet"
        }
    }
    
    private func itemCount(for list: UserList) -> Int {
        return listItems.filter { $0.listId == list.id }.count
    }
}

struct ListCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSpecialList: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(colorForList(title))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(colorForList(title).opacity(0.1)))
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func colorForList(_ name: String) -> Color {
        switch name {
        case "Shared":
            return .green
        case "Quick":
            return .orange
        default:
            return .blue
        }
    }
}

struct CreateListView: View {
    @Binding var isPresented: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var listName = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("List Name")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter list name", text: $listName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.done)
                        .onSubmit {
                            createList()
                        }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createList()
                    }
                    .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createList() {
        guard !listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUser = authService.currentAccount else {
            return
        }
        
        isCreating = true
        
        let trimmedName = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If creating a new "Quick" list, rename the existing one
        if trimmedName == "Quick" {
            renameExistingQuickList()
        }
        
        let newList = UserList(context: viewContext)
        newList.id = UUID().uuidString
        newList.name = trimmedName
        newList.createdAt = Date()
        newList.userId = currentUser.id
        
        do {
            try viewContext.save()
            isPresented = false
        } catch {
            print("Failed to create list: \(error)")
        }
        
        isCreating = false
    }
    
    private func renameExistingQuickList() {
        let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@ AND userId == %@", "Quick", authService.currentAccount?.id ?? "")
        
        do {
            let existingQuickLists = try viewContext.fetch(fetchRequest)
            if let existingQuick = existingQuickLists.first {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy"
                let dateString = formatter.string(from: existingQuick.createdAt ?? Date())
                existingQuick.name = "Quick - \(dateString)"
                print("Renamed existing Quick list to: Quick - \(dateString)")
            }
        } catch {
            print("Failed to rename existing Quick list: \(error)")
        }
    }
}

#Preview {
    ListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}