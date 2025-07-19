# ReminoraShareExt/ Directory

## Purpose
iOS Share Extension for adding photos to Reminora from other apps.

## Contents
- **ShareViewController.swift** - Main share extension controller
- **Info.plist** - Extension configuration and supported types
- **ReminoraShareExt.entitlements** - Extension capabilities and app group access
- **Base.lproj/MainInterface.storyboard** - Interface for share extension UI

## Key Features
- Accept images and URLs from other iOS apps
- Extract GPS location from shared images
- Save shared content to Core Data with app group support
- Integrated with main app's data storage
- Support for various image formats
- Automatic location extraction from EXIF data

## App Group Integration
- Uses `group.com.alexezh.reminora` for shared data access
- Shared Core Data stack with main app
- Seamless data synchronization between extension and main app

## Supported Share Types
- Images (JPEG, PNG, HEIC, etc.)
- URLs that contain images
- Photos from Camera Roll
- Images from web browsers and social apps