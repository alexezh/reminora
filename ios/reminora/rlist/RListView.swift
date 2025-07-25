import SwiftUI
import Photos
import CoreData
import CoreLocation
import MapKit

// MARK: - RListView Item Protocol
protocol RListViewItem: Identifiable {
    var id: String { get }
    var date: Date { get }
    var itemType: RListItemType { get }
}

enum RListItemType {
    case photo(PHAsset)
    case photoStack([PHAsset])
    case pin(Place)
    case location(NearbyLocation)
}

// MARK: - RListView Item Implementations
struct RListPhotoItem: RListViewItem {
    let id: String
    let date: Date
    let itemType: RListItemType
    
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.date = asset.creationDate ?? Date()
        self.itemType = .photo(asset)
    }
}

struct RListPhotoStackItem: RListViewItem {
    let id: String
    let date: Date
    let itemType: RListItemType
    
    init(assets: [PHAsset]) {
        self.id = assets.map { $0.localIdentifier }.joined(separator: "-")
        self.date = assets.first?.creationDate ?? Date()
        self.itemType = .photoStack(assets)
    }
}

struct RListPinItem: RListViewItem {
    let id: String
    let date: Date
    let itemType: RListItemType
    
    init(place: Place) {
        self.id = place.objectID.uriRepresentation().absoluteString
        self.date = place.dateAdded ?? Date()
        self.itemType = .pin(place)
    }
}

struct RListLocationItem: RListViewItem {
    let id: String
    let date: Date
    let itemType: RListItemType
    
    init(location: NearbyLocation) {
        self.id = location.id
        self.date = Date() // Use current date for shared locations
        self.itemType = .location(location)
    }
}

// MARK: - RListView Data Source
enum RListDataSource {
    case photoLibrary([PHAsset])
    case userList(UserList, [Place])
    case nearbyPhotos([PHAsset])
    case pins([Place])
    case locations([NearbyLocation])
    case mixed([any RListViewItem])
}

// MARK: - Date Section
struct RListDateSection: Identifiable {
    let id: String
    let date: Date
    let title: String
    let items: [any RListViewItem]
    
    init(date: Date, items: [any RListViewItem]) {
        self.date = date
        self.title = RListDateSection.formatDate(date)
        self.id = title
        self.items = items
    }
    
    private static func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day of week
            return formatter.string(from: date)
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d" // Apr 1
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy" // Apr 1, 2023
            return formatter.string(from: date)
        }
    }
}

// MARK: - RListView
struct RListView: View {
    let dataSource: RListDataSource
    let onPhotoTap: (PHAsset) -> Void
    let onPinTap: (Place) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    let onLocationTap: ((NearbyLocation) -> Void)?
    
    @State private var sections: [RListDateSection] = []
    @State private var isLoading = true
    
    // Photo stack grouping interval (in minutes)
    private let stackingInterval: TimeInterval = 10 * 60 // 10 minutes
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else if sections.isEmpty {
                    EmptyStateView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else {
                    ForEach(sections) { section in
                        RListSectionView(
                            section: section,
                            onPhotoTap: onPhotoTap,
                            onPinTap: onPinTap,
                            onPhotoStackTap: onPhotoStackTap,
                            onLocationTap: onLocationTap
                        )
                    }
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        await MainActor.run {
            isLoading = true
        }
        
        let items = await processDataSource()
        let groupedSections = groupItemsByDate(items)
        
        await MainActor.run {
            self.sections = groupedSections
            self.isLoading = false
        }
    }
    
    private func processDataSource() async -> [any RListViewItem] {
        switch dataSource {
        case .photoLibrary(let assets):
            return await processPhotoAssets(assets)
        case .userList(_, let places):
            return places.map { RListPinItem(place: $0) }
        case .nearbyPhotos(let assets):
            return await processPhotoAssets(assets)
        case .pins(let places):
            return places.map { RListPinItem(place: $0) }
        case .locations(let locations):
            return locations.map { RListLocationItem(location: $0) }
        case .mixed(let items):
            return items
        }
    }
    
    private func processPhotoAssets(_ assets: [PHAsset]) async -> [any RListViewItem] {
        // Sort assets by creation date
        let sortedAssets = assets.sorted { 
            ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast)
        }
        
        var items: [any RListViewItem] = []
        var currentStack: [PHAsset] = []
        
        for asset in sortedAssets {
            let assetDate = asset.creationDate ?? Date()
            
            if let lastAsset = currentStack.last,
               let lastDate = lastAsset.creationDate {
                let timeDifference = abs(assetDate.timeIntervalSince(lastDate))
                
                if timeDifference <= stackingInterval && currentStack.count < 3 {
                    // Add to current stack
                    currentStack.append(asset)
                } else {
                    // Finalize current stack and start new one
                    if currentStack.count == 1 {
                        items.append(RListPhotoItem(asset: currentStack[0]))
                    } else if currentStack.count > 1 {
                        items.append(RListPhotoStackItem(assets: currentStack))
                    }
                    currentStack = [asset]
                }
            } else {
                // First asset or no date
                currentStack = [asset]
            }
        }
        
        // Handle remaining stack
        if currentStack.count == 1 {
            items.append(RListPhotoItem(asset: currentStack[0]))
        } else if currentStack.count > 1 {
            items.append(RListPhotoStackItem(assets: currentStack))
        }
        
        return items
    }
    
