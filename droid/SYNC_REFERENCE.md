# Android App Sync Reference

## Last iOS Sync Point
**Git Commit**: `741fcc2` - "more auth"
**Date**: 2025-07-08
**Status**: Android app created from iOS version at this commit

## iOS Features to Sync
The iOS app has the following features that need to be implemented in Android:

### ✅ Completed (Basic Structure)
- [x] Authentication system with OAuth support
- [x] Home screen with photo timeline
- [x] Basic UI structure with Material 3 design
- [x] Repository pattern for API calls
- [x] Hilt dependency injection setup

### 🔄 In Progress / To Do

#### Authentication Features
- [ ] Apple Sign In (use Google Play Games Services equivalent)
- [ ] Google OAuth integration with real SDK
- [ ] GitHub OAuth support
- [ ] Handle/username selection flow
- [ ] Session management with secure storage
- [ ] Auto-refresh token handling

#### Core Features
- [ ] Photo capture with camera
- [ ] Photo library access
- [ ] Location services and GPS tagging
- [ ] Map view with photo markers
- [ ] Photo upload with base64 encoding
- [ ] Timeline/feed with real photos
- [ ] Nearby places integration
- [ ] Distance calculations and display

#### Social Features
- [ ] Follow/unfollow system
- [ ] User search functionality
- [ ] Profile management
- [ ] Settings and preferences
- [ ] Cloud sync service

#### Advanced Features
- [ ] Offline-first architecture
- [ ] Local database (Room) integration
- [ ] Push notifications
- [ ] Share extensions
- [ ] Photo editing capabilities
- [ ] Search and discovery

## iOS App Structure Reference
```
ios/reminora/
├── Authentication/
│   ├── AuthenticationService.swift
│   ├── AuthenticationModels.swift
│   └── LoginView.swift
├── API/
│   ├── APIService.swift
│   ├── APIModels.swift
│   └── CloudSyncService.swift
├── UI/
│   ├── MapView.swift
│   ├── PhotoLibraryView.swift
│   ├── FullPhotoView.swift
│   ├── ProfileView.swift
│   └── NearbyPlacesView.swift
└── Core/
    ├── Persistence.swift
    └── LocationManager.swift
```

## Android App Structure (Current)
```
droid/app/src/main/java/com/reminora/android/
├── ui/
│   ├── auth/          # ✅ Basic auth UI
│   ├── home/          # ✅ Timeline UI
│   ├── camera/        # ❌ Not implemented
│   ├── profile/       # ❌ Not implemented
│   └── theme/         # ✅ Material 3 theme
├── data/
│   ├── api/           # ✅ API interface defined
│   ├── repository/    # ✅ Repository pattern
│   └── database/      # ❌ Not implemented
└── di/                # ❌ DI modules needed
```

## Key Differences iOS vs Android
1. **UI Framework**: SwiftUI vs Jetpack Compose
2. **Navigation**: SwiftUI Navigation vs Navigation Compose
3. **State Management**: @StateObject vs ViewModel + StateFlow
4. **Dependency Injection**: Manual vs Hilt
5. **OAuth**: Sign in with Apple vs Google Play Services
6. **Storage**: Keychain vs EncryptedSharedPreferences
7. **Camera**: AVFoundation vs CameraX
8. **Maps**: MapKit vs Google Maps

## Next Steps
1. **Implement Google OAuth** - Complete authentication flow
2. **Add Camera functionality** - Photo capture and gallery
3. **Implement Map view** - Google Maps integration
4. **Add photo upload** - Connect to backend API
5. **Implement follow system** - Social features
6. **Add offline support** - Room database

## Backend API Compatibility
The Android app uses the same backend API as iOS:
- **Base URL**: `https://reminora-backend.reminora.workers.dev`
- **Authentication**: Bearer token (session-based)
- **Photo Storage**: Base64 encoded JSON
- **OAuth Support**: Google, GitHub, Apple

## Testing Strategy
- Unit tests for ViewModels and Repositories
- UI tests for critical user flows
- Integration tests for API calls
- Manual testing on various Android devices

## Notes
- Android app follows Material 3 design guidelines
- Uses modern Android architecture (MVVM + Repository)
- Jetpack Compose for UI
- Kotlin coroutines for async operations
- Hilt for dependency injection

---
**Next Sync**: Update this file when syncing with future iOS commits
**Maintainer**: Update Android features to match iOS functionality