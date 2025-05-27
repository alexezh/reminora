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

    @State private var sheetOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    let minHeight: CGFloat = 50
    let maxHeight: CGFloat = 400

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
                    height: maxHeight,
                    alignment: .top
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 5)
                )
                .offset(y: geometry.size.height - minHeight + dragOffset + sheetOffset)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            let newOffset = sheetOffset + value.translation.height
                            // Clamp between fully expanded and collapsed
                            sheetOffset = min(max(newOffset, -maxHeight + minHeight), 0)
                        }
                )
            }
            .frame(height: maxHeight)

            // Always keep ExpandableSearchView in the view hierarchy, but control its offset and opacity
            // ExpandableSearchView(
            //     isOpen: .constant(true),  // Always open so it's always in the view hierarchy
            //     isExpanded: $isSheetExpanded,
            //     minHeight: showSheet ? 80 : 10,
            //     maxHeight: UIScreen.main.bounds.height * 0.95
            // ) {
            //     VStack(spacing: 0) {
            //         // Drag handle and expand/collapse button
            //         HStack {
            //             Capsule()
            //                 .frame(width: 40, height: 6)
            //                 .foregroundColor(.gray.opacity(0.4))
            //                 .padding(.top, 8)
            //                 .onTapGesture {
            //                     withAnimation {
            //                         isSheetExpanded.toggle()
            //                     }
            //                 }
            //             Spacer()
            //             Button(action: {
            //                 withAnimation {
            //                     isSheetExpanded.toggle()
            //                 }
            //             }) {
            //                 Image(systemName: isSheetExpanded ? "chevron.down" : "chevron.up")
            //                     .padding(.top, 8)
            //                     .padding(.trailing, 16)
            //             }
            //         }
            //         // Search bar
            //         HStack {
            //             Image(systemName: "magnifyingglass")
            //                 .foregroundColor(.gray)
            //             TextField("Search...", text: $searchText)
            //                 .textFieldStyle(PlainTextFieldStyle())
            //                 .padding(8)
            //         }
            //         .background(Color(.systemGray6))
            //         .cornerRadius(10)
            //         .padding([.top, .horizontal])

            //         // Move the list to a separate control
            //         PlaceListView(
            //             items: filteredItems,
            //             onSelect: { item in
            //                 selectedPlace = item
            //                 showSheet = false
            //                 let coord = coordinate(for: item)
            //                 region.center = coord
            //             },
            //             onDelete: deleteItems
            //         )
            //     }
            // }
            //            .opacity(showSheet ? 1 : 0)
            //            .animation(.easeInOut, value: showSheet)
            //            .allowsHitTesting(showSheet)
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
