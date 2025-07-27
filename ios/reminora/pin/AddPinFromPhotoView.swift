//
//  AddPinFromPhotoView.swift
//  reminora
//
//  Created by alexezh on 7/19/25.
//

import SwiftUI
import Photos
import PhotosUI
import UIKit
import CoreData
import MapKit
import CoreLocation

struct AddPinFromPhotoView: View {
    let asset: PHAsset
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authService = AuthenticationService.shared
    @State private var image: UIImage?
    @State private var caption: String = ""
    @State private var isSaving = false
    @State private var isPrivate = false
    @State private var showingAuthentication = false
    @State private var placeName: String? = nil
    @State private var country: String? = nil
    @State private var city: String? = nil
    @State private var isLoadingLocation = false
    @State private var selectedLocations: [LocationInfo] = []
    @State private var showingLocationSelector = false
    
    private let cloudSyncService = CloudSyncService.shared
    
    // Computed property to get current locations (selected + default from photo)
    var currentLocations: [LocationInfo] {
        if !selectedLocations.isEmpty {
            return selectedLocations
        }
        
        // Create default location from photo coordinates if available
        if let location = asset.location {
            let defaultLocation = LocationInfo(
                id: "photo_location",
                name: placeName ?? (city != nil && country != nil ? "\(city!), \(country!)" : country ?? "Photo Location"),
                address: city != nil && country != nil ? "\(city!), \(country!)" : country,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                category: "photo"
            )
            return [defaultLocation]
        }
        
        return []
    }
    
    // Helper to check if location is the default photo location
    func isDefaultLocation(_ location: LocationInfo) -> Bool {
        return location.id == "photo_location"
    }
    
    // MARK: - View Components
    
