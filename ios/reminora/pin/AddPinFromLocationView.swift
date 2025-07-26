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
    let location: NearbyLocation
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var caption: String = ""
    @State private var isSaving = false
    @State private var isPrivate = false
    
    private let cloudSyncService = CloudSyncService.shared
    
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
                        
                        Text(location.address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text(String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))
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
                    HStack {
                        Text("Privacy")
                            .font(.headline)
                        
                        Spacer()
                        
                        Toggle("Private pin", isOn: $isPrivate)
                            .labelsHidden()
                    }
                    
                    if isPrivate {
                        Text("Private pins are only visible to you")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Public pins can be seen by others")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
                // Create LocationInfo from NearbyLocation
                let locationInfo = LocationInfo(from: location)
                
                // Create placeholder image data for location pins
                let placeholderImageData = createLocationPlaceholderImageData()
                
                // Save the pin using CloudSyncService for proper cloud sync
                let place = try await cloudSyncService.savePinAndSyncToCloud(
                    imageData: placeholderImageData,
                    location: CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
                    caption: caption.isEmpty ? location.name : caption,
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
    
    private func createLocationPlaceholderImageData() -> Data {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Create a location-themed placeholder
            UIColor.systemBlue.withAlphaComponent(0.2).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add location pin icon
            let iconSize: CGFloat = 80
            let iconRect = CGRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            
            UIColor.systemBlue.setFill()
            let iconPath = UIBezierPath(ovalIn: iconRect)
            iconPath.fill()
            
            // Add pin symbol
            let text = "📍"
            let font = UIFont.systemFont(ofSize: 40)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
}