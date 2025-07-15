import CoreData
import CoreLocation
import SwiftUI

struct RListDetailView: View {
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

                // Places browser
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
                    let placesInList = listItems.compactMap { placeForItem($0) }
                    PinBrowserView(
                        places: placesInList,
                        title: "",
                        showToolbar: false
                    )
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

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let sampleList = UserList(context: context)
    sampleList.id = "sample"
    sampleList.name = "Quick"
    sampleList.createdAt = Date()
    sampleList.userId = "user1"

    return RListDetailView(list: sampleList)
        .environment(\.managedObjectContext, context)
}
