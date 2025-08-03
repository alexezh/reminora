# ui/ Directory

## Purpose
Jetpack Compose UI layer containing all screens, ViewModels, and UI components for the Android app.

## Contents

### Core App Structure
- **ReminoraApp.kt** - Main Compose application setup and theme configuration
- **main/MainScreen.kt** - Main navigation controller (equivalent to iOS ContentView)
- **theme/** - Material Design theme configuration

### Feature Screens
- **auth/** - Authentication and login screens
- **home/** - Home screen with main navigation
- **photos/** - Photo viewing and management screens
- **map/** - Map-based location and pin screens
- **places/** - Place management and detail screens
- **lists/** - List management screens (rlist equivalent)
- **quicklist/** - Quick List functionality
- **profile/** - User profile screens
- **add/** - Add place/pin screens

## Key Components

### Navigation Structure
- **MainScreen**: Central navigation controller managing tab state
- **Bottom Navigation**: Material Design bottom navigation bar
- **Screen Composables**: Individual screen implementations using Compose

### State Management
- **ViewModels**: MVVM pattern with lifecycle-aware ViewModels
- **UI State**: Compose State and StateFlow for reactive UI updates
- **Navigation State**: Navigation component for screen transitions

## iOS Parity Requirements

### Missing iOS Features
1. **Universal Action Sheet System**
   - Need Android equivalent of UniversalActionSheet
   - Context-aware action menus/bottom sheets
   - ActionRouter equivalent for centralized action handling

2. **Dynamic Toolbar System**
   - Adaptive toolbar based on current screen context
   - Universal FAB button system
   - Context-sensitive toolbar buttons

3. **Advanced Photo Features**
   - Two-image swipe animation system for SwipePhotoView
   - Enhanced thumbnail selection with scaling and spacing
   - AI-powered photo similarity detection

4. **ECard System**
   - Template-based card creation
   - SVG template rendering in Android
   - ECard editor interface

5. **Sheet Management System**
   - Centralized sheet/modal management
   - Sheet routing equivalent to iOS SheetStack

### Architecture Improvements Needed
- **ActionRouter**: Centralized action handling system
- **Selection Service**: Multi-selection state management
- **Layout Constants**: Shared UI constants for consistency
- **Context Management**: Action context awareness system

## Development Patterns

### Compose Best Practices
```kotlin
// Screen structure
@Composable
fun PhotoScreen(
    viewModel: PhotoViewModel = hiltViewModel(),
    onNavigate: (String) -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    
    // UI implementation
}

// ViewModel pattern
@HiltViewModel
class PhotoViewModel @Inject constructor(
    private val repository: PhotoRepository
) : ViewModel() {
    // State management
}
```

### Material Design Integration
- Use Material Design 3 components
- Implement proper color schemes and typography
- Follow Android design guidelines while maintaining app consistency

### State Handling
- Use `collectAsState()` for reactive UI updates
- Implement proper error handling and loading states
- Handle configuration changes gracefully

## Testing Strategy

### UI Testing
- Use Compose testing framework for UI tests
- Test user interactions and navigation flows
- Verify proper state updates and UI rendering

### Integration Testing
- Test ViewModel and Repository integration
- Verify proper data flow between layers
- Test navigation and state persistence