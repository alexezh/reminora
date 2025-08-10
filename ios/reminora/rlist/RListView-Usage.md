# RListView Usage Guide

## Overview

`RListView` is a flexible, unified scrollable view component that can display both photos and pins in a single interface with automatic date separators. It supports various data sources and provides a consistent user experience across different content types.

## Key Features

- **Mixed Content**: Display photos, photo stacks, and pins in a single scrollable view
- **Automatic Date Grouping**: Items are automatically grouped by date with smart date separators
- **Photo Stacking**: Photos taken within 10 minutes are automatically grouped into stacks of up to 3 images
- **Flexible Data Sources**: Supports photo library, user lists, nearby photos, pins, or mixed content
- **Responsive Layout**: Pins take full width, photo stacks show 3 images side by side
- **Date Separators**: Smart date formatting (Today, Yesterday, day of week, or date)

## Data Sources

### 1. Photo Library
```swift
let photoStackCollection: RPhotoStackCollection = // your photo stack collection
let dataSource = RListDataSource.photoLibrary(photoStackCollection)
```

### 2. User List (Pins only)
```swift
let userList: UserList = // your user list
let places: [Place] = // places in the list
let dataSource = RListDataSource.userList(userList, places)
```

### 3. Nearby Photos
```swift
let nearbyAssets: [PHAsset] = // nearby photo assets
let dataSource = RListDataSource.nearbyPhotos(nearbyAssets)
```

### 4. Pins Only
```swift
let pins: [Place] = // your pin places
let dataSource = RListDataSource.pins(pins)
```

### 5. Mixed Content
```swift
let items: [RListViewItem] = [
    RListPhotoItem(asset: someAsset),
    RListPinItem(place: somePlace),
    RListPhotoStackItem(assets: [asset1, asset2, asset3])
]
let dataSource = RListDataSource.mixed(items)
```

## Basic Usage

```swift
struct MyView: View {
    var body: some View {
        RListView(
            dataSource: .photoLibrary(myPhotoStackCollection),
            onPhotoStackTap: { photoStack in
                // Handle photo stack tap (both single photos and multi-photo stacks)
                showPhotoStack(photoStack)
            },
            onPinTap: { place in
                // Handle pin tap
                showPinDetail(place)
            }
        )
    }
}
```

## Helper Methods

RListView provides convenient helper methods for common use cases:

### Photo Library View
```swift
RListView.photoLibraryView(
    assets: photoAssets,
    onPhotoTap: { asset in /* handle */ },
    onPhotoStackTap: { assets in /* handle */ }
)
```

### User List View
```swift
RListView.userListView(
    list: userList,
    places: places,
    onPinTap: { place in /* handle */ }
)
```

### Nearby Photos View
```swift
RListView.nearbyPhotosView(
    assets: nearbyAssets,
    onPhotoTap: { asset in /* handle */ },
    onPhotoStackTap: { assets in /* handle */ }
)
```

### Mixed Content View
```swift
RListView.mixedContentView(
    items: mixedItems,
    onPhotoTap: { asset in /* handle */ },
    onPinTap: { place in /* handle */ },
    onPhotoStackTap: { assets in /* handle */ }
)
```

## Creating Custom Items

### Photo Item
```swift
let photoItem = RListPhotoItem(asset: phAsset)
```

### Photo Stack Item
```swift
let stackItem = RListPhotoStackItem(assets: [asset1, asset2, asset3])
```

### Pin Item
```swift
let pinItem = RListPinItem(place: coreDataPlace)
```

## Integration Examples

### 1. Replace PhotoStackView
```swift
// Before: PhotoStackView
PhotoStackView()

// After: RListView with photo library
RListView.photoLibraryView(
    assets: photoAssets,
    onPhotoTap: { asset in
        selectedAsset = asset
        showingFullPhoto = true
    },
    onPhotoStackTap: { assets in
        selectedAssets = assets
        showingPhotoStack = true
    }
)
```

### 2. Replace PinListView
```swift
// Before: PinListView
PinListView(list: userList)

// After: RListView with user list
RListView.userListView(
    list: userList,
    places: places,
    onPinTap: { place in
        selectedPlace = place
        showingPinDetail = true
    }
)
```

### 3. Create Mixed Content View
```swift
// Combine photos and pins from different sources
let photoItems = photoAssets.map { RListPhotoItem(asset: $0) }
let pinItems = places.map { RListPinItem(place: $0) }
let mixedItems = photoItems + pinItems

RListView.mixedContentView(
    items: mixedItems,
    onPhotoTap: { asset in /* handle photo */ },
    onPinTap: { place in /* handle pin */ },
    onPhotoStackTap: { assets in /* handle stack */ }
)
```

## Date Separator Logic

RListView automatically creates intelligent date separators:

- **Today**: Items from today
- **Yesterday**: Items from yesterday  
- **This Week**: Day of week (e.g., "Monday", "Tuesday")
- **This Year**: Month and day (e.g., "Apr 1", "Dec 25")
- **Previous Years**: Full date (e.g., "Apr 1, 2023")

## Photo Stacking Algorithm

Photos are automatically grouped into stacks based on:
- **Time Proximity**: Photos taken within 10 minutes of each other
- **Stack Size**: Maximum 3 photos per stack
- **Creation Date**: Uses photo's EXIF creation date

## Performance Considerations

- **Lazy Loading**: Images are loaded asynchronously as needed
- **Memory Efficient**: Uses appropriate image sizes for thumbnails
- **Progressive Display**: Shows placeholder while images load
- **Efficient Grouping**: Date grouping is performed in background

## Customization

The view can be customized by:
- Adjusting the `stackingInterval` for different photo grouping
- Modifying date formatting in `RListDateSection.formatDate()`
- Customizing individual item views (`RListPhotoView`, `RListPinView`, etc.)
- Adding additional item types by extending `RListItemType`

## Error Handling

- **Missing Images**: Shows placeholder with loading indicator
- **Empty States**: Displays appropriate empty state message
- **Invalid Data**: Gracefully handles missing or corrupt data
- **Network Issues**: Handles photo loading failures

## Testing

Use `RListExampleView` for testing different configurations:

```swift
// Test with different data sources
RListExampleView.photoLibraryExample(with: testAssets)
RListExampleView.userListExample(with: testList, places: testPlaces)
RListExampleView.mixedContentExample(with: testItems)
```