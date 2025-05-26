//
//  ContentView.swift
//  wahi
//
//  Created by alexezh on 5/26/25.
//

import CoreData
import MapKit
import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Place.dateAdded, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Place>

    @State private var searchText: String = ""
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var showSheet = false
    @State private var selectedPlace: Place?

    @State private var sheetHeight: CGFloat = 400
    @State private var isSheetExpanded: Bool = false

    var filteredItems: [Place] {
        if searchText.isEmpty {
            return Array(items)
        } else {
            return items.filter { item in
                (item.post?.localizedCaseInsensitiveContains(searchText) ?? false)
                    || (item.url?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var body: some View {
        ZStack {
            // Map background
            Map(coordinateRegion: $region, annotationItems: filteredItems) { item in
                MapAnnotation(coordinate: coordinate(for: item)) {
                    Button(action: {
                        selectedPlace = item
                        showSheet = true
                    }) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                }
            }
            .ignoresSafeArea()

            // Sliding pane (bottom sheet)
            VStack {
                Spacer()
                ExpandableSearchView(
                    isOpen: $showSheet,
                    isExpanded: $isSheetExpanded,
                    minHeight: 80,
                    maxHeight: UIScreen.main.bounds.height * 0.95
                ) {
                    VStack(spacing: 0) {
                        // Drag handle and expand/collapse button
                        HStack {
                            Capsule()
                                .frame(width: 40, height: 6)
                                .foregroundColor(.gray.opacity(0.4))
                                .padding(.top, 8)
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    isSheetExpanded.toggle()
                                }
                            }) {
                                Image(systemName: isSheetExpanded ? "chevron.down" : "chevron.up")
                                    .padding(.top, 8)
                                    .padding(.trailing, 16)
                            }
                        }
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(8)
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding([.top, .horizontal])

                        // List of items
                        List {
                            ForEach(filteredItems) { item in
                                HStack(alignment: .center, spacing: 12) {
                                    if let imageData = item.imageData,
                                        let image = UIImage(data: imageData)
                                    {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 56, height: 56)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else if let urlString = item.url,
                                        let url = URL(string: urlString),
                                        let image = loadImage(from: url)
                                    {
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
                                        if let post = item.post, !post.isEmpty {
                                            Text(post)
                                                .font(.body)
                                                .lineLimit(1)
                                        } else if let urlString = item.url {
                                            Text(urlString)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                                .onTapGesture {
                                    selectedPlace = item
                                    showSheet = false
                                    let coord = coordinate(for: item)
                                    region.center = coord
                                }
                            }
                            .onDelete(perform: deleteItems)
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                // Bottom toolbar
                HStack {
                    Spacer()
                    Button(action: addItem) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                    }
                    Spacer()
                    EditButton()
                        .font(.system(size: 18))
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Place(context: viewContext)
            newItem.dateAdded = Date()
            newItem.url = nil  // Or set a default image URL if desired

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

    // Helper to get coordinate from Place
    private func coordinate(for item: Place) -> CLLocationCoordinate2D {
        if let locationData = item.value(forKey: "location") as? Data,
            let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData)
                as? CLLocation
        {
            return location.coordinate
        }
        // Default to San Francisco if no location
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
