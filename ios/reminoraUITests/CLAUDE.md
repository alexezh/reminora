# reminoraUITests/ Directory

## Purpose
UI automation tests for the Reminora iOS application.

## Contents
- **reminoraUITests.swift** - Main UI test suite
- **reminoraUITestsLaunchTests.swift** - App launch and startup tests

## Key Features
- XCUITest framework integration
- Automated UI testing
- User interaction simulation
- App launch testing
- End-to-end workflow validation

## Test Coverage Areas
- App launch and initialization
- Navigation between views
- Photo library integration
- Map interactions
- User authentication flows
- Share extension functionality

## Running UI Tests
```bash
xcodebuild -project reminora.xcodeproj -scheme reminora -configuration Debug test -destination 'platform=iOS Simulator,name=iPhone 15'
```