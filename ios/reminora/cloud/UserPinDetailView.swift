import SwiftUI
import MapKit
import CoreData

struct UserPinDetailView: View {
    let pin: UserPin
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var region: MKCoordinateRegion
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    
    init(pin: UserPin, onDismiss: @escaping () -> Void) {
        self.pin = pin
        self.onDismiss = onDismiss
        
        // Initialize region centered on the pin
        self._region = State(
            initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Action buttons at top
                    HStack {
                        Spacer()
                        
                        Button(action: sharePin) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                        }
                        
                        Button(action: savePin) {
                            HStack(spacing: 4) {
                                if isSaving {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: showingSaveSuccess ? "checkmark" : "plus")
                                }
                                Text(showingSaveSuccess ? "Saved" : "Save")
                            }
                            .font(.caption)
                            .foregroundColor(showingSaveSuccess ? .green : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(showingSaveSuccess ? Color.green.opacity(0.2) : Color.blue)
                            .cornerRadius(16)
                        }
                        .disabled(isSaving || showingSaveSuccess)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    
                    // Pin image placeholder (full width)
                    if let imageUrl = pin.imageUrl, !imageUrl.isEmpty {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxHeight: 400)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 300)
                                .overlay(
                                    ProgressView()
                                )
                        }
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 300)
                            .overlay(
                                VStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.blue)
                                    Text(pin.name)
                                        .font(.headline)
                                        .padding(.top, 8)
                                }
                            )
                    }
                    
                    // Pin details
                    VStack(alignment: .leading, spacing: 12) {
                        // Pin name and description
                        VStack(alignment: .leading, spacing: 8) {
                            Text(pin.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            if let description = pin.description, !description.isEmpty {
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Date
                        HStack {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(pin.createdAt, formatter: itemFormatter)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        // Map showing pin location
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("Location")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            
                            Map(coordinateRegion: .constant(region), annotationItems: [PinAnnotation(pin: pin)]) { annotation in
                                MapAnnotation(coordinate: annotation.coordinate) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                }
                            }
                            .frame(height: 200)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            
                            // Coordinates
                            HStack {
                                Image(systemName: "location")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(String(format: "%.6f, %.6f", pin.latitude, pin.longitude))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .monospaced()
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save Pin") {
                        savePin()
                    }
                    .disabled(isSaving || showingSaveSuccess)
                }
            }
        }
    }
    
    private func savePin() {
        guard !isSaving else { return }
        
        isSaving = true
        
        Task {
            do {
                print("💾 Saving pin: \(pin.name)")
                
                // Create a new place from the user pin
                let newPlace = Place(context: viewContext)
                newPlace.dateAdded = Date()
                newPlace.post = "\(pin.name)\n\(pin.description ?? "")"
                newPlace.url = "Saved from @\(authService.currentAccount?.handle ?? "user") pin"
                
                // Store location
                let location = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
                if let locationData = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: false) {
                    newPlace.setValue(locationData, forKey: "location")
                }
                
                // TODO: Download and store image if imageUrl is available
                if let imageUrl = pin.imageUrl, !imageUrl.isEmpty {
                    // For now, we'll just mark it as having an external image
                    // In a real implementation, you'd download and store the image
                    print("💾 Note: Image URL available but not downloaded: \(imageUrl)")
                }
                
                try viewContext.save()
                
                await MainActor.run {
                    self.isSaving = false
                    self.showingSaveSuccess = true
                    print("💾 ✅ Successfully saved pin: \(pin.name)")
                    
                    // Hide success state after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.showingSaveSuccess = false
                    }
                    
                    // Provide haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
                
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    print("💾 ❌ Failed to save pin: \(error)")
                }
            }
        }
    }
    
    private func sharePin() {
        // Create a share URL for this pin
        let shareText = "Check out \(pin.name) on Reminora!"
        let shareUrl = "reminora://pin/\(pin.id)?name=\(pin.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&lat=\(pin.latitude)&lon=\(pin.longitude)"
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText, shareUrl],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

struct PinAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    
    init(pin: UserPin) {
        self.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    UserPinDetailView(
        pin: UserPin(
            id: "test123",
            name: "Test Pin",
            description: "This is a test pin for preview",
            latitude: 37.7749,
            longitude: -122.4194,
            imageUrl: nil,
            createdAt: Date(),
            isPublic: true
        ),
        onDismiss: {}
    )
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}