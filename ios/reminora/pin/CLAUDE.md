# pin/ Directory

## Purpose
Map-based features, location pins, place management, and map interactions.

## Contents

### Main Views
- **PinMainView.swift** - Card-based pins feed with fixed header, image/map toggle, and user navigation
- **PinDetailView.swift** - Full-screen detailed view of a specific place with traditional navigation
- **PinListView.swift** - Scrollable list of places in sliding panel
- **PinBrowserView.swift** - Browse and search places interface

### Location Features
- **NearbyPhotosGridView.swift** - Grid of photos near a location
- **NearbyPhotosWrapperView.swift** - Wrapper for nearby photos functionality
- **NearbyLocationsPageView.swift** - Explore nearby locations and places
- **FilteredMapItems.swift** - Filter and sort map items by criteria

### Comments & Social
- **CommentsView.swift** - Full comments interface for places
- **SimpleCommentsView.swift** - Simplified comments display
- **UserCommentsView.swift** - User-specific comment management

### Collections
- **PinCollectionListView.swift** - Manage collections of pins/places

### Extensions
- **Place+Embedding.swift** - Core Data extensions for place embeddings

## Key Features
- Card-based pins feed with 1/4 screen height cards
- Fixed header with "Pins" title and add button menu
- Image/map toggle positioned relative to card boundaries
- Proper image scaling to fit card dimensions
- Traditional navigation to PinDetailsView with toolbar buttons
- Tappable user names for UserProfileView navigation
- Interactive MapKit integration
- Geotagged photo management
- Location-based photo discovery
- Place comments and social features
- Distance-based sorting
- Pin collections and organization
- Address information display
- Map annotations and clustering

## Design Pattern
- **Layout**: Fixed header + scrollable card list
- **Cards**: 1/4 screen height, rounded corners, left content + right image/map
- **Navigation**: Traditional push navigation instead of modal sheets
- **User Interaction**: Tap titles for details, tap usernames for profiles
- **Image Handling**: Scaled to fit card area with proper aspect ratio
- **Button Positioning**: Toggle buttons positioned relative to card area, not image content