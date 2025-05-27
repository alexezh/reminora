import CoreData
import MapKit
import PhotosUI
import SwiftUI

// New view for displaying all photos from the user's photo library
struct PhotoLibraryView: View {
  @Binding var isPresented: Bool
  @State private var selection: [PhotosPickerItem] = []

  var body: some View {
    NavigationView {
      PhotosPicker(
        selection: $selection,
        matching: .images
      ) {
        VStack {
          Image(systemName: "photo.on.rectangle.angled")
            .resizable()
            .scaledToFit()
            .frame(width: 80, height: 80)
            .foregroundColor(.accentColor)
          Text("Browse your photo library")
            .font(.headline)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
      }
      .navigationTitle("Photo Library")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            isPresented = false
          }
        }
      }
    }
  }
}
