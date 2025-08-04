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
    case photoStack(RPhotoStack)
    case pin(PinData)
    case location(LocationInfo)
}

// MARK: - RListView Item Implementations
struct RListPhotoStackItem: RListViewItem {
    let id: String
    let date: Date
    let itemType: RRListItemDataType
    
    init(photoStack: RPhotoStack) {
        self.id = photoStack.id
        self.date = photoStack.creationDate
        self.itemType = .photoStack(photoStack)
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
    
    // Selection mode support
    let isSelectionMode: Bool
    let selectedAssets: Set<String>
    
    init(
        dataSource: RListDataSource,
        isSelectionMode: Bool = false,
        selectedAssets: Set<String> = [],
        onPhotoTap: @escaping (PHAsset) -> Void,
        onPinTap: @escaping (PinData) -> Void,
        onPhotoStackTap: @escaping ([PHAsset]) -> Void,
        onLocationTap: ((LocationInfo) -> Void)? = nil,
        onDeleteItem: ((any RListViewItem) -> Void)? = nil,
        onUserTap: ((String, String) -> Void)? = nil
    ) {
        self.dataSource = dataSource
        self.isSelectionMode = isSelectionMode
        self.selectedAssets = selectedAssets
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
                            isSelectionMode: isSelectionMode,
                            selectedAssets: selectedAssets,
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
        // Use RPhotoStack to create photo stacks
        let photoStacks = RPhotoStack.createStacks(from: assets, stackingInterval: stackingInterval, maxStackSize: 3)
        
        // Convert to RListViewItem
        return photoStacks.map { photoStack in
            RListPhotoStackItem(photoStack: photoStack)
        }
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
    let isSelectionMode: Bool
    let selectedAssets: Set<String>
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
                        isSelectionMode: isSelectionMode,
                        selectedAssets: selectedAssets,
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
            case .photoStack(_):
                // Add photo stack to current row
                currentPhotoRow.append(item)
                
                // If we have 3 photo stacks, create a row
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
    let isSelectionMode: Bool
    let selectedAssets: Set<String>
    let onPhotoTap: (PHAsset) -> Void
    let onPinTap: (PinData) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    let onLocationTap: ((LocationInfo) -> Void)?
    let onDeleteItem: ((any RListViewItem) -> Void)?
    let onUserTap: ((String, String) -> Void)?
    
    @State private var photoAspectRatios: [String: CGFloat] = [:]
    
    var body: some View {
        switch row.type {
        case .photoRow:
            GeometryReader { geometry in
                let spacing: CGFloat = 4
                let totalSpacing = spacing * CGFloat(max(0, row.items.count - 1))
                let availableWidth = geometry.size.width - totalSpacing
                let maxRowHeight: CGFloat = 200 // Maximum allowed height for any row
                
                // Calculate optimal height for this specific row
                let rowHeight = calculateOptimalRowHeight(availableWidth: availableWidth, maxHeight: maxRowHeight)
                
                // Calculate widths based on aspect ratios
                let widths = calculatePhotoWidths(availableWidth: availableWidth, rowHeight: rowHeight)
                
                HStack(spacing: spacing) {
                    ForEach(Array(row.items.enumerated()), id: \.offset) { index, item in
                        let width = widths.indices.contains(index) ? widths[index] : rowHeight
                        
                        if case .photoStack(let photoStack) = item.itemType {
                            RListPhotoView(
                                photoStack: photoStack,
                                isSelectionMode: isSelectionMode,
                                selectedAssets: selectedAssets,
                                onTap: {
                                    if photoStack.isSinglePhoto {
                                        onPhotoTap(photoStack.primaryAsset)
                                    } else {
                                        onPhotoStackTap(photoStack.assets)
                                    }
                                },
                                onAspectRatioCalculated: { aspectRatio in
                                    photoAspectRatios[item.id] = aspectRatio
                                }
                            )
                            .frame(width: width, height: rowHeight)
                            .clipped()
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            .frame(height: calculateOptimalRowHeight(availableWidth: UIScreen.main.bounds.width - 32, maxHeight: 200)) // Dynamic height per row
            
        case .pinRow:
            ForEach(row.items, id: \.id) { item in
                RRListItemDataView(
                    item: item,
                    isSelectionMode: isSelectionMode,
                    selectedAssets: selectedAssets,
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
    
    private func calculatePhotoWidths(availableWidth: CGFloat, rowHeight: CGFloat) -> [CGFloat] {
        var widths: [CGFloat] = []
        var totalAspectRatio: CGFloat = 0
        
        // Calculate total aspect ratio
        for item in row.items {
            if case .photoStack(let photoStack) = item.itemType {
                totalAspectRatio += photoStack.primaryAspectRatio
            } else {
                totalAspectRatio += 1.0 // Default aspect ratio for non-photo items
            }
        }
        
        // If no aspect ratios calculated yet, use equal widths
        guard totalAspectRatio > 0 else {
            let equalWidth = availableWidth / CGFloat(row.items.count)
            return Array(repeating: equalWidth, count: row.items.count)
        }
        
        // Calculate individual widths based on aspect ratios
        for item in row.items {
            let aspectRatio: CGFloat
            if case .photoStack(let photoStack) = item.itemType {
                aspectRatio = photoStack.primaryAspectRatio
            } else {
                aspectRatio = 1.0 // Default aspect ratio for non-photo items
            }
            let proportionalWidth = (aspectRatio / totalAspectRatio) * availableWidth
            widths.append(proportionalWidth)
        }
        
        return widths
    }
    
    private func calculateOptimalRowHeight(availableWidth: CGFloat, maxHeight: CGFloat) -> CGFloat {
        // Calculate total aspect ratio for photo stacks in this row
        var totalAspectRatio: CGFloat = 0
        for item in row.items {
            if case .photoStack(let photoStack) = item.itemType {
                totalAspectRatio += photoStack.primaryAspectRatio
            } else {
                // For non-photo items, use square aspect ratio
                totalAspectRatio += 1.0
            }
        }
        
        // If no valid aspect ratios, use default
        guard totalAspectRatio > 0 else {
            return min(120, maxHeight)
        }
        
        // Calculate height that would make all photos fit the available width
        let calculatedHeight = availableWidth / totalAspectRatio
        
        // Apply min/max constraints
        let minHeight: CGFloat = 80  // Minimum readable height
        let constrainedHeight = min(max(calculatedHeight, minHeight), maxHeight)
        
        return constrainedHeight
    }
}


// MARK: - RRListItemDataView
struct RRListItemDataView: View {
    let item: any RListViewItem
    let isSelectionMode: Bool
    let selectedAssets: Set<String>
    let onPhotoTap: (PHAsset) -> Void
    let onPinTap: (PinData) -> Void
    let onPhotoStackTap: ([PHAsset]) -> Void
    let onLocationTap: ((LocationInfo) -> Void)?
    let onDeleteItem: ((any RListViewItem) -> Void)?
    let onUserTap: ((String, String) -> Void)?
    
    init(
        item: any RListViewItem,
        isSelectionMode: Bool = false,
        selectedAssets: Set<String> = [],
        onPhotoTap: @escaping (PHAsset) -> Void,
        onPinTap: @escaping (PinData) -> Void,
        onPhotoStackTap: @escaping ([PHAsset]) -> Void,
        onLocationTap: ((LocationInfo) -> Void)? = nil,
        onDeleteItem: ((any RListViewItem) -> Void)? = nil,
        onUserTap: ((String, String) -> Void)? = nil
    ) {
        self.item = item
        self.isSelectionMode = isSelectionMode
        self.selectedAssets = selectedAssets
        self.onPhotoTap = onPhotoTap
        self.onPinTap = onPinTap
        self.onPhotoStackTap = onPhotoStackTap
        self.onLocationTap = onLocationTap
        self.onDeleteItem = onDeleteItem
        self.onUserTap = onUserTap
    }
    
    var body: some View {
        switch item.itemType {
        case .photoStack(let photoStack):
            RListPhotoView(
                photoStack: photoStack,
                isSelectionMode: isSelectionMode,
                selectedAssets: selectedAssets,
                onTap: {
                    if photoStack.isSinglePhoto {
                        onPhotoTap(photoStack.primaryAsset)
                    } else {
                        onPhotoStackTap(photoStack.assets)
                    }
                }
            )
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
