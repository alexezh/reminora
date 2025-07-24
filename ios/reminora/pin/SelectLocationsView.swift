import SwiftUI
import MapKit
import CoreData

struct SelectLocationsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    let initialAddresses: [PlaceAddress]
    let onSave: ([PlaceAddress]) -> Void
    
    @State private var selectedAddresses: [PlaceAddress] = []
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Location selection temporarily disabled")
                    .font(.headline)
                    .padding()
                
                Spacer()
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
            }
            .navigationTitle("Select Locations")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            selectedAddresses = initialAddresses
        }
    }
}