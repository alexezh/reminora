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
- 3-tab TabView: Pin (Map), Photos, Profile
- Pin tab with PinMainView for map interface
- Photos tab with PhotoStackView for library management
- Profile tab for user management
- Photo library overlay triggered by toolbar buttons

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
- List filtering combo box for user lists (All Places, Quick, etc.)
- Add button in panel header for quick photo addition
- Dynamic place filtering based on selected list

### **PinListView.swift**
**Purpose**: List component for displaying places with thumbnails
- Displays place metadata (date, caption, distance)
- 56x56 rounded image thumbnails
- Distance calculation from current map center
- Selection highlighting for currently selected place
- Swipe-to-delete functionality

## Photo Stack & Library Management

### **PhotoStackView.swift**
**Purpose**: Main photo library interface with time-based stacking and preference management
- Grid layout (4 columns) with exact square sizing (width/4)
- Time-based photo grouping (10-minute intervals)
- Integrated photo preference system (favorites via iOS Photos, dislikes via Core Data)
- Filter tabs: Photos (default), All Photos, Favorites, Disliked, Neutral
- Visual preference indicators: white heart for favorites, red X for dislikes
- Stack indicators for grouped photos (multi-photo stacks)
- Permission management for photo library access (readWrite for favorites)
- Navigation to SwipePhotoView for all photos (unified interface)
- PhotoStackCell with preference overlays and stack count indicators
- Core Data initialization with loading states and retry mechanisms
- PhotoPreferenceManager for hybrid preference storage

### **SwipePhotoView.swift**
**Purpose**: Full-screen photo browsing with gesture navigation and preference management
- TabView-based smooth swiping between photos (unified for single photos and stacks)
- Modern X close button with circular background
- Heart/X action buttons for favorites and dislikes with real-time UI updates
- Integrated with iOS Photos favorites and Core Data dislikes
- Share button with Reminora link generation
- Pin button for adding photos to places
- Swipe down to close gesture (with directional detection)
- Navigation dots for multi-photo stacks
- AddPinFromPhotoView integration
- Zoom functionality: pinch-to-zoom (1x-4x), pan when zoomed, double-tap zoom
- Preference manager initialization with timeout and error handling
- Auto-dismiss on dislike with haptic feedback

### **AddPinFromPhotoView.swift**
**Purpose**: Interface for converting photos to places/pins
- Photo preview with caption input
- Location display from EXIF data
- Save/Cancel functionality
- Core Data Place creation
- Metadata preservation (creation date, location)

## Traditional Photo Management & Capture

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
- Coordinate display for search center
- Zoomable full-screen photo viewer (PhotoZoomView)
- Photo sharing and deep link generation
- Integration with Photos app
- PhotoZoomView with pinch/pan gestures and swipe-down dismissal
- SavePhotoToPlaces functionality for quick pin creation

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
- Action buttons: Map (shows nearby places), Photos, Quick List, Share
- Facebook-style caption below photo
- Inline comments system with SimpleCommentsView
- Map with nearby places at bottom
- Deep link sharing functionality
- Close button instead of back navigation
- NearbyPlacesList sheet presentation for map button

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

### **PhotoPreference.swift**
**Purpose**: Hybrid photo preference management system
- PhotoPreferenceManager class for unified preference handling
- Integration with iOS Photos favorites (PHAsset.isFavorite)
- Core Data storage for dislikes (PhotoPreference entity)
- Photo filtering by preference type (all, favorites, dislikes, neutral, notDisliked)
- Preference types: like (iOS Photos), dislike (Core Data), neutral
- Filter types with display names and SF Symbols icons
- Batch filtering operations for PhotoStackView

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

1. **Photo Stack Flow**: Photos Tab → PhotoStackView → Filter by preference → Tap photo/stack → SwipePhotoView → Like/Dislike/Pin/Share
2. **Photo Preference Flow**: SwipePhotoView → Heart (saves to iOS Photos favorites) → X (saves to Core Data dislikes) → Auto-dismiss on dislike
3. **Photo to Pin Flow**: SwipePhotoView → Pin button → AddPinFromPhotoView → Save place
4. **Map Exploration**: Pin Tab → PinMainView → PinBrowserView → Place selection → PinDetailView
5. **Social Interaction**: PinDetailView → Comments → User profiles
6. **List Management**: PinBrowserView → List combo box → Filter places by list
7. **Discovery**: NearbyPhotosGridView → Distance filtering → PhotoZoomView → Photo exploration
8. **Sharing Flow**: SwipePhotoView → Share → Create Place → Generate Reminora link → iOS share sheet
9. **Photo Management**: PhotoStackView → Filter tabs → Visual preference indicators → Unified photo viewing

The app demonstrates sophisticated SwiftUI architecture with strong separation of concerns, comprehensive data management, and modern iOS development patterns. The codebase shows careful attention to user experience with features like gesture handling, keyboard management, and smooth animations.