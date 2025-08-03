# reminora/ Directory

## Purpose
Main iOS application directory containing the Reminora app source code.

## Contents
- **reminoraApp.swift** - SwiftUI App entry point and Core Data environment setup
- **Info.plist** - App configuration and permissions
- **Assets.xcassets/** - App icons, colors, and image assets
- **reminora.entitlements** - App capabilities and entitlements

## Subdirectories
- **cloud/** - Authentication, cloud sync, and API services
- **ecard/** - ECard template system and editor functionality
- **photo/** - Photo library, viewing, AI features, and photo-related functionality
- **pin/** - Map pins, location-based features, place management, and location discovery
- **rlist/** - List management and sharing features
- **shared/** - Shared UI components, navigation, and system services
- **Preview Content/** - SwiftUI preview assets

## Key Features
- SwiftUI-based iOS app with custom navigation system
- Core Data integration with advanced data modeling
- Photo library access with AI-powered similarity detection
- Location services and map integration
- Cloud synchronization with Cloudflare Workers backend
- Universal Action Sheet system with context-aware actions
- Dynamic toolbar system with FAB navigation
- Two-image swipe animation system for smooth photo transitions

## Architecture Highlights

### Navigation System
- **Custom Navigation**: Replaced TabView with VStack + ZStack for complete control
- **Dynamic Toolbar**: Context-aware bottom toolbar with universal FAB
- **Universal Action Sheet**: Centralized action system with context enum
- **Sheet Management**: Centralized sheet routing with SheetStack

### Core Components
- **ContentView**: Main navigation controller with tab management
- **DynamicToolbar**: Flexible toolbar system with FAB and regular buttons
- **UniversalActionSheet**: Context-sensitive action sheet with tab-specific actions
- **ActionRouter**: Centralized action handling with dependency injection

### UI/UX Guidelines
- **SwipePhotoView**: MUST use overlay presentation, not sheet/fullScreenCover
- **Toolbar Integration**: All views must properly set ActionSheet context
- **Animation System**: Two-image sliding transitions for photo navigation
- **Thumbnail Enhancement**: 20% larger selected thumbnails with dynamic spacing

## Important Guidelines
- **Entity Renames**: Always confirm with user before making large-scale entity or model renames that affect Core Data and multiple files
- **Breaking Changes**: Ask for explicit confirmation before making changes that could break compilation across many files
- **Core Data**: Remember that Core Data entity renames require careful coordination between model updates and code changes
- **Action Sheet Context**: Views must set appropriate context using UniversalActionSheetModel.shared.setContext()
- **Toolbar Restoration**: Use NotificationCenter "RestoreToolbar" for proper toolbar state management