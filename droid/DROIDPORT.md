# DROIDPORT.md - iOS to Android Porting Requirements

## Overview
This document outlines all iOS features, services, and components that need to be implemented or updated in the Android version to achieve feature parity.

## 🏗️ Core Architecture Components

### Navigation & UI Framework
- [ ] **UniversalActionSheet System** (iOS: `shared/UniversalActionSheet.swift`)
  - **Android Target**: `ui/components/UniversalActionSheet.kt`
  - **Description**: Context-aware bottom sheet with tab-specific actions
  - **Dependencies**: ActionRouter, Context management

- [ ] **UniversalActionSheetModel** (iOS: `shared/UniversalActionSheetModel.swift`)
  - **Android Target**: `ui/state/ActionSheetState.kt`
  - **Description**: Action sheet context management (photos, quickList, pins, etc.)
  - **Dependencies**: Compose State, ViewModel integration

- [ ] **ActionRouter System** (iOS: `shared/ActionRouter.swift`)
  - **Android Target**: `ui/actions/ActionRouter.kt`
  - **Description**: Centralized action handling with dependency injection
  - **Dependencies**: Hilt, Repository layer

- [ ] **DynamicToolbar System** (iOS: `shared/DynamicToolbar.swift`)
  - **Android Target**: `ui/components/DynamicToolbar.kt`
  - **Description**: Context-aware toolbar with FAB and regular buttons
  - **Dependencies**: Compose, ActionRouter

- [ ] **LayoutConstants** (iOS: `shared/LayoutConstants.swift`)
  - **Android Target**: `ui/theme/LayoutConstants.kt`
  - **Description**: Shared UI constants for consistent spacing and sizing

### Navigation Management
- [ ] **ContentView Navigation Logic** (iOS: `shared/ContentView.swift`)
  - **Android Target**: `ui/main/MainScreen.kt` (enhance existing)
  - **Description**: Custom navigation system with context management
  - **Dependencies**: ActionSheet context, Toolbar management

- [ ] **SheetRouter System** (iOS: `shared/SheetRouter.swift`)
  - **Android Target**: `ui/navigation/SheetRouter.kt`
  - **Description**: Centralized sheet/modal presentation management

- [ ] **SheetStack Management** (iOS: `shared/SheetStack.swift`)
  - **Android Target**: `ui/navigation/SheetStack.kt`
  - **Description**: Stack-based sheet management with proper lifecycle

### State Management
- [ ] **SelectionService** (iOS: `shared/SelectionService.swift`)
  - **Android Target**: `ui/state/SelectionService.kt`
  - **Description**: Multi-selection state management across screens
  - **Dependencies**: ViewModel, Compose State

## 📸 Photo Features

### Photo Viewing & Navigation
- [ ] **SwipePhotoView with Two-Image Animation** (iOS: `photo/SwipePhotoView.swift`)
  - **Android Target**: `ui/photos/SwipePhotoView.kt` (enhance existing)
  - **Description**: Smooth left/right image transitions with preloaded images
  - **Dependencies**: Compose animations, Image loading

- [ ] **Enhanced ThumbnailView** (iOS: `photo/SwipePhotoView.swift` - ThumbnailView)
  - **Android Target**: `ui/photos/ThumbnailView.kt`
  - **Description**: 20% larger selected thumbnails with dynamic spacing
  - **Dependencies**: Compose animations, Layout calculations

- [ ] **PhotoStackView** (iOS: `photo/SwipePhotoView.swift` - stack functionality)
  - **Android Target**: `ui/photos/PhotoStackView.kt`
  - **Description**: Photo stack grouping and expansion/collapse
  - **Dependencies**: Photo grouping logic, Animations

### AI-Powered Photo Features
- [ ] **ImageEmbeddingService** (iOS: `photo/ImageEmbeddingService.swift`)
  - **Android Target**: `data/ai/ImageEmbeddingService.kt`
  - **Description**: AI-powered image embedding generation for similarity
  - **Dependencies**: TensorFlow Lite, ML model integration

- [ ] **PhotoEmbeddingService** (iOS: `photo/PhotoEmbeddingService.swift`)
  - **Android Target**: `data/ai/PhotoEmbeddingService.kt`
  - **Description**: Photo-specific embedding operations and caching
  - **Dependencies**: ImageEmbeddingService, Room database

- [ ] **PhotoSimilarityView** (iOS: `photo/PhotoSimilarityView.swift`)
  - **Android Target**: `ui/photos/PhotoSimilarityView.kt`
  - **Description**: Find and display similar photos interface
  - **Dependencies**: AI services, Photo grid display

- [ ] **SimilarPhotosGridView** (iOS: `photo/SimilarPhotosGridView.swift`)
  - **Android Target**: `ui/photos/SimilarPhotosGridView.kt`
  - **Description**: Grid display for similar photos with similarity scores

