# Reminora iOS App - View Structure Overview

## App Entry Point & Core Navigation

### **reminoraApp.swift**
**Purpose**: Main app entry point and authentication coordinator
- Handles authentication state management with Google Sign-In integration
- Deep link handling for Reminora URLs (`reminora.app/place/...`)
- Automatic place creation from shared links
- Auth state routing: loading → login → authenticated
- Sets up Core Data environment and manages PersistenceController

### **ContentView.swift**
**Purpose**: Main tab-based navigation container
- 5-tab TabView: Home (Map), Add Photo, Lists, Places, Profile
- Photo library integration triggered by "Add" tab
- Returns to Home tab after photo selection
- Tab bar with system icons and labels

## Core Map & Photo Management

### **PinMainView.swift**
**Purpose**: Main map interface with search functionality
- Interactive map with place annotations
- Real-time location tracking via LocationManager
- Geo-search with MKLocalSearch integration
- Text search in place names/posts
- Delegates to PinBrowserView for actual display
- FetchRequest for all places, filtered by search terms

### **PinBrowserView.swift**
**Purpose**: Combined map and sliding panel interface
- Interactive map with place pins
- 3-height sliding panel (min/third/max)
- Double-tap detection for place detail navigation
- Gesture-based panel height control
- Real-time place selection with map centering
- Single tap = map navigation, double tap = detail view

### **PinListView.swift**
**Purpose**: List component for displaying places with thumbnails
- Displays place metadata (date, caption, distance)
- 56x56 rounded image thumbnails
- Distance calculation from current map center
- Selection highlighting for currently selected place
- Swipe-to-delete functionality

## Photo Management & Capture

### **PhotoLibraryView.swift**
**Purpose**: System photo library browser
- Grid layout (3 columns) with lazy loading
- PHAsset integration for photo access
- Thumbnail generation with 300x300 target size
- Navigation to FullPhotoView for detailed editing
- LazyVGrid with PhotoThumbnailView components

### **FullPhotoView.swift**
**Purpose**: Full-screen photo viewer and caption editor
- Full-screen photo display (max 300px height)
- Multi-line caption input with 5-10 line limit
- GPS location extraction from EXIF data
- Mini-map display if location available
- Core Data integration for saving
- PHAsset → UIImage → Core Data with location flow

### **NearbyPhotosGridView.swift**
**Purpose**: Advanced photo library with location filtering
- Distance-based filtering (200m to 10km ranges)
- Grid layout with distance overlays
- Zoomable full-screen photo viewer
- Photo sharing and deep link generation
- Integration with Photos app
- PhotoZoomView with pinch/pan gestures

### **NearbyPhotosWrapperView.swift**
**Purpose**: Simple wrapper for places tab
- Single button to launch NearbyPhotosGridView
- Placeholder interface for future expansion

### **NearbyPhotosListView.swift**
**Purpose**: Alternative list view for nearby photos
- Distance-sorted place listing
- Thumbnail + metadata display
- Location-based sorting and distance display

## Place Detail & Social Features

### **PinDetailView.swift**
**Purpose**: Detailed view for individual places (Facebook-style)
- Full-width photo display
- Action buttons: Map, Photos, Quick List, Share
- Facebook-style caption below photo
- Inline comments system with SimpleCommentsView
- Map with nearby places
- Deep link sharing functionality

### **SimpleCommentsView.swift**
**Purpose**: Streamlined commenting system
- Supports both photo and user comments
- User avatar placeholders with initials
- "View all comments" expansion (shows 3 by default)
- Real-time comment submission
- Keyboard toolbar with Done button
- Core Data Comment entities integration

## List Management

### **SavedListView.swift**
**Purpose**: User-created lists management interface
- Special lists: "Shared" and "Quick" appear first
- List creation with handle conflict resolution
- Card-based UI with custom icons/colors
- Item count display
- UserList and ListItem Core Data entities

### **ListDetailView.swift**
**Purpose**: Individual list contents viewer
- Uses PinBrowserView for consistent place display
- Custom header with list icon and metadata
- Empty state handling
- Core Data relationship resolution (ListItem → Place)

## Authentication & User Management

### **LoginView.swift**
**Purpose**: Authentication interface with social login
- Apple Sign In integration
- Google Sign In button
- GitHub placeholder (not implemented)
- Gradient background design
- Handle setup flow for new users via HandleSetupView

### **ProfileView.swift**
**Purpose**: User profile and settings management
- User avatar and profile information
- Stats display (photos, followers, following, comments)
- Cloud sync status and manual sync
- Settings navigation (followers, notifications, privacy)
- Sign out functionality
- CloudSyncService and AuthenticationService integration

### **UserCommentsView.swift**
**Purpose**: User-specific comment management
- Tabbed interface: Received vs Sent comments
- Comment cards with user info and timestamps
- Context information (photo vs profile comments)
- Time-ago formatting
- Empty state handling

## Supporting Components

### **LocationManager.swift**
**Purpose**: Core Location wrapper for user location
- CLLocationManager delegate implementation
- 5-meter distance filtering
- Accuracy validation (≤50 meters)
- Published location updates for reactive UI

## Architecture Patterns

### **Data Flow**
- Core Data with @FetchRequest for reactive updates
- @StateObject for service classes (LocationManager, AuthenticationService)
- @State for local UI state management
- Environment injection for managed object context

### **Navigation Patterns**
- TabView for primary navigation
- Sheet presentations for modals
- NavigationView within sheets
- Custom back button handling in detail views

### **SwiftUI Patterns**
- Extensive use of ViewModifiers and custom components
- @FocusState for keyboard management
- Gesture handling for map interactions
- Lazy loading for performance (LazyVGrid, LazyVStack)

### **Location & Photos Integration**
- PHPhotoLibrary for photo access
- Core Location for GPS data
- MapKit for mapping functionality
- EXIF data extraction for photo metadata

## Key User Flows

1. **Photo Capture Flow**: Add Tab → PhotoLibraryView → FullPhotoView → Save with location
2. **Map Exploration**: PinMainView → PinBrowserView → Place selection → PinDetailView
3. **Social Interaction**: PinDetailView → Comments → User profiles
4. **List Management**: ListView → Create/manage lists → ListDetailView → Place browser
5. **Discovery**: NearbyPhotosGridView → Distance filtering → Photo exploration

The app demonstrates sophisticated SwiftUI architecture with strong separation of concerns, comprehensive data management, and modern iOS development patterns. The codebase shows careful attention to user experience with features like gesture handling, keyboard management, and smooth animations.