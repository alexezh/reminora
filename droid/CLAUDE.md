# droid/ Directory

## Purpose
Android implementation of the Reminora app using Kotlin, Jetpack Compose, and modern Android architecture.

## Contents

### App Structure
- **app/** - Main Android application module
- **build.gradle.kts** - Project-level build configuration
- **settings.gradle.kts** - Project settings and module configuration
- **gradle.properties** - Gradle configuration properties

### Documentation
- **README.md** - Android-specific setup and development guide
- **overview_android.md** - Android architecture overview
- **ANDROID_ADDRESS_IMPLEMENTATION_SUMMARY.md** - Address handling implementation
- **ANDROID_UPDATE_SUMMARY.md** - Recent updates and changes
- **SYNC_REFERENCE.md** - Synchronization with iOS implementation reference

## Key Features
- **Kotlin-based** Android app with modern architecture patterns
- **Jetpack Compose** UI framework for declarative UI
- **Room Database** for local data persistence
- **Retrofit** for network API integration
- **Hilt/Dagger** for dependency injection
- **MVVM Architecture** with ViewModels and repository pattern

## Architecture Highlights

### Data Layer
- **Room Database**: Local data persistence with DAOs
- **Repository Pattern**: Data abstraction layer
- **API Service**: Retrofit-based network layer
- **Entity Models**: Room entities and data models

### UI Layer
- **Jetpack Compose**: Modern declarative UI framework
- **MVVM Pattern**: ViewModels managing UI state
- **Navigation Component**: Screen navigation management
- **Theme System**: Material Design theming

### Dependency Injection
- **Hilt/Dagger**: Dependency injection framework
- **Module Organization**: Network, Database, and Repository modules

## Current Implementation Status

### Completed Features
- Basic app structure with navigation
- Authentication system with OAuth integration
- Photo management and display
- Map integration with place markers
- Quick List functionality
- Local database with Room

### Areas Needing iOS Parity
- Universal Action Sheet system equivalent
- Dynamic toolbar/FAB navigation system
- Two-image swipe animation for photo viewing
- ECard creation and template system
- Advanced photo similarity and AI features
- Complete rlist (list management) system
- Comprehensive sheet management system

## Development Guidelines

### Code Structure
- Follow Android architectural patterns (MVVM, Repository)
- Use Jetpack Compose for all UI components
- Implement dependency injection with Hilt
- Follow Material Design guidelines

### iOS Parity Requirements
- Maintain feature parity with iOS implementation
- Adapt iOS navigation patterns to Android conventions
- Implement equivalent action systems and UI patterns
- Ensure consistent user experience across platforms

## Important Notes

### State Management
- Use Compose State and ViewModels for UI state
- Implement proper lifecycle-aware components
- Handle configuration changes gracefully

### Performance Considerations
- Implement proper image loading and caching
- Use lazy loading for large photo collections
- Optimize database queries and background operations

### Testing Strategy
- Unit tests for ViewModels and repositories
- Integration tests for database operations
- UI tests with Compose testing framework