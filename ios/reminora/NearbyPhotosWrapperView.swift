import CoreData
import MapKit
import SwiftUI

struct NearbyPhotosWrapperView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationManager = LocationManager()
    @State private var showPhotoDetail = false
    @State private var selectedPlace: Place?
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Place.dateAdded, ascending: false)],
        animation: .default
    )
    private var places: FetchedResults<Place>
    
    var body: some View {
        Group {
            if let userLocation = locationManager.lastLocation {
                NearbyPhotosListView(
                    places: Array(places),
                    currentLocation: userLocation.coordinate,
                    onPhotoSelect: { place in
                        selectedPlace = place
                        showPhotoDetail = true
                    }
                )
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Location Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Please allow location access to see nearby photos")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Refresh Location") {
                        // Location is automatically requested in LocationManager's init
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .navigationTitle("Nearby Photos")
            }
        }
        .sheet(isPresented: $showPhotoDetail) {
            if let selectedPlace = selectedPlace {
                NavigationView {
                    PlaceDetailView(
                        place: selectedPlace,
                        allPlaces: Array(places),
                        onBack: {
                            showPhotoDetail = false
                        }
                    )
                }
            }
        }
        .onAppear {
            // Location is automatically requested in LocationManager's init
        }
    }
}

#Preview {
    NearbyPhotosWrapperView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}