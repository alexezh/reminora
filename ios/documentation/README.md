# iOS Directory Documentation

This directory contains documentation for the iOS app structure, completely separate from the Xcode build process.

## Directory Information

### Main App (`reminora/`)
Main iOS application directory containing the Reminora app source code with SwiftUI entry points, Core Data integration, photo library access, location services, map integration, and cloud synchronization.

### Cloud Services (`reminora/cloud/`)
Authentication, API services, and cloud sync including OAuth (Google, Facebook), user profile management, cloud data synchronization, RESTful API integration, location services, and pin sharing functionality.

### Photo Features (`reminora/photo/`)
Photo library access, viewing, management, and AI features including Photos framework integration, full-screen photo viewing with gestures, AI-powered photo similarity detection, photo preference tracking, GPS extraction from EXIF data, photo sharing capabilities, image downsampling for storage, and machine learning embeddings for photo analysis.

### Map & Pins (`reminora/pin/`)
Map-based features, location pins, place management, and map interactions including interactive MapKit integration, geotagged photo management, location-based photo discovery, place comments and social features, distance-based sorting, pin collections and organization, address information display, and map annotations.

### List Management (`reminora/rlist/`)
List management system for organizing and sharing collections of places and photos including custom list creation and management, list sharing with other users, Quick List for rapid item collection, list collaboration features, search and filter capabilities, list templates and examples, and Core Data storage integration.

### Share Extension (`ReminoraShareExt/`)
iOS Share Extension for adding photos to Reminora from other apps with image and URL acceptance, GPS location extraction from shared images, Core Data saving with app group support, and integration with main app's data storage.

### Shared Code (`shared/`)
Shared code and services used by both the main app and share extension including Core Data stack and database management, App Group support for data sharing, database model management and migrations, and shared database access across app targets.

### Test Suites (`reminoraTests/`, `reminoraUITests/`)
Unit tests and UI automation tests for the Reminora iOS application using XCTest framework for unit testing and XCUITest framework for UI automation.