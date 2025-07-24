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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Photo preview
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
                
                // Caption input
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
                
                // Selected locations display
                if !selectedLocations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Locations")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(selectedLocations, id: \.id) { location in
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
                                    Button("Remove") {
                                        selectedLocations.removeAll { $0.id == location.id }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Privacy setting
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
                
                // Location info with map
                if let location = asset.location {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Location info with reverse geocoding
                        VStack(alignment: .leading, spacing: 4) {
                            if isLoadingLocation {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Finding location...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else if let placeName = placeName {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(placeName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        if let city = city, let country = country {
                                            Text("\(city), \(country)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else if let country = country {
                                            Text(country)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                            } else if let city = city, let country = country {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.blue)
                                    Text("\(city), \(country)")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            } else if let country = country {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.blue)
                                    Text(country)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            } else {
                                // Fallback to coordinates
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.blue)
                                    Text(String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospaced()
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Spacer()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Mini map (clickable)
                        Button(action: {
                            showingLocationSelector = true
                        }) {
                            Map(coordinateRegion: .constant(MKCoordinateRegion(
                                center: location.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )), annotationItems: [MapPin(coordinate: location.coordinate)]) { pin in
                                MapMarker(coordinate: pin.coordinate, tint: .red)
                            }
                            .frame(maxWidth: .infinity, maxHeight: 150)
                            .cornerRadius(8)
                            .disabled(true) // Disable map interaction, use button instead
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack {
                            Image(systemName: "location.slash")
                                .foregroundColor(.orange)
                            Text("No location data available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                }
                
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
                reverseGeocodeLocation(location)
            }
        }
        .sheet(isPresented: $showingAuthentication) {
            AuthenticationView()
        }
        .sheet(isPresented: $showingLocationSelector) {
            if let location = asset.location {
                NavigationView {
                    NearbyLocationsPageView(
                        searchLocation: location.coordinate,
                        locationName: placeName ?? "this location",
                        isSelectMode: true,
                        selectedLocations: $selectedLocations
                    )
                }
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
                        context: viewContext
                    )
                    
                    // Save selected locations as JSON
                    if !selectedLocations.isEmpty {
                        let locationsData = try JSONEncoder().encode(selectedLocations)
                        let locationsJSON = String(data: locationsData, encoding: .utf8)
                        place.locations = locationsJSON
                        try viewContext.save()
                    }
                    
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

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
