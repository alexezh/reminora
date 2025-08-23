# cloud/ Directory

## Purpose
Cloud services, authentication, and API integration for the Reminora app.

## Contents

### Authentication
- **AuthenticationService.swift** - Core authentication service and user management
- **AuthenticationModels.swift** - Data models for user accounts and authentication
- **AuthenticationView.swift** - Authentication UI components
- **LoginView.swift** - Login interface
- **GoogleSignInHelper.swift** - Google OAuth integration
- **FacebookSignInHelper.swift** - Facebook authentication integration

### Cloud Services
- **CloudSyncService.swift** - Synchronization between local and cloud data
- **APIService.swift** - HTTP API client and networking
- **APIModels.swift** - Data models for API communication
- **PinSharingService.swift** - Centralized deep link handling and pin sharing functionality

### User Management
- **ProfileView.swift** - User profile display with debug deep link testing capabilities
- **UserProfileView.swift** - User profile management
- **SubscriptionService.swift** - In-app purchases and subscriptions

### Location
- **LocationManager.swift** - Core Location wrapper for GPS services

## Key Features
- OAuth authentication (Google, Facebook)
- User profile management
- Cloud data synchronization
- RESTful API integration
- Location services
- Pin sharing functionality with ownership tracking
- Deep link handling for shared pins (reminora:// scheme)
- Debug deep link testing via ProfileView

## Deep Link Architecture

### PinSharingService
- **Central Hub**: All deep link processing flows through PinSharingService.shared.handleReminoraLink()
- **URL Scheme**: Handles `reminora://` scheme for shared pins
- **Ownership Preservation**: Tracks originalUserId, originalUsername, originalDisplayName for shared pins
- **Integration Points**:
  - reminoraApp.swift: Production deep link handling
  - ProfileView.swift: Debug deep link testing via manual URL entry

### Deep Link Flow
1. **URL Reception**: App receives `reminora://place/...` URL
2. **Authentication Check**: Defer processing if user not authenticated
3. **Parameter Extraction**: Parse name, lat, lon, ownerId, ownerHandle from query parameters
4. **Pin Creation**: Create new PinData with location and owner information
5. **List Integration**: Add to "Shared" list for organization
6. **Navigation**: Automatically navigate to newly created shared pin

### Owner Information Tracking
- **originalUserId**: Cloud/backend user ID of the pin's original creator
- **originalUsername**: Handle/username of the original creator
- **originalDisplayName**: Display name of the original creator
- **Usage**: Enables proper attribution when viewing shared pins from other users