### Photo Management
- [ ] **PhotoPreference System** (iOS: `photo/PhotoPreference.swift`)
  - **Android Target**: `data/preferences/PhotoPreferenceManager.kt`
  - **Description**: User photo preferences (like/dislike) storage
  - **Dependencies**: Room database, User preferences

- [ ] **PhotoSharingService** (iOS: `photo/PhotoSharingService.swift`)
  - **Android Target**: `data/sharing/PhotoSharingService.kt`
  - **Description**: System share sheet integration for photos
  - **Dependencies**: Android sharing intents

## 🎨 ECard System

### ECard Core Components
- [ ] **ECardTemplateService** (iOS: `ecard/ECardTemplateService.swift`)
  - **Android Target**: `data/ecard/ECardTemplateService.kt`
  - **Description**: SVG template management and parsing
  - **Dependencies**: SVG rendering library, Asset management

- [ ] **ECardModels** (iOS: `ecard/ECardModels.swift`)
  - **Android Target**: `data/model/ECardModels.kt`
  - **Description**: Data models for templates, cards, and configuration
  - **Dependencies**: Serialization, Room entities

- [ ] **ECardEditorView** (iOS: `ecard/ECardEditorView.swift`)
  - **Android Target**: `ui/ecard/ECardEditorView.kt`
  - **Description**: Template-based card creation interface
  - **Dependencies**: SVG rendering, Photo selection, Text editing

### ECard Assets
- [ ] **SVG Templates** (iOS: `ecard/*.svg` files)
  - **Android Target**: `res/raw/` or `assets/ecard/`
  - **Description**: All SVG template files for different card styles
  - **Dependencies**: SVG asset handling, Template loading

## 📍 Pin & Location Features

### Pin Management
- [ ] **PinDetailView Enhancements** (iOS: `pin/PinDetailView.swift`)
  - **Android Target**: `ui/places/PlaceDetailView.kt` (enhance existing)
  - **Description**: Enhanced pin detail view with action integration
  - **Dependencies**: ActionRouter, Comments system

- [ ] **Multiple Address Support** (iOS: Place entity locations array)
  - **Android Target**: `data/local/Place.kt` (enhance existing)
  - **Description**: Support multiple addresses per place like iOS
  - **Dependencies**: Database migration, Address models

### Location Features
- [ ] **LocationInfo Extensions** (iOS: `pin/LocationInfo+Extensions.swift`)
  - **Android Target**: `data/model/LocationInfoExtensions.kt`
  - **Description**: Location utility extensions and helpers
  - **Dependencies**: Location models, Utility functions

- [ ] **NearbyLocationsView** (iOS: `pin/NearbyLocationsView.swift`)
  - **Android Target**: `ui/map/NearbyLocationsView.kt`
  - **Description**: Explore nearby places and locations interface

## 📋 List Management (RList System)

### Core RList Components
- [ ] **RListView with Context System** (iOS: `rlist/RListView.swift`)
  - **Android Target**: `ui/lists/RListView.kt` (enhance existing)
  - **Description**: Universal list view with mixed content support
  - **Dependencies**: Photo assets, Pin data, Date grouping

- [ ] **RListDetailView with ActionSheet Integration** (iOS: `rlist/RListDetailView.swift`)
  - **Android Target**: `ui/lists/RListDetailView.kt`
  - **Description**: List detail view with context-aware actions
  - **Dependencies**: ActionRouter, QuickList actions

- [ ] **QuickList ActionSheet Integration** (iOS: QuickList context in ActionSheet)
  - **Android Target**: `ui/quicklist/QuickListActions.kt`
  - **Description**: Empty Quick List, Create List, Add to List actions
  - **Dependencies**: ActionRouter, RList service

### RList Service Layer
- [ ] **Enhanced RListService** (iOS: `rlist/RListService.swift`)
  - **Android Target**: `data/repository/RListRepository.kt` (enhance existing)
  - **Description**: Complete list management with photo integration
  - **Dependencies**: Photo assets, Core Data operations

- [ ] **List Item Types Support** (iOS: RListViewItem protocol system)
  - **Android Target**: `data/model/RListItems.kt`
  - **Description**: Support for photos, photo stacks, pins, locations in lists
  - **Dependencies**: Polymorphic data handling

## ☁️ Cloud & Authentication

### Enhanced Cloud Features
- [ ] **Advanced CloudSyncService** (iOS: `cloud/CloudSyncService.swift`)
  - **Android Target**: `data/sync/CloudSyncService.kt` (enhance existing)
  - **Description**: Enhanced cloud sync with conflict resolution
  - **Dependencies**: API service, Local database