    private var photoPreviewSection: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .clipped()
                    .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .cornerRadius(12)
                    .overlay(
                        ProgressView()
                    )
            }
        }
    }
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Caption")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            TextField("What's happening here?", text: $caption, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Toggle("Keep private (don't sync to cloud)", isOn: $isPrivate)
                .font(.subheadline)
                .onChange(of: isPrivate) { oldValue, newValue in
                    // If switching from private to public, check authentication
                    if oldValue == true && newValue == false {
                        checkAuthenticationForSharing()
                    }
                }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var locationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            locationsHeader
            locationsList
            locationsMap
        }
        .frame(maxWidth: .infinity)
    }
    
    private var locationsHeader: some View {
        HStack {
            Text("Locations")
                .font(.headline)
            
            Spacer()
            
            Button("More") {
                showingLocationSelector = true
            }
            .font(.subheadline)
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var locationsList: some View {
        LazyVStack(spacing: 8) {
            ForEach(currentLocations, id: \.id) { location in
                locationRow(for: location)
            }
        }
    }
    
    private func locationRow(for location: LocationInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let address = location.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if !isDefaultLocation(location) {
                Button("Remove") {
                    selectedLocations.removeAll { $0.id == location.id }
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var locationsMap: some View {
        if !currentLocations.isEmpty {
            Map(coordinateRegion: .constant(getRegionForCurrentLocations()), annotationItems: currentLocations) { location in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 16, height: 16)
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
            .cornerRadius(8)
            .disabled(true) // Make map non-interactive
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
                .cornerRadius(8)
                .overlay(
                    Text("No location data")
                        .foregroundColor(.secondary)
                )
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                photoPreviewSection
                captionSection
                privacySection
                locationsSection
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .navigationTitle("Add Pin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onDismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    savePinFromPhoto()
                }
                .disabled(isSaving)
            }
        }
        .onAppear {
            loadImage()
            if let location = asset.location {
                print("📍 AddPinFromPhoto: Photo has GPS location: \(location.coordinate)")
                reverseGeocodeLocation(location)
            } else {
                print("📍 AddPinFromPhoto: Photo has no GPS location data")
            }
            print("📍 AddPinFromPhoto: Selected locations count: \(selectedLocations.count)")
            print("📍 AddPinFromPhoto: Current locations count: \(currentLocations.count)")
        }
        .sheet(isPresented: $showingAuthentication) {
            AuthenticationView()
        }
        .sheet(isPresented: $showingLocationSelector) {
            NavigationView {
                NearbyLocationsView(
                    searchLocation: asset.location?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to San Francisco if no GPS
                    locationName: placeName ?? (asset.location != nil ? "this location" : "nearby locations"),
                    isSelectMode: true,
                    selectedLocations: $selectedLocations
                )
            }
        }
    }
    
    private func checkAuthenticationForSharing() {
        let authenticationService = AuthenticationService.shared
        guard authenticationService.currentAccount != nil && authenticationService.currentSession != nil else {
            print("❌ Authentication required for sharing pins")
            showingAuthentication = true
            // Revert to private if authentication fails
            isPrivate = true
            return
        }
        print("✅ Authentication verified for sharing")
    }
    
    private func loadImage() {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        
        imageManager.requestImage(for: asset, targetSize: CGSize(width: 400, height: 400), contentMode: .aspectFill, options: options) { loadedImage, _ in
            DispatchQueue.main.async {
                image = loadedImage
            }
        }
    }
    
    private func savePinFromPhoto() {
        isSaving = true
        
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        imageManager.requestImage(for: asset, targetSize: CGSize(width: 1024, height: 1024), contentMode: .aspectFit, options: options) { image, _ in
            guard let image = image,
                  let imageData = image.jpegData(compressionQuality: 0.8) else {
                DispatchQueue.main.async {
                    isSaving = false
                }
                return
            }
            
            Task {
                do {
                    print("📍 AddPinFromPhoto: Saving pin with CloudSyncService")
                    
                    let place = try await cloudSyncService.savePinAndSyncToCloud(
                        imageData: imageData,
                        location: asset.location,
                        caption: caption,
                        isPrivate: isPrivate,
                        locations: currentLocations.isEmpty ? nil : currentLocations,
                        context: viewContext,
                        pinDate: Date()
                    )
                    
                    await MainActor.run {
                        isSaving = false
                        onDismiss()
                    }
                    
                    print("✅ AddPinFromPhoto: Pin saved and synced successfully")
                } catch {
                    print("❌ AddPinFromPhoto: Failed to save pin: \(error)")
                    await MainActor.run {
                        isSaving = false
                    }
                }
            }
        }
    }
    
    private func getRegionForCurrentLocations() -> MKCoordinateRegion {
        let locations = currentLocations
        guard !locations.isEmpty else {
            // Default region if no locations
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        if locations.count == 1 {
            // Single location - center on it
            let location = locations[0]
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        // Multiple locations - find bounding box
        let latitudes = locations.map { $0.latitude }
        let longitudes = locations.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        let spanLat = max(maxLat - minLat, 0.01) * 1.5 // Add padding
        let spanLon = max(maxLon - minLon, 0.01) * 1.5 // Add padding
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
    }

    private func getRegionForSelectedLocations() -> MKCoordinateRegion {
        guard !selectedLocations.isEmpty else {
            // Default region if no locations
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        if selectedLocations.count == 1 {
            // Single location - center on it
            let location = selectedLocations[0]
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
        
        // Multiple locations - find bounding box
        let latitudes = selectedLocations.map { $0.latitude }
        let longitudes = selectedLocations.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        let spanLat = max(maxLat - minLat, 0.01) * 1.5 // Add padding
        let spanLon = max(maxLon - minLon, 0.01) * 1.5 // Add padding
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
    }

    private func reverseGeocodeLocation(_ location: CLLocation) {
        isLoadingLocation = true
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                self.isLoadingLocation = false
                
                if let error = error {
                    print("❌ Reverse geocoding failed: \(error)")
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    print("ℹ️ No placemark found")
                    return
                }
                
                // Extract place information
                self.placeName = placemark.name
                self.city = placemark.locality ?? placemark.administrativeArea
                self.country = placemark.country
                
                print("🗺️ Geocoded location:")
                print("  Place: \(placemark.name ?? "None")")
                print("  City: \(placemark.locality ?? "None")")
                print("  Country: \(placemark.country ?? "None")")
            }
        }
    }
}

