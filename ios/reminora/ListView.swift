import SwiftUI
import CoreData

struct ListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var showingCreateList = false
    @State private var newListName = ""
    
    @FetchRequest private var userLists: FetchedResults<UserList>
    
    init() {
        self._userLists = FetchRequest<UserList>(
            sortDescriptors: [NSSortDescriptor(keyPath: \UserList.createdAt, ascending: false)],
            animation: .default
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Lists")
                        .font(.largeTitle)
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
                .padding(.top, 8)
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Shared list (always present)
                        ListCard(
                            title: "Shared",
                            subtitle: "Items shared with you",
                            icon: "shared.with.you",
                            isSharedList: true,
                            onTap: {
                                // TODO: Navigate to shared list
                            }
                        )
                        
                        // User's custom lists
                        ForEach(userLists, id: \.id) { list in
                            ListCard(
                                title: list.name ?? "Untitled List",
                                subtitle: "\(list.items?.count ?? 0) items",
                                icon: "list.bullet",
                                isSharedList: false,
                                onTap: {
                                    // TODO: Navigate to list detail
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCreateList) {
            CreateListView(isPresented: $showingCreateList)
        }
    }
}

struct ListCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSharedList: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSharedList ? .green : .blue)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(isSharedList ? Color.green.opacity(0.1) : Color.blue.opacity(0.1)))
                
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
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
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
        
        let newList = UserList(context: viewContext)
        newList.id = UUID().uuidString
        newList.name = listName.trimmingCharacters(in: .whitespacesAndNewlines)
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
}

#Preview {
    ListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}