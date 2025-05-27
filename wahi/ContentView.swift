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

    @State private var sheetHeight: CGFloat = 50
    @GestureState private var dragOffset: CGFloat = 0

    @StateObject private var locationManager = LocationManager()

    var filteredItems: [Place] {
        let center = region.center
        let places: [Place]
        if searchText.isEmpty {
            places = Array(items)
        } else {
            places = items.filter { item in
                (item.post?.localizedCaseInsensitiveContains(searchText) ?? false)
                    || (item.url?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        // Sort by distance from map center
        return places.sorted { a, b in
            let aCoord = coordinate(for: a)
            let bCoord = coordinate(for: b)
            let aDist = distance(from: center, to: aCoord)
            let bDist = distance(from: center, to: bCoord)
            return aDist < bDist
        }
    }

    // Helper to calculate distance between two coordinates (in meters)
    private func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)
        -> CLLocationDistance
    {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }

    var body: some View {
        MapView(
            region: $region,
            filteredItems: filteredItems,
            selectedPlace: $selectedPlace,
            showSheet: $showSheet,
            coordinate: coordinate(for:),
            locationManager: locationManager
        )
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                Button(action: {
                    // Map button action
                    // Example: center on user location
                    if let userLoc = locationManager.lastLocation {
                        region.center = userLoc.coordinate
                    }
                }) {
                    VStack {
                        Image(systemName: "map")
                            .font(.system(size: 24))
                        Text("Map")
                            .font(.caption)
                    }
                }
                Spacer()
                Button(action: {
                    // Places button action
                    // Example: show/hide places list
                    withAnimation {
                        showSheet.toggle()
                    }
                }) {
                    VStack {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 24))
                        Text("Places")
                            .font(.caption)
                    }
                }
                Spacer()
                Button(action: {
                    // Camera button action
                    // Example: trigger camera or add new place
                    addItem()
                }) {
                    VStack {
                        Image(systemName: "camera")
                            .font(.system(size: 24))
                        Text("Camera")
                            .font(.caption)
                    }
                }
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
