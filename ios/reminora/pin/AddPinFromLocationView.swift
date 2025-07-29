//
//  AddPinFromLocationView.swift
//  reminora
//
//  Created by alexezh on 7/26/25.
//


import SwiftUI
import MapKit
import CoreData

struct AddPinFromLocationView: View {
    let location: LocationInfo
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var caption: String = ""
    @State private var isSaving = false
    @State private var isPrivate = false
    
    private let cloudSyncService = CloudSyncService.shared
    
    private var defaultCaption: String {
        let placeName = location.name
        
        // Try to extract city from address
        if let address = location.address {
            let components = address.components(separatedBy: ", ")
            // Find the city component (usually second to last, before state/country)
            if components.count >= 2 {
                let city = components[components.count - 2].trimmingCharacters(in: .whitespacesAndNewlines)
                if !city.isEmpty && city != placeName {
                    return "\(placeName), \(city)"
                }
            }
        }
        
        // Fallback to just the place name
        return placeName
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Location preview with map
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(.headline)
                    
                    // Location name and address
                    VStack(alignment: .leading, spacing: 4) {
                        Text(location.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(location.address ?? "Address not available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospaced()
                        }
                        .padding(.top, 2)
                    }
                    .padding(.bottom, 8)
                    
                    // Mini map
                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )), annotationItems: [NearbyMapAnnotationItem(coordinate: location.coordinate)]) { pin in
                        MapAnnotation(coordinate: pin.coordinate) {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 20, height: 20)
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 20, height: 20)
                            }
                        }
                    }
                    .frame(height: 200)
                    .cornerRadius(12)
                    .disabled(true) // Make map non-interactive
                }
                
                // Caption input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Caption")
                        .font(.headline)
                    
                    TextField("What's special about this place?", text: $caption, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                // Privacy toggle
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Toggle("Keep private (don't sync to cloud)", isOn: $isPrivate)
                        .font(.subheadline)
                }
                
                Spacer()
            }
            .padding()
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
                Button {
                    savePinFromLocation()
                } label: {
                    if isSaving {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Saving...")
                        }
                    } else {
                        Text("Save")
                    }
                }
                .disabled(isSaving)
            }
        }
    }
    
    private func savePinFromLocation() {
        guard !isSaving else { return }
        
        isSaving = true
        
        Task {
            do {
                // Use existing LocationInfo
                let locationInfo = location
                
                // Save the pin using CloudSyncService for proper cloud sync (no image data)
                let place = try await cloudSyncService.savePinAndSyncToCloud(
                    imageData: Data(),
                    location: CLLocation(latitude: location.latitude, longitude: location.longitude),
                    caption: caption.isEmpty ? defaultCaption : caption,
                    isPrivate: isPrivate,
                    locations: [locationInfo],
                    context: viewContext,
                    pinDate: Date()
                )
                
                await MainActor.run {
                    // Show success feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    isSaving = false
                    onDismiss()
                }
                
            } catch {
                await MainActor.run {
                    print("❌ Failed to save location pin: \(error)")
                    isSaving = false
                }
            }
        }
    }
    
}