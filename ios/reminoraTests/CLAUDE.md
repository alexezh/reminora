# reminoraTests/ Directory

## Purpose
Unit tests for the Reminora iOS application.

## Contents
- **reminoraTests.swift** - Main unit test suite

## Key Features
- XCTest framework integration
- Unit testing for app logic and services
- Core Data testing
- Model validation tests
- Service layer testing

## Test Coverage Areas
- Core Data operations
- Authentication services
- Photo processing
- Location services
- API integration
- Data model validation

## Running Tests
```bash
xcodebuild -project reminora.xcodeproj -scheme reminora -configuration Debug test -destination 'platform=iOS Simulator,name=iPhone 15'
```