import SwiftUI
import CoreData
import CoreLocation

struct ListDetailView: View {
    let list: UserList
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    @FetchRequest private var listItems: FetchedResults<ListItem>
    @FetchRequest private var places: FetchedResults<Place>
    
    init(list: UserList) {
        self.list = list
        
        // Fetch items for this list
        self._listItems = FetchRequest<ListItem>(
            sortDescriptors: [NSSortDescriptor(keyPath: \ListItem.addedAt, ascending: false)],
            predicate: NSPredicate(format: "listId == %@", list.id ?? ""),
            animation: .default
        )
        
        // Fetch all places to match with list items
        self._places = FetchRequest<Place>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Place.dateAdded, ascending: false)],
            animation: .default
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with list info
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(colorForList(list.name ?? "").opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: iconForList(list.name ?? ""))
                                    .font(.title2)
                                    .foregroundColor(colorForList(list.name ?? ""))
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(list.name ?? "Untitled List")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(listItems.count) items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .background(Color(.systemBackground))
                
                Divider()
                
                // List items
                if listItems.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: iconForList(list.name ?? ""))
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 4) {
                            Text("No items in \(list.name ?? "this list")")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Add places to this list to see them here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(listItems, id: \.id) { item in
                                if let place = placeForItem(item) {
                                    ListItemCard(
                                        place: place,
                                        listItem: item,
                                        onRemove: {
                                            removeItem(item)
                                        }
                                    )
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func placeForItem(_ item: ListItem) -> Place? {
        // Find place by matching the object ID stored in placeId
        return places.first { place in
            place.objectID.uriRepresentation().absoluteString == item.placeId
        }
    }
    
    private func removeItem(_ item: ListItem) {
        withAnimation {
            viewContext.delete(item)
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to remove item from list: \(error)")
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

struct ListItemCard: View {
    let place: Place
    let listItem: ListItem
    let onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Place info
            HStack(spacing: 12) {
                // Photo thumbnail or placeholder
                if let imageData = place.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.post ?? "Untitled")
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    if let url = place.url, !url.isEmpty {
                        Text(url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let date = place.dateAdded {
                        Text(date, formatter: itemFormatter)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Remove button
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                }
            }
            
            // Shared info if available
            if let sharedLink = listItem.sharedLink, !sharedLink.isEmpty {
                HStack {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("Shared via link")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .padding(.leading, 72) // Align with text above
            }
            
            // Added date
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Added \(listItem.addedAt ?? Date(), formatter: shortFormatter)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 72) // Align with text above
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

private let shortFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
}()

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let sampleList = UserList(context: context)
    sampleList.id = "sample"
    sampleList.name = "Quick"
    sampleList.createdAt = Date()
    sampleList.userId = "user1"
    
    return ListDetailView(list: sampleList)
        .environment(\.managedObjectContext, context)
}