# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Reminora is a geotagged photo sharing iOS app built with SwiftUI. The app allows users to view their photo library, save photos with location data, and view them on a map interface. It includes a share extension for adding photos from other apps.

## Development Commands

### Build and Run
```bash
# Build main app
xcodebuild -project reminora.xcodeproj -scheme reminora -configuration Debug build

# Run tests
xcodebuild -project reminora.xcodeproj -scheme reminora -configuration Debug test -destination 'platform=iOS Simulator,name=iPhone 15'

# Build share extension
xcodebuild -project reminora.xcodeproj -scheme ReminoraShareExt -configuration Debug build
```

### Open in Xcode
```bash
open reminora.xcodeproj
```

## Architecture

### Core Components

1. **Main App (`reminora/`)**
   - `reminoraApp.swift` - SwiftUI App entry point, sets up Core Data environment
   - `ContentView.swift` - Main view controller with map/photo library toggle
   - `MapView.swift` - Interactive map showing geotagged photos with sliding panel
   - `PhotoLibraryView.swift` - Photo library browser with thumbnail grid
   - `FullPhotoView.swift` - Full-screen photo viewer
   - `LocationManager.swift` - Core Location wrapper for user location
   - `PlaceListView.swift` - Scrollable list of places in the sliding panel

2. **Share Extension (`ReminoraShareExt/`)**
   - `ShareViewController.swift` - Handles incoming images/URLs from other apps
   - Saves shared content to Core Data with location extraction

3. **Shared Data Layer (`shared/`)**
   - `Persistence.swift` - Core Data stack with App Group support
   - Handles image downsampling and GPS extraction from EXIF data

### Data Model

The app uses Core Data with a single `Place` entity:
- `imageData: Binary` - Downsampled JPEG image data
- `location: Binary` - Archived CLLocation with GPS coordinates
- `dateAdded: Date` - When the photo was added
- `post: String` - Optional text content from share extension
- `url: String` - Optional original file URL

### Key Features

- **App Group Integration**: Uses `group.com.alexezh.reminora` for shared Core Data between main app and share extension
- **GPS Extraction**: Automatically extracts location from image EXIF data
- **Image Downsampling**: Reduces image size to 1024px max dimension for storage
- **Map Interaction**: Tappable map pins that center the map and show photo details
- **Search**: Filter photos by text content in the sliding panel
- **Distance Sorting**: Photos sorted by distance from current map center

### Navigation Flow

1. **Home View**: Map with bottom toolbar (Home/Add buttons)
2. **Add Mode**: Full-screen photo library browser
3. **Photo Selection**: Full-screen photo viewer with save capability
4. **Map Interaction**: Tap pins to select photos, sliding panel shows details
5. **Share Extension**: External apps can share photos directly to Wahi

### Technical Details

- **Target**: iOS 18.2+, Swift 5.0
- **Frameworks**: SwiftUI, Core Data, MapKit, Photos, PhotosUI, Core Location
- **Bundle ID**: `com.alexezh.reminora` (main app), `com.alexezh.reminora.WahiShareExt` (extension)
- **App Group**: `group.com.alexezh.reminora` for shared Core Data access
- **Permissions**: Location (when in use), Photo Library access

### Common Patterns

- All views use `@Environment(\.managedObjectContext)` for Core Data access
- `@FetchRequest` with `Place` entity for reactive data updates
- `PersistenceController.shared` singleton for Core Data operations
- Async image loading with `PHImageManager` for photo thumbnails
- Location updates via `@StateObject private var locationManager = LocationManager()`

### Testing

- `reminoraTests/` - Unit tests for main app
- `reminoraUITests/` - UI tests for main app
- Run tests via Xcode Test navigator or command line with `xcodebuild test`