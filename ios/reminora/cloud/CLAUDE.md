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
- **PinSharingService.swift** - Share pins and places via cloud

### User Management
- **ProfileView.swift** - User profile display
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
- Pin sharing functionality