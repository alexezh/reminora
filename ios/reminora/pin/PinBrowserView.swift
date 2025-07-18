import CoreData
import MapKit
import SwiftUI

// list of pins with map
struct PinBrowserView: View {
    let places: [Place]
    let title: String
    let showToolbar: Bool

    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedPlace: Place?
    @State private var showPlaceDetail: Bool = false
    @State private var lastTappedPlace: Place?
    @State private var lastTapTime: Date = Date()

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    let minHeight: CGFloat = 50
    let oneThirdHeight: CGFloat = UIScreen.main.bounds.height * 0.33
    let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.8

    @State private var sheetHeight: CGFloat = UIScreen.main.bounds.height * 0.33
    @GestureState private var dragOffset: CGFloat = 0
    @State private var shouldScrollToSelected: Bool = true
    @State private var showingAddPhoto = false
    @State private var isSwipePhotoViewOpenInSheet = false
    private var filteredPlaces: [Place] {
        return places
    }

    var body: some View {
        ZStack {
            // Map with places
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: filteredPlaces)
            {
                item in
                MapAnnotation(coordinate: coordinate(item: item)) {
                    Button(action: {
                        shouldScrollToSelected = true
                        selectedPlace = item
                    }) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                }
            }

            // Sliding pane
            GeometryReader { geometry in
                let safeAreaBottom = geometry.safeAreaInsets.bottom

                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        // Drag handle
                        Capsule()
                            .fill(Color.secondary)
                            .frame(width: 40, height: 6)
                            .padding(.top, 8)
                            .padding(.bottom, 8)

                        // Button section
                        HStack(spacing: 12) {
                            Spacer()

                            // Add button
                            Button(action: {
                                showingAddPhoto = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                    Text("Add")
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                        // Title
                        if !title.isEmpty {
                            HStack {
                                Text(title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }

                        // Places list
                        PinListView(
                            items: filteredPlaces,
                            selectedPlace: selectedPlace,
                            onSelect: { item in
                                let now = Date()
                                let timeSinceLastTap = now.timeIntervalSince(lastTapTime)

                                // Check if this is a second tap on the same item within 2 seconds
                                if let lastPlace = lastTappedPlace,
                                    lastPlace.objectID == item.objectID,
                                    timeSinceLastTap < 2.0
                                {
                                    // Double tap detected - show detail view
                                    showPlaceDetail = true
                                } else {
                                    // First tap or different item - navigate map
                                    shouldScrollToSelected = false
                                    selectedPlace = item

                                    // Get coordinate of selected place
                                    let coord = coordinate(item: item)

                                    // Animate to the selected photo location
                                    let newRegion = MKCoordinateRegion(
                                        center: coord,
                                        span: MKCoordinateSpan(
                                            latitudeDelta: 0.01,
                                            longitudeDelta: 0.01
                                        )
                                    )
                                    withAnimation(.easeInOut(duration: 1.0)) {
                                        region = newRegion
                                    }
                                }

                                // Update last tapped info
                                lastTappedPlace = item
                                lastTapTime = now
                            },
                            onLongPress: { item in
                                // Long press detected - show detail view directly
                                selectedPlace = item
                                
                                // Provide haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                
                                showPlaceDetail = true
                            },
                            onDelete: showToolbar ? deleteItems : { _ in },
                            mapCenter: region.center
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
                    .offset(
                        y: max(
                            geometry.safeAreaInsets.top,  // Don't go above safe area
                            min(
                                geometry.size.height - minHeight,  // Don't go below minimum
                                geometry.size.height - sheetHeight - (showToolbar ? 100 : 50)
                                    + dragOffset
                            )
                        )
                    )
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.height
                            }
                            .onEnded { value in
                                let currentHeight = sheetHeight
                                let translation = value.translation.height

                                withAnimation(.easeInOut(duration: 0.3)) {
                                    if translation < -50 {  // Swiping up
                                        if currentHeight <= oneThirdHeight + 50 {
                                            sheetHeight = maxHeight
                                        } else {
                                            sheetHeight = maxHeight
                                        }
                                    } else if translation > 50 {  // Swiping down
                                        if currentHeight >= maxHeight - 50 {
                                            sheetHeight = oneThirdHeight
                                        } else if currentHeight >= oneThirdHeight - 50 {
                                            sheetHeight = minHeight
                                        }
                                    } else {
                                        // Small gesture - snap to nearest height
                                        let targetHeight = currentHeight - translation
                                        let heights = [minHeight, oneThirdHeight, maxHeight]
                                        let nearestHeight =
                                            heights.min {
                                                abs($0 - targetHeight) < abs($1 - targetHeight)
                                            } ?? oneThirdHeight
                                        sheetHeight = nearestHeight
                                    }
                                }
                            }
                    )
                    .onChange(of: selectedPlace) { place in
                        if let place = place, shouldScrollToSelected {
                            withAnimation {
                                proxy.scrollTo(place.objectID, anchor: .center)
                            }
                            shouldScrollToSelected = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPlaceDetail) {
            if let selectedPlace = selectedPlace {
                NavigationView {
                    PinDetailView(
                        place: selectedPlace,
                        allPlaces: filteredPlaces,
                        onBack: {
                            showPlaceDetail = false
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showingAddPhoto) {
            PhotoStackView(isSwipePhotoViewOpen: $isSwipePhotoViewOpenInSheet)
        }
        .onAppear {
            // Center map on first place if available
            if let firstPlace = filteredPlaces.first {
                region.center = coordinate(item: firstPlace)
            }
        }
    }

    // Helper to get coordinate from Place
    private func coordinate(item: Place) -> CLLocationCoordinate2D {
        if let locationData = item.value(forKey: "location") as? Data,
            let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData)
                as? CLLocation
        {
            return location.coordinate
        }
        // Default to San Francisco if no location
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }

    private func deleteItems(offsets: IndexSet) {
        guard showToolbar else { return }

        withAnimation {
            offsets.map { places[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Failed to delete: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let samplePlaces: [Place] = []

    return PinBrowserView(
        places: samplePlaces,
        title: "Sample List",
        showToolbar: false
    )
    .environment(\.managedObjectContext, context)
}
