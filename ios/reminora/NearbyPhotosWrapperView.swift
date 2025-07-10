import CoreData
import MapKit
import SwiftUI

struct NearbyPhotosWrapperView: View {
    var body: some View {
        NearbyPhotosGridView()
    }
}

#Preview {
    NearbyPhotosWrapperView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}