# shared/ Directory

## Purpose
Shared UI components, navigation system, and core services used throughout the iOS app.

## Contents

### Navigation & UI Framework
- **ContentView.swift** - Main app controller with custom navigation system
- **DynamicToolbar.swift** - Flexible bottom toolbar with FAB and regular buttons
- **UniversalActionSheet.swift** - Context-sensitive action sheet system
- **UniversalActionSheetModel.swift** - Action sheet context state management
- **ActionRouter.swift** - Centralized action handling with dependency injection
- **LayoutConstants.swift** - Shared layout constants for consistent UI

### Sheet Management
- **SheetRouter.swift** - Centralized sheet presentation routing
- **SheetStack.swift** - Stack-based sheet management system
- **SheetType.swift** - Enum defining all available sheet types

### Services
- **SelectionService.swift** - Multi-selection state management for photos/assets
- **LocationModels.swift** - Shared location data models and utilities

### Documentation
- **DynamicToolbar-Usage.md** - Usage guide for toolbar system

## Key Features

### Navigation Architecture
- **Custom Navigation System**: Replaced iOS TabView with VStack + ZStack for complete control
- **Dynamic Toolbar**: Context-aware toolbar that adapts to current view
- **Universal FAB**: "R" circle button present on all screens, opens action sheet
- **Tab Management**: Manual tab switching with proper state restoration

### Action System
- **Context-Based Actions**: ActionSheet adapts to current context (.photos, .quickList, etc.)
- **Action Router**: Centralized action handling with dependency injection
- **Notification System**: Action execution via NotificationCenter for loose coupling

### Toolbar System
- **FAB-Only Mode**: Floating action button only (Photos, Profile tabs)
- **Full Toolbar Mode**: FAB + additional buttons (Map tab)
- **Custom Toolbar Mode**: Context-specific buttons (SwipePhotoView)

## Architecture Guidelines

### Navigation Flow
1. **ContentView** manages tab state and calls `setupToolbarForTab()`
2. **setupToolbarForTab()** configures toolbar AND sets ActionSheet context
3. **Views** can override context using `UniversalActionSheetModel.shared.setContext()`
4. **ActionSheet** adapts based on current context enum value

### Toolbar Integration
```swift
// Setting up toolbar for a view
toolbarManager.setCustomToolbar(buttons: buttonConfigs)
UniversalActionSheetModel.shared.setContext(.appropriateContext)

// In view lifecycle
.onAppear {
    UniversalActionSheetModel.shared.setContext(.viewSpecificContext)
}
.onDisappear {
    // Context will be reset by parent view
}
```

### Action Handling
```swift
// Using ActionRouter
ActionRouter.shared.execute(.actionType)

// Custom actions
ActionRouter.shared.execute(.custom("actionId") { 
    // Custom logic
})
```

## UI/UX Standards

### Toolbar Behavior
- **Consistent FAB**: Universal "R" button on all screens
- **Context Sensitivity**: Toolbar adapts to current view context
- **Smooth Transitions**: Proper state restoration after overlays

### ActionSheet Patterns
- **Context Awareness**: Actions adapt to current screen context
- **Destructive Actions**: Properly marked with red styling
- **Accessibility**: All actions have proper titles and icons

### Animation Standards
- **Toolbar Transitions**: Spring animations for toolbar changes
- **ActionSheet**: Standard iOS sheet presentation with proper detents
- **State Changes**: Smooth animations for selection and navigation states

## Important Notes

### State Management
- **Centralized Services**: SelectionService, ActionRouter, SheetStack are singletons
- **Environment Integration**: Services injected via SwiftUI environment
- **Context Synchronization**: ActionSheet context must be kept in sync with view state

### Performance Considerations
- **Lazy Loading**: ActionSheet content loads only when needed
- **Efficient Updates**: Toolbar updates use versioning to avoid unnecessary rebuilds
- **Memory Management**: Proper cleanup in view lifecycle methods

### Testing Considerations
- **Mock Services**: All services can be mocked for testing
- **Action Verification**: ActionRouter execution can be tested via notifications
- **UI Testing**: Toolbar and ActionSheet interactions are testable via accessibility IDs