    private func groupItemsByDate(_ items: [any RListViewItem]) -> [RListDateSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.date)
        }
        
        return grouped.map { date, items in
            RListDateSection(date: date, items: items.sorted { $0.date > $1.date })
        }.sorted { $0.date > $1.date }
    }
}

// MARK: - RListSectionView
struct RListSectionView: View {
    let section: RListDateSection
    let onPhotoTap: (PHAsset) -> Void
    let onPinTap: (Place) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    let onLocationTap: ((NearbyLocation) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Date separator
            HStack {
                Text(section.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            
            // Items in this section with custom layout
            LazyVStack(spacing: 8) {
                ForEach(Array(arrangeItemsInRows().enumerated()), id: \.offset) { _, row in
                    RListRowView(
                        row: row,
                        onPhotoTap: onPhotoTap,
                        onPinTap: onPinTap,
                        onPhotoStackTap: onPhotoStackTap,
                        onLocationTap: onLocationTap
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    private func arrangeItemsInRows() -> [RListRow] {
        var rows: [RListRow] = []
        var currentPhotoRow: [any RListViewItem] = []
        
        for item in section.items {
            switch item.itemType {
            case .photo(_), .photoStack(_):
                // Add photo to current row
                currentPhotoRow.append(item)
                
                // If we have 3 photos, create a row
                if currentPhotoRow.count == 3 {
                    rows.append(RListRow(items: currentPhotoRow, type: .photoRow))
                    currentPhotoRow = []
                }
                
            case .pin(_), .location(_):
                // Finish any pending photo row first
                if !currentPhotoRow.isEmpty {
                    rows.append(RListRow(items: currentPhotoRow, type: .photoRow))
                    currentPhotoRow = []
                }
                
                // Add pin or location as its own row
                rows.append(RListRow(items: [item], type: .pinRow))
            }
        }
        
        // Add any remaining photos as a row
        if !currentPhotoRow.isEmpty {
            rows.append(RListRow(items: currentPhotoRow, type: .photoRow))
        }
        
        return rows
    }
}

// MARK: - RListRow
struct RListRow {
    let items: [any RListViewItem]
    let type: RListRowType
}

enum RListRowType {
    case photoRow  // 1-3 photos in a horizontal row
    case pinRow    // Single pin taking full width
}

// MARK: - RListRowView
struct RListRowView: View {
    let row: RListRow
    let onPhotoTap: (PHAsset) -> Void
    let onPinTap: (Place) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    let onLocationTap: ((NearbyLocation) -> Void)?
    
    var body: some View {
        switch row.type {
        case .photoRow:
            HStack(spacing: 4) {
                ForEach(Array(row.items.enumerated()), id: \.offset) { _, item in
                    RListPhotoGridItemView(
                        item: item,
                        onPhotoTap: onPhotoTap,
                        onPhotoStackTap: onPhotoStackTap
                    )
                }
                
                // Fill remaining space if less than 3 photos
                if row.items.count < 3 {
                    ForEach(0..<(3 - row.items.count), id: \.self) { _ in
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            
        case .pinRow:
            ForEach(row.items, id: \.id) { item in
                RListItemView(
                    item: item,
                    onPhotoTap: onPhotoTap,
                    onPinTap: onPinTap,
                    onPhotoStackTap: onPhotoStackTap,
                    onLocationTap: onLocationTap
                )
            }
        }
    }
}

// MARK: - RListPhotoGridItemView
struct RListPhotoGridItemView: View {
    let item: any RListViewItem
    let onPhotoTap: (PHAsset) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    
    var body: some View {
        switch item.itemType {
        case .photo(let asset):
            RListPhotoGridView(asset: asset, onTap: { onPhotoTap(asset) })
        case .photoStack(let assets):
            RListPhotoStackGridView(assets: assets, onTap: { onPhotoStackTap(assets) })
        case .pin(_), .location(_):
            // This shouldn't happen in photo rows, but handle gracefully
            EmptyView()
        }
    }
}

// MARK: - RListItemView
struct RListItemView: View {
    let item: any RListViewItem
    let onPhotoTap: (PHAsset) -> Void
    let onPinTap: (Place) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    let onLocationTap: ((NearbyLocation) -> Void)?
    
    var body: some View {
        switch item.itemType {
        case .photo(let asset):
            RListPhotoView(asset: asset, onTap: { onPhotoTap(asset) })
        case .photoStack(let assets):
            RListPhotoStackView(assets: assets, onTap: { onPhotoStackTap(assets) })
        case .pin(let place):
            RListPinView(place: place, onTap: { onPinTap(place) })
        case .location(let location):
            RListLocationView(location: location, onTap: { onLocationTap?(location) })
        }
    }
}

// MARK: - Individual Item Views
struct RListPhotoView: View {
    let asset: PHAsset
    let onTap: () -> Void
    
    @State private var image: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        await withCheckedContinuation { continuation in
            var hasResumed = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 400, height: 400),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                
                if !isDegraded {
                    hasResumed = true
                    self.image = image
                    continuation.resume()
                } else if image == nil {
                    hasResumed = true
                    continuation.resume()
                }
            }
        }
    }
}

struct RListPhotoStackView: View {
    let assets: [PHAsset]
    let onTap: () -> Void
    
    @State private var images: [UIImage?] = []
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                ForEach(Array(assets.prefix(3).enumerated()), id: \.offset) { index, asset in
                    if index < images.count, let image = images[index] {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 120)
                            .cornerRadius(8)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.7)
                            )
                    }
                }
                if assets.count > 3 {
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                        .frame(height: 120)
                        .cornerRadius(8)
                        .overlay(
                            Text("+\(assets.count - 3)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadImages()
        }
    }
    
    private func loadImages() async {
        images = Array(repeating: nil, count: min(assets.count, 3))
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        for (index, asset) in assets.prefix(3).enumerated() {
            await withCheckedContinuation { continuation in
                var hasResumed = false
                
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: CGSize(width: 200, height: 200),
                    contentMode: .aspectFill,
                    options: options
                ) { image, info in
                    guard !hasResumed else { return }
                    
                    let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                    
                    if !isDegraded {
                        hasResumed = true
                        DispatchQueue.main.async {
                            if index < self.images.count {
                                self.images[index] = image
                            }
                        }
                        continuation.resume()
                    } else if image == nil {
                        hasResumed = true
                        continuation.resume()
                    }
                }
            }
        }
    }
}

struct RListPinView: View {
    let place: Place
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Pin image or placeholder
                Group {
                    if let imageData = place.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(8)
                            .onAppear {
                                print("🖼️ RListPinView: Displaying image for place '\(place.post ?? "nil")' - \(imageData.count) bytes")
                            }
                    } else {
                        Rectangle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            )
                            .onAppear {
                                print("❌ RListPinView: No image data for place '\(place.post ?? "nil")' - imageData: \(place.imageData?.count ?? 0) bytes")
                            }
                    }
                }
                
                // Pin details
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.post ?? "Untitled Pin")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let locationData = place.value(forKey: "coordinates") as? Data,
                       let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospaced()
                        }
                    }
                    
                    if let date = place.dateAdded {
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RListLocationView: View {
    let location: NearbyLocation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Location icon
                Rectangle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "location.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    )
                
                // Location details
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(location.address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospaced()
                    }
                    
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(String(format: "%.1f", location.distance / 1000)) km away")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Grid-specific Photo Views
struct RListPhotoGridView: View {
    let asset: PHAsset
    let onTap: () -> Void
    
    @State private var image: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(8)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        await withCheckedContinuation { continuation in
            var hasResumed = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                
                if !isDegraded {
                    hasResumed = true
                    self.image = image
                    continuation.resume()
                } else if image == nil {
                    hasResumed = true
                    continuation.resume()
                }
            }
        }
    }
}

struct RListPhotoStackGridView: View {
    let assets: [PHAsset]
    let onTap: () -> Void
    
    @State private var image: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(1, contentMode: .fit)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.7)
                        )
                }
                
                // Stack indicator overlay
                if assets.count > 1 {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: "rectangle.stack.fill")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                            .padding(6)
                        }
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let primaryAsset = assets.first else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        await withCheckedContinuation { continuation in
            var hasResumed = false
            
            PHImageManager.default().requestImage(
                for: primaryAsset,
                targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                
                if !isDegraded {
                    hasResumed = true
                    self.image = image
                    continuation.resume()
                } else if image == nil {
                    hasResumed = true
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Items Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("There are no photos or pins to display")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Preview Helper
#Preview {
    RListView(
        dataSource: .mixed([]),
        onPhotoTap: { _ in },
        onPinTap: { _ in },
        onPhotoStackTap: { _ in },
        onLocationTap: { _ in }
    )
}