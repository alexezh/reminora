# Reminora Android App Overview

## Application Overview

Reminora is a sophisticated geotagged photo sharing Android application built with Kotlin and Jetpack Compose. The app enables users to organize their photo library, save photos with location data, view them on an interactive map, and manage collections through a flexible list system.

## Core Features

### 1. Photo Library Management
- **Photo Grid Screen**: Browse photos organized in time-based stacks
- **Swipe Photo View**: Navigate through photos with gesture-based swiping
- **Photo Preferences**: Like, dislike, and rate photos with haptic feedback
- **Photo Filtering**: View photos by preferences (favorites, dislikes, all)

### 2. Map Integration
- **Interactive Map**: View geotagged photos on a map interface using Google Maps
- **Location Pins**: Tap pins to view photo details and location information
- **GPS Extraction**: Automatically extract location from image EXIF data
- **Nearby Photos**: Discover photos taken near specific locations

### 3. Quick List System
- **Quick Collection**: Temporarily collect photos and pins for organization
- **One-Touch Adding**: Add photos/pins to Quick List with floating action button
- **Batch Operations**: Perform actions on multiple items simultaneously
- **Smart Organization**: Mixed content support (photos and pins together)

### 4. List Management
- **User Lists**: Create custom lists to organize photos and pins
- **List Actions**: Create, rename, and manage multiple lists
- **Mixed Content**: Lists can contain both photos and location pins
- **Cross-List Operations**: Move items between lists efficiently

### 5. Share Integration
- **Intent Handling**: Receive photos from other apps via Android intents
- **Location Processing**: Extract and save location data from shared photos
- **Content Provider**: Shared data access between app components

## Technical Architecture

### Core Technologies
- **Jetpack Compose**: Modern declarative UI framework
- **Room Database**: Local data persistence with SQLite
- **CameraX**: Camera and photo capture functionality
- **Google Maps**: Interactive map and location services
- **Location Services**: GPS and location data processing
- **Hilt**: Dependency injection framework

### Data Model
- **Place**: Core entity for photos with location data
- **UserList**: User-created lists for organization
- **ListItem**: Junction entity linking places to lists
- **PhotoPreference**: User ratings and preferences
- **PhotoLocationCache**: Cached location data for photos

### Key Components

#### PhotoStackScreen
- Main photo browsing interface
- Time-based photo stacking (10-minute intervals)
- Preference filtering and Quick List integration
- LazyVerticalGrid layout with thumbnail previews

#### SwipePhotoView
- Full-screen photo viewer with navigation
- Preference controls (like/dislike/neutral)
- Quick List toggle floating action button
- Share and pin creation functionality

#### Quick List System
- **QuickListService**: Core service for Quick List operations
- **QuickListScreen**: Display interface for Quick List items
- **Menu Integration**: Actions accessible through options menu
- **LiveData/StateFlow**: Real-time updates across screens

#### Lists System
- **ListsScreen**: Unified view for mixed content (photos and pins)
- **ListDetailScreen**: Individual list display with menu actions
- **AllListsScreen**: Overview of all user lists
- **AddToListDialog**: List selection interface

### Quick List Workflow

1. **Adding Items**:
   - Tap floating action button on photos in PhotoStackScreen
   - Tap floating action button in SwipePhotoView
   - Add pins from PlaceDetailScreen "Quick" button

2. **Managing Quick List**:
   - Access through Lists tab → Quick List
   - Menu actions via overflow menu in ListDetailScreen
   - Three main actions: Create List, Add to List, Clear Quick

3. **Create List Action**:
   - Shows dialog for new list name
   - Moves all Quick List items to new list
   - Clears Quick List and returns to main lists screen

4. **Add to List Action**:
   - Shows dialog with existing lists
   - Moves all Quick List items to selected list
   - Clears Quick List and returns to main lists screen

5. **Clear Quick Action**:
   - Shows confirmation dialog
   - Removes all items from Quick List
   - Returns to main lists screen

## User Interface Design

### Navigation Structure
- **Bottom Navigation**: Four main tabs (Photos, Map, Lists, Profile)
- **Contextual Actions**: Actions available based on current context
- **Gesture Support**: Swipe navigation and pull-to-refresh

### Visual Design
- **Material Design 3**: Follows Google's Material Design guidelines
- **Haptic Feedback**: Tactile responses for user interactions
- **Accessibility**: TalkBack and accessibility support
- **Dynamic Theming**: Material You dynamic color support

