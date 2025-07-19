# shared/ Directory

## Purpose
Shared code and services used by both the main app and share extension.

## Contents
- **Persistence.swift** - Core Data stack and database management

## Key Features
- Core Data persistent store setup
- App Group support for data sharing between main app and extension
- Database model management and migrations
- Shared database access across app targets
- Image downsampling and GPS extraction utilities

## Core Data Integration
- Manages the persistent store coordinator
- Handles database migrations between versions
- Provides managed object context for both main app and share extension
- Uses App Group container for shared data storage

## Shared Between
- Main Reminora app
- ReminoraShareExt (Share Extension)
- Both targets access the same Core Data stack through app group container