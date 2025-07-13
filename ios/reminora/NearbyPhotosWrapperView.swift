import CoreData
import MapKit
import SwiftUI

struct NearbyPhotosWrapperView: View {
    @State private var showingPhotos = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Main content can go here - for now, just the Photos button
                Button(action: {
                    showingPhotos = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Photos")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Pins")
            .sheet(isPresented: $showingPhotos) {
                NearbyPhotosGridView(centerLocation: nil)
            }
        }
    }
}

#Preview {
    NearbyPhotosWrapperView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
