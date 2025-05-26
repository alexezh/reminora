//
//  ContentView.swift
//  wahi
//
//  Created by alexezh on 5/26/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Place.dateAdded, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Place>

    var body: some View {
        NavigationView {
            List {
                ForEach(items) { item in
                    HStack(alignment: .center, spacing: 12) {
                        if let imageData = item.imageData, let image = UIImage(data: imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if let urlString = item.url, let url = URL(string: urlString), let image = loadImage(from: url) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .foregroundColor(.gray)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            if let date = item.dateAdded {
                                Text(date, formatter: itemFormatter)
                                    .font(.headline)
                            }
                            if let urlString = item.url {
                                Text(urlString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Place(context: viewContext)
            newItem.dateAdded = Date()
            newItem.url = nil // Or set a default image URL if desired

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // Helper to load image from file URL
    private func loadImage(from url: URL) -> UIImage? {
        if url.isFileURL {
            return UIImage(contentsOfFile: url.path)
        } else if let data = try? Data(contentsOf: url) {
            return UIImage(data: data)
        }
        return nil
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
