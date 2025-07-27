# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Reminora (Wahi) is a geotagged photo sharing app built with SwiftUI (iOS) and Kotlin (Android). The app allows users to view their photo library, save photos with location data, view them on an interactive map, and share pins with other users. It includes cloud synchronization, user authentication, and social features like following users and commenting on pins.

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

1. **Main App (`ios/reminora/`)**
   - `reminoraApp.swift` - SwiftUI App entry point, sets up Core Data environment
   - `ContentView.swift` - Main view controller with map/photo library toggle
   - `PinMainView.swift` - Interactive map showing geotagged photos with sliding panel
   - `PhotoLibraryView.swift` - Photo library browser with thumbnail grid
   - `SwipePhotoView.swift` - Full-screen photo viewer with swipe navigation
   - `AddPinFromPhotoView.swift` - Create pins from photos with reverse geocoding

2. **Cloud Services (`ios/reminora/cloud/`)**
   - `AuthenticationService.swift` - User authentication and session management
   - `CloudSyncService.swift` - Synchronization between local and cloud data
   - `APIService.swift` - HTTP API client and networking
   - `UserProfileView.swift` - User profile management and following

3. **Pin Management (`ios/reminora/pin/`)**
   - `PinDetailView.swift` - Detailed pin view with address management
   - `SelectLocationsView.swift` - Multi-select location picker for addresses
   - `NearbyLocationsPageView.swift` - Explore nearby places and locations
   - `CommentsView.swift` - Pin comments and social interactions

4. **Backend (`backend/`)**
   - Cloudflare Workers with D1 SQLite database
   - Session-based authentication with Bearer tokens
   - RESTful API for pins, users, follows, and comments

5. **Android App (`android/`)**
   - Kotlin-based Android implementation
   - Matching functionality with iOS version

### Data Model

The app uses Core Data (iOS) with main entities:

**Place Entity:**
- `imageData: Binary` - Downsampled JPEG image data
- `location: Binary` - Archived CLLocation with GPS coordinates
- `locations: String` - JSON array of PlaceAddress objects for multiple addresses
- `dateAdded: Date` - When the photo was added
- `post: String` - Caption/text content
- `url: String` - Optional original file URL
- `cloudId: String` - Unique ID for cloud synchronization
- `isPrivate: Bool` - Privacy setting for pin sharing
- `originalUserId: String` - ID of the original pin creator (for shared pins)
- `originalUsername: String` - Username of the original creator
- `originalDisplayName: String` - Display name of the original creator

**Additional Entities:**
- `Comment` - User comments on pins
- `UserList` - Following relationships and user lists
- `ListItem` - Items within user lists

### Key Features

- **Cloud Synchronization**: Real-time sync between local storage and Cloudflare Workers backend
- **User Authentication**: Session-based auth with Google/Facebook OAuth integration
- **Reverse Geocoding**: Automatically extracts place names, cities, and countries from GPS coordinates
- **Address Management**: Multi-address support for pins with location picker
- **Social Features**: User following, pin sharing, comments, and user profiles
- **Map Interaction**: Interactive map with pin clustering and detailed pin views
- **Photo Management**: Smart photo library integration with EXIF data extraction
- **Offline Support**: Local-first architecture with cloud sync when available
- **Cross-Platform**: iOS (SwiftUI) and Android (Kotlin) implementations

### Navigation Flow

1. **Home View**: Interactive map with pin clustering and dynamic toolbar
2. **Photo Library**: Smart photo browser with swipe navigation and filtering
3. **Add Pin**: Photo selection with reverse geocoding and privacy controls
4. **Pin Details**: Full-screen pin view with address management and comments
5. **User Profiles**: User discovery, following, and shared pin viewing
6. **Location Discovery**: Interactive MapView with location search, sharing, and pin creation from discovered places

### Technical Details

**iOS:**
- **Target**: iOS 18.2+, Swift 5.0, SwiftUI
- **Frameworks**: Core Data, MapKit, Photos, PhotosUI, Core Location, CoreLocationUI
- **Bundle ID**: `com.alexezh.reminora`
- **App Group**: `group.com.alexezh.reminora` for shared data access
- **Permissions**: Location (when in use), Photo Library access

**Backend:**
- **Platform**: Cloudflare Workers with TypeScript
- **Database**: D1 SQLite for structured data
- **Authentication**: Session-based with Bearer tokens
- **API**: RESTful endpoints for pins, users, follows, comments

**Android:**
- **Target**: Android API level TBD, Kotlin
- **Architecture**: MVVM with Room database
- **Matching iOS functionality and UI patterns

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