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

    @State private var isSheetExpanded: Bool = false

    let minHeight: CGFloat = 50
    let maxHeight: CGFloat = 400

    @State private var sheetHeight: CGFloat = 50;
    @GestureState private var dragOffset: CGFloat = 0

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
            // Center map on first item if available
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
            .onAppear {
                if let first = filteredItems.first {
                    region.center = coordinate(for: first)
                }
            }

            // Sliding pane
            GeometryReader { geometry in
                let safeAreaBottom = geometry.safeAreaInsets.bottom

                VStack {
                    Capsule()
                        .fill(Color.secondary)
                        .frame(width: 40, height: 6)
                        .padding(.top, 8)
                    Spacer()
                    // Move the list to a separate control
                    PlaceListView(
                        items: filteredItems,
                        onSelect: { item in
                            selectedPlace = item
                            showSheet = false
                            let coord = coordinate(for: item)
                            region.center = coord
                        },
                        onDelete: deleteItems
                    )
                }
                .frame(
                    width: geometry.size.width,
                    // safe area is approximation, make actual size bigger
                    height: maxHeight + safeAreaBottom,
                    alignment: .top
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 5)
                )
                .offset(
                    y: geometry.size.height - sheetHeight - safeAreaBottom + dragOffset
                )
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            let newHeight = sheetHeight - value.translation.height
                            // zero offset is position at minHeight
                            // we want to limit offset to maxHeight - minHeight
                            sheetHeight = min(maxHeight, max(newHeight, minHeight))
                        }
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
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

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