- [ ] **PinSharingService** (iOS: `cloud/PinSharingService.swift`)
  - **Android Target**: `data/sharing/PinSharingService.kt`
  - **Description**: Pin sharing and collaboration features
  - **Dependencies**: Cloud API, Sharing intents

- [ ] **UserProfileView Enhancements** (iOS: `cloud/UserProfileView.swift`)
  - **Android Target**: `ui/profile/UserProfileView.kt` (enhance existing)
  - **Description**: Enhanced user profile with following system
  - **Dependencies**: User API, Profile management

## 🎯 Action System Integration

### ActionRouter Actions
All iOS ActionType cases need Android equivalents:

- [ ] **Photo Actions**
  - `archive`, `delete`, `duplicate`
  - `addToQuickList`, `findSimilar`, `findDuplicates`
  - `makeECard`, `makeCollage`, `sharePhoto`, `toggleFavorite`

- [ ] **Pin Actions**
  - `addPin`, `addOpenInvite`, `toggleSort`
  - `addPinFromPhoto`, `addPinFromLocation`, `showPinDetail`

- [ ] **List Actions**
  - `refreshLists`, `showQuickList`, `showAllLists`
  - `emptyQuickList`, `createListFromQuickList`, `addQuickListToExistingList`

- [ ] **Navigation Actions**
  - `switchToTab`, `showActionSheet`

### Context Management
- [ ] **ActionSheetContext Enum** (iOS: ActionSheetContext)
  - **Android Target**: `ui/state/ActionSheetContext.kt`
  - **Description**: `.photos`, `.map`, `.pins`, `.lists`, `.quickList`, `.profile`, `.swipePhoto`, `.pinDetail`

## 🎨 UI/UX Enhancements

### Animation Systems
- [ ] **Two-Image Swipe Animation** (iOS: SwipePhotoView animation system)
  - **Android Target**: `ui/animations/PhotoSwipeAnimations.kt`
  - **Description**: Smooth photo transitions with side-loading
  - **Dependencies**: Compose animations, State management

- [ ] **Thumbnail Selection Animation** (iOS: ThumbnailView enhancements)
  - **Android Target**: `ui/animations/ThumbnailAnimations.kt`
  - **Description**: 20% scaling with dynamic spacing for selected thumbnails

### Layout & Spacing
- [ ] **Dynamic Spacing System** (iOS: getThumbnailSpacing function)
  - **Android Target**: `ui/layout/DynamicSpacing.kt`
  - **Description**: Context-aware spacing calculations
  - **Dependencies**: Layout constants, Selection state

## 📱 Platform-Specific Considerations

### Android Adaptations Needed
- [ ] **Material Design Integration**
  - Adapt iOS navigation patterns to Material Design
  - Use Material components where appropriate
  - Maintain app-specific design language

- [ ] **Android Navigation**
  - Adapt custom navigation to Android conventions
  - Handle system back button properly
  - Implement proper fragment/screen lifecycle

- [ ] **Permission Handling**
  - Adapt iOS permission requests to Android permission system
  - Handle runtime permissions properly
  - Implement proper permission rationales

- [ ] **Background Processing**
  - Adapt iOS background tasks to Android background processing
  - Implement WorkManager for background sync
  - Handle doze mode and battery optimization

## 🧪 Testing Requirements

### Testing Components Needed
- [ ] **ActionRouter Tests**
  - Unit tests for action execution
  - Integration tests with repositories
  - UI tests for action sheet interactions

- [ ] **Photo Feature Tests**
  - AI similarity testing with mock models
  - Photo stack grouping logic tests
  - Swipe animation performance tests

- [ ] **Navigation Tests**
  - Screen transition tests
  - Context switching tests
  - State persistence tests

## 📋 Implementation Priority

### Phase 1: Core Architecture (High Priority)
1. ActionRouter system
2. UniversalActionSheet framework
3. Selection service
4. Enhanced navigation

### Phase 2: Photo Features (High Priority)
1. Two-image swipe animation
2. Enhanced thumbnails
3. Photo similarity (basic)
4. ECard basic functionality

### Phase 3: Advanced Features (Medium Priority)
1. Complete AI photo features
2. Advanced ECard templates
3. Enhanced cloud sync
4. Complete list management

### Phase 4: Polish & Optimization (Low Priority)
1. Performance optimizations
2. Advanced animations
3. Accessibility improvements
4. Testing coverage completion

## 📝 Notes

### Development Guidelines
- Maintain feature parity with iOS while following Android design patterns
- Use Jetpack Compose for all new UI components
- Follow Android architecture guidelines (MVVM, Repository pattern)
- Ensure proper dependency injection with Hilt
- Implement comprehensive testing for all new features

### Architecture Decisions
- Use Compose for UI to match SwiftUI declarative patterns
- Implement Repository pattern to match iOS service layer
- Use Room database to match Core Data functionality
- Follow Material Design while maintaining app identity