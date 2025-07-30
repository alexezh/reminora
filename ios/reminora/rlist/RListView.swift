import SwiftUI
import Photos
import CoreData
import CoreLocation
import MapKit

// MARK: - RListView Item Protocol
protocol RListViewItem: Identifiable {
    var id: String { get }
    var date: Date { get }
    var itemType: RRListItemDataType { get }
}

enum RRListItemDataType {
    case photo(PHAsset)
    case photoStack([PHAsset])
    case pin(PinData)
    case location(LocationInfo)
}

// MARK: - RListView Item Implementations
struct RListPhotoItem: RListViewItem {
    let id: String
    let date: Date
    let itemType: RRListItemDataType
    
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.date = asset.creationDate ?? Date()
        self.itemType = .photo(asset)
    }
}

struct RListPhotoStackItem: RListViewItem {
    let id: String
    let date: Date
    let itemType: RRListItemDataType
    
    init(assets: [PHAsset]) {
        self.id = assets.map { $0.localIdentifier }.joined(separator: "-")
        self.date = assets.first?.creationDate ?? Date()
        self.itemType = .photoStack(assets)
    }
}

struct RListPinItem: RListViewItem {
    let id: String
    let date: Date
    let itemType: RRListItemDataType
    
    init(place: PinData) {
        self.id = place.objectID.uriRepresentation().absoluteString
        self.date = place.dateAdded ?? Date()
        self.itemType = .pin(place)
    }
}

struct RListLocationItem: RListViewItem {
    let id: String
    let date: Date
    let itemType: RRListItemDataType
    
    init(location: LocationInfo) {
        self.id = location.id
        self.date = Date() // Use current date for shared locations
        self.itemType = .location(location)
    }
}

// MARK: - RListView Data Source
enum RListDataSource {
    case photoLibrary([PHAsset])
    case userList(RListData, [PinData])
    case nearbyPhotos([PHAsset])
    case pins([PinData])
    case locations([LocationInfo])
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
    let onPinTap: (PinData) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    let onLocationTap: ((LocationInfo) -> Void)?
    let onDeleteItem: ((any RListViewItem) -> Void)?
    let onUserTap: ((String, String) -> Void)?
    
    init(
        dataSource: RListDataSource,
        onPhotoTap: @escaping (PHAsset) -> Void,
        onPinTap: @escaping (PinData) -> Void,
        onPhotoStackTap: @escaping ([PHAsset]) -> Void,
        onLocationTap: ((LocationInfo) -> Void)? = nil,
        onDeleteItem: ((any RListViewItem) -> Void)? = nil,
        onUserTap: ((String, String) -> Void)? = nil
    ) {
        self.dataSource = dataSource
        self.onPhotoTap = onPhotoTap
        self.onPinTap = onPinTap
        self.onPhotoStackTap = onPhotoStackTap
        self.onLocationTap = onLocationTap
        self.onDeleteItem = onDeleteItem
        self.onUserTap = onUserTap
    }
    
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
                            onLocationTap: onLocationTap,
                            onDeleteItem: onDeleteItem,
                            onUserTap: onUserTap
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
    let onPinTap: (PinData) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    let onLocationTap: ((LocationInfo) -> Void)?
    let onDeleteItem: ((any RListViewItem) -> Void)?
    let onUserTap: ((String, String) -> Void)?
    
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
                        onLocationTap: onLocationTap,
                        onDeleteItem: onDeleteItem,
                        onUserTap: onUserTap
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
    let onPinTap: (PinData) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    let onLocationTap: ((LocationInfo) -> Void)?
    let onDeleteItem: ((any RListViewItem) -> Void)?
    let onUserTap: ((String, String) -> Void)?
    
    var body: some View {
        switch row.type {
        case .photoRow:
            GeometryReader { geometry in
                let spacing: CGFloat = 4
                let totalSpacing = spacing * CGFloat(max(0, row.items.count - 1))
                let availableWidth = geometry.size.width - totalSpacing
                let itemWidth = availableWidth / CGFloat(row.items.count)
                
                HStack(spacing: spacing) {
                    ForEach(Array(row.items.enumerated()), id: \.offset) { _, item in
                        RListPhotoGridItemView(
                            item: item,
                            onPhotoTap: onPhotoTap,
                            onPhotoStackTap: onPhotoStackTap
                        )
                        .frame(width: itemWidth, height: itemWidth)
                        .clipped()
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            .aspectRatio(CGFloat(row.items.count), contentMode: .fit) // Maintain aspect ratio based on item count
            
        case .pinRow:
            ForEach(row.items, id: \.id) { item in
                RRListItemDataView(
                    item: item,
                    onPhotoTap: onPhotoTap,
                    onPinTap: onPinTap,
                    onPhotoStackTap: onPhotoStackTap,
                    onLocationTap: onLocationTap,
                    onDeleteItem: onDeleteItem,
                    onUserTap: onUserTap
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

// MARK: - RRListItemDataView
struct RRListItemDataView: View {
    let item: any RListViewItem
    let onPhotoTap: (PHAsset) -> Void
    let onPinTap: (PinData) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    let onLocationTap: ((LocationInfo) -> Void)?
    let onDeleteItem: ((any RListViewItem) -> Void)?
    let onUserTap: ((String, String) -> Void)?
    
    var body: some View {
        switch item.itemType {
        case .photo(let asset):
            RListPhotoView(asset: asset, onTap: { onPhotoTap(asset) })
        case .photoStack(let assets):
            RListPhotoStackView(assets: assets, onTap: { onPhotoStackTap(assets) })
        case .pin(let place):
            VStack(spacing: 0) {
                PinCardView(
                    place: place,
                    cardHeight: 200,
                    onPhotoTap: { onPinTap(place) },
                    onTitleTap: { onPinTap(place) },
                    onMapTap: { onPinTap(place) },
                    onUserTap: { userId, userName in
                        onUserTap?(userId, userName)
                    }
                )
                
                // Add delete button if delete is supported
                if let onDeleteItem = onDeleteItem {
                    HStack {
                        Spacer()
                        Button(action: { onDeleteItem(item) }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove")
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        case .location(let location):
            RListLocationView(location: location, onTap: { onLocationTap?(location) }, onDelete: onDeleteItem != nil ? { onDeleteItem!(item) } : nil)
        }
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        onLocationTap: { _ in },
        onDeleteItem: { _ in },
        onUserTap: { _, _ in }
    )
}