### Photo Display
- **Thumbnail Grid**: Efficient photo browsing with LazyVerticalGrid
- **Full-Screen View**: Immersive photo viewing experience
- **Overlay Controls**: Non-intrusive floating action buttons
- **Stack Indicators**: Visual badges for photo groupings

## Data Flow

### Photo Processing Pipeline
1. **Photo Selection**: User selects photos from gallery
2. **Metadata Extraction**: GPS and EXIF data processing
3. **Image Optimization**: Bitmap processing for storage efficiency
4. **Room Database Storage**: Persistent local storage
5. **UI Updates**: StateFlow/LiveData updates UI

### Quick List Operations
1. **Item Addition**: Photos/pins added to Quick List
2. **Batch Processing**: Multiple items handled simultaneously
3. **List Creation**: Quick List items moved to permanent lists
4. **State Updates**: UI refreshes across all screens
5. **Data Persistence**: Changes saved to Room database

## Performance Optimization

### Memory Management
- **Coil**: Efficient image loading and caching
- **Lazy Loading**: Photos loaded on-demand with LazyColumn/LazyGrid
- **Bitmap Recycling**: Automatic memory management
- **Background Processing**: Coroutines for non-blocking operations

### Database Optimization
- **Room**: Type-safe database operations
- **Coroutines**: Async database operations
- **Indexes**: Optimized queries for large datasets
- **Migration Support**: Seamless database schema updates

## Integration Points

### System Integration
- **MediaStore**: Read access to device photo gallery
- **Location Services**: GPS and location data access
- **Share Intents**: System-wide sharing support
- **Background Tasks**: WorkManager for background operations

### External Services
- **Google Sign-In**: User authentication
- **Google Maps**: Map functionality
- **Cloud Sync**: Future cloud synchronization support
- **Firebase**: Push notifications and analytics (future)

## Security & Privacy

### Data Protection
- **Local Storage**: All data stored locally on device
- **Encryption**: Room database encryption for sensitive data
- **Privacy Controls**: User-controlled permissions
- **Secure Storage**: Android Keystore for sensitive data

### User Consent
- **Photo Access**: Explicit permission required (READ_EXTERNAL_STORAGE)
- **Location Access**: Fine/coarse location permissions
- **Data Sharing**: No data shared without user consent

## Future Enhancements

### Planned Features
- **Cloud Synchronization**: Cross-device data sync
- **Social Sharing**: Enhanced sharing capabilities
- **AI-Powered Organization**: Smart photo grouping with ML Kit
- **Collaborative Lists**: Shared lists between users
- **Advanced Search**: Content-based photo search

### Technical Improvements
- **Performance Optimization**: Further memory and speed improvements
- **Accessibility**: Enhanced TalkBack and accessibility features
- **Widget Support**: Home screen widgets for quick access
- **Shortcuts Integration**: App shortcuts and deep links

## Development Guidelines

### Code Organization
- **MVVM Pattern**: Model-View-ViewModel architecture
- **Repository Pattern**: Data layer abstraction
- **Modular Design**: Feature-based module structure
- **Dependency Injection**: Hilt for dependency management

### Testing Strategy
- **Unit Tests**: ViewModel and repository testing
- **Integration Tests**: Database and API testing
- **UI Tests**: Compose UI testing
- **Performance Tests**: Memory and CPU profiling

### Key Android Components

#### ViewModels
- **PhotoStackViewModel**: Manages photo browsing state
- **MapViewModel**: Handles map interactions and location data
- **ListsViewModel**: Manages user lists and Quick List operations
- **AuthViewModel**: Handles user authentication state

#### Repositories
- **PhotoRepository**: Photo data operations
- **AuthRepository**: Authentication and user management
- **Database Operations**: Room database interactions

#### UI Components
- **Composables**: Reusable UI components
- **Navigation**: Compose Navigation for screen transitions
- **State Management**: StateFlow and Compose state handling

## Build Configuration

### Gradle Setup
- **Kotlin DSL**: Modern Gradle configuration
- **Version Catalogs**: Centralized dependency management
- **Build Variants**: Debug and release configurations
- **ProGuard**: Code obfuscation and optimization

### Dependencies
- **Compose BOM**: Jetpack Compose Bill of Materials
- **AndroidX**: Modern Android libraries
- **Google Play Services**: Maps and location services
- **Room**: Database persistence
- **Hilt**: Dependency injection
- **Coil**: Image loading
- **Retrofit**: Network operations (future)

This overview provides a comprehensive understanding of the Reminora Android application's architecture and implementation, adapted from the iOS version to reflect Android-specific technologies and patterns while maintaining feature parity with the iOS Quick List functionality.