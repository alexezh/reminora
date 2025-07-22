# Dynamic Toolbar System

## Overview

The dynamic toolbar system allows views to provide custom toolbar buttons that replace the default tab bar when needed. This creates a more contextual and flexible user interface.

## Architecture

### Core Components

1. **`ToolbarButtonConfig`** - Configuration for individual toolbar buttons
2. **`DynamicToolbar`** - The visual toolbar component
3. **`ToolbarManager`** - Environment object managing toolbar state
4. **`ContentView`** - Host view that displays the toolbar

### File Structure
- `shared/DynamicToolbar.swift` - All toolbar-related components
- `ContentView.swift` - Integration with tab view system
- Views using toolbar: `SwipePhotoView.swift`, `PinDetailView.swift`

## Usage

### Setting Up Toolbar Buttons

Views can provide custom toolbar buttons by:

1. Adding `@Environment(\.toolbarManager) private var toolbarManager`
2. Creating `ToolbarButtonConfig` array in `setupToolbar()`
3. Calling `toolbarManager.setCustomToolbar()` in `onAppear`
4. Calling `toolbarManager.hideCustomToolbar()` in `onDisappear`

### Example Implementation

```swift
struct MyView: View {
    @Environment(\.toolbarManager) private var toolbarManager
    
    var body: some View {
        // View content
        Text("My View")
        .onAppear {
            setupToolbar()
        }
        .onDisappear {
            toolbarManager.hideCustomToolbar()
        }
    }
    
    private func setupToolbar() {
        let buttons = [
            ToolbarButtonConfig(
                id: "action",
                title: "Action",
                systemImage: "star",
                action: { performAction() },
                color: .blue
            ),
            ToolbarButtonConfig(
                id: "share",
                title: "Share",
                systemImage: "square.and.arrow.up", 
                action: { shareContent() },
                isEnabled: canShare,
                color: .green
            )
        ]
        
        toolbarManager.setCustomToolbar(buttons: buttons, hideDefaultTabBar: true)
    }
}
```

## Current Implementations

### SwipePhotoView Toolbar
- **Share**: Share current photo
- **Favorite**: Toggle iOS native favorite status (heart fills when favorited)
- **Reject**: Toggle photo preference (orange when rejected)
- **Quick List**: Add/remove from Quick List (fills when in list)

### SwipePhotoView Menu (Top Right)
- **Find Similar**: Search for similar photos
- **Add Pin**: Create location pin from photo

*Note: Main action buttons are in the toolbar, while secondary actions are in the top menu for cleaner organization*

### PinDetailView Toolbar  
- **Share**: Share place/pin
- **View on Map**: Show nearby locations
- **Nearby Photos**: Browse photos near this location
- **Add to List**: Add pin to Quick List

## Behavior

### Visibility Rules
- Default tab bar is hidden when custom toolbar is active
- Custom toolbar is hidden when `SwipePhotoView` is open (full screen)
- Toolbar automatically hides when view disappears
- Toolbar updates dynamically when underlying data changes

### Integration with ContentView
- `ContentView` manages both default tab bar and custom toolbar
- Uses `ToolbarManager` as environment object
- Automatically handles visibility transitions
- Positioned as overlay at bottom of screen

## Customization

### Button Configuration
- **id**: Stable identifier for the button (required for proper updates)
- **title**: Display text (can be empty)
- **systemImage**: SF Symbol icon name
- **action**: Closure to execute on tap
- **isEnabled**: Whether button is interactive (default: true)
- **color**: Button tint color (default: .primary)

**Important**: Use stable IDs (e.g., "share", "favorite") instead of generated UUIDs to ensure proper button replacement when toolbar updates.

### Toolbar Positioning  
- Currently supports bottom positioning
- Can be extended for top positioning via `ToolbarPosition` enum

### Styling
- Separator line above/below toolbar
- System background color with transparency
- Consistent spacing and sizing
- Disabled state styling

## Benefits

1. **Contextual**: Each view provides relevant actions
2. **Consistent**: Unified toolbar appearance across views
3. **Flexible**: Easy to add/remove/modify buttons
4. **Dynamic**: Buttons update based on current state
5. **Clean**: Replaces multiple floating action buttons and overcrowded navigation
6. **Organized**: All actions accessible in one location at bottom of screen
7. **iOS Standard**: Follows iOS design patterns for toolbars

## Technical Implementation

- **Environment-based**: Uses SwiftUI environment for clean data flow
- **Button replacement**: Uses stable IDs and version counter for proper SwiftUI updates
- **Equatable configs**: `ToolbarButtonConfig` conforms to `Equatable` for change detection
- **State management**: Centralized through `ToolbarManager` with `@Published` properties
- **Update mechanism**: `updateCustomToolbar()` method with version increment for forced updates

## Future Enhancements

- Support for toolbar groups/sections
- Animation transitions between toolbar configurations
- Customizable toolbar height and styling
- Support for badges on toolbar buttons
- Integration with more views in the app