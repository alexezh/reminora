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
    @State private var image: UIImage?
    @State private var caption: String = ""
    @State private var isSaving = false
    @State private var isPrivate = false
    
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
                
                // Privacy setting
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Toggle("Keep private (don't sync to cloud)", isOn: $isPrivate)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                
                // Location info with map
                if let location = asset.location {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Coordinates
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
                        .frame(maxWidth: .infinity)
                        
                        // Mini map
                        Map(coordinateRegion: .constant(MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )), annotationItems: [MapPin(coordinate: location.coordinate)]) { pin in
                            MapMarker(coordinate: pin.coordinate, tint: .red)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 150)
                        .cornerRadius(8)
                        .disabled(true) // Make map non-interactive
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
        }
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
                    
                    _ = try await cloudSyncService.savePinAndSyncToCloud(
                        imageData: imageData,
                        location: asset.location,
                        caption: caption,
                        isPrivate: isPrivate,
                        context: viewContext
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
}
