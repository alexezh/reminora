import SwiftUI
import Photos
import CoreData

// MARK: - RListExampleView
struct RListExampleView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedAsset: PHAsset?
    @State private var selectedPlace: PinData?
    @State private var showingPinDetail = false
    
    // Example data sources
    let exampleDataSource: RListDataSource
    
    init(dataSource: RListDataSource = .mixed([])) {
        self.exampleDataSource = dataSource
    }
    
    var body: some View {
        NavigationView {
            RListView(
                dataSource: exampleDataSource,
                onPhotoTap: { asset in
                    selectedAsset = asset
                },
                onPinTap: { place in
                    selectedPlace = place
                    showingPinDetail = true
                },
                onPhotoStackTap: { assets in
                    // For photo stacks, show the first photo
                    if let firstAsset = assets.first {
                        selectedAsset = firstAsset
                    }
                },
                onLocationTap: { location in
                    // Handle location tap if needed
                    print("Location tapped: \(location.name)")
                }
            )
            .navigationTitle("RList Demo")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingPinDetail) {
            if let place = selectedPlace {
                NavigationView {
                    PinDetailView(
                        place: place,
                        allPlaces: [],
                        onBack: {
                            showingPinDetail = false
                            selectedPlace = nil
                        }
                    )
                }
            }
        }
    }
}

// MARK: - RListView Usage Examples
extension RListExampleView {
    
    // Example: Photo Library View
    static func photoLibraryExample(with assets: [PHAsset]) -> RListExampleView {
        RListExampleView(dataSource: .photoLibrary(assets))
    }
    
    // Example: User List View
    static func userListExample(with list: RListData, places: [PinData]) -> RListExampleView {
        RListExampleView(dataSource: .userList(list, places))
    }
    
    // Example: Nearby Photos View
    static func nearbyPhotosExample(with assets: [PHAsset]) -> RListExampleView {
        RListExampleView(dataSource: .nearbyPhotos(assets))
    }
    
    // Example: Pins Only View
    static func pinsOnlyExample(with places: [PinData]) -> RListExampleView {
        RListExampleView(dataSource: .pins(places))
    }
    
    // Example: Mixed Content View
    static func mixedContentExample(with items: [any RListViewItem]) -> RListExampleView {
        RListExampleView(dataSource: .mixed(items))
    }
}

// MARK: - RListView Integration Helpers
extension RListView {
    
    // Helper initializer for Photo Library integration
    static func photoLibraryView(
        assets: [PHAsset],
        onPhotoTap: @escaping (PHAsset) -> Void,
        onPhotoStackTap: @escaping ([PHAsset]) -> Void
    ) -> RListView {
        RListView(
            dataSource: .photoLibrary(assets),
            onPhotoTap: onPhotoTap,
            onPinTap: { _ in }, // No pins in photo library
            onPhotoStackTap: onPhotoStackTap,
            onLocationTap: nil // No locations in photo library
        )
    }
    
    // Helper initializer for User List integration
    static func userListView(
        list: RListData,
        places: [PinData],
        onPinTap: @escaping (PinData) -> Void
    ) -> RListView {
        RListView(
            dataSource: .userList(list, places),
            onPhotoTap: { _ in }, // No photos in user lists
            onPinTap: onPinTap,
            onPhotoStackTap: { _ in },
            onLocationTap: nil // No locations in basic user lists
        )
    }
    
    // Helper initializer for Nearby Photos integration
    static func nearbyPhotosView(
        assets: [PHAsset],
        onPhotoTap: @escaping (PHAsset) -> Void,
        onPhotoStackTap: @escaping ([PHAsset]) -> Void
    ) -> RListView {
        RListView(
            dataSource: .nearbyPhotos(assets),
            onPhotoTap: onPhotoTap,
            onPinTap: { _ in }, // No pins in nearby photos
            onPhotoStackTap: onPhotoStackTap,
            onLocationTap: nil // No locations in nearby photos
        )
    }
    
    // Helper initializer for mixed content (photos and pins)
    static func mixedContentView(
        items: [any RListViewItem],
        onPhotoTap: @escaping (PHAsset) -> Void,
        onPinTap: @escaping (PinData) -> Void,
        onPhotoStackTap: @escaping ([PHAsset]) -> Void
    ) -> RListView {
        RListView(
            dataSource: .mixed(items),
            onPhotoTap: onPhotoTap,
            onPinTap: onPinTap,
            onPhotoStackTap: onPhotoStackTap,
            onLocationTap: nil // Mixed content may have locations in future
        )
    }
}

// MARK: - Preview
#Preview("Photo Library") {
    RListExampleView.photoLibraryExample(with: [])
}

#Preview("Pins Only") {
    RListExampleView.pinsOnlyExample(with: [])
}

#Preview("Mixed Content") {
    RListExampleView.mixedContentExample(with: [])
}
