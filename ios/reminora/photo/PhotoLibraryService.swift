//
//  PhotoLibraryService.swift
//  reminora
//
//  Created by Claude on 8/15/25.
//

import Foundation
import Photos
import SwiftUI
import CoreData
import Combine

/// Service that manages photo library access and maintains a shared photo stack collection
class PhotoLibraryService: ObservableObject {
    static let shared = PhotoLibraryService()
    
    // MARK: - Published Properties
    
    @Published private(set) var photoStackCollection = RPhotoStackCollection()
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published private(set) var lastSyncDate: Date?
    
    // MARK: - Private Properties
    
    private var viewContext: NSManagedObjectContext?
    private var preferenceManager: PhotoPreferenceManager?
    private var currentFilter: PhotoFilterType = .notDisliked
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupAuthorizationObserver()
        setupAppStateObserver()
    }
    
    // MARK: - Public Methods
    
    /// Initialize the service with Core Data context and preference manager
    /// - Parameters:
    ///   - viewContext: Core Data managed object context
    ///   - preferenceManager: Photo preference manager for filtering
    ///   - initialFilter: Initial filter to apply (default: .notDisliked)
    func initialize(
        with viewContext: NSManagedObjectContext,
        preferenceManager: PhotoPreferenceManager,
        initialFilter: PhotoFilterType = .notDisliked
    ) {
        self.viewContext = viewContext
        self.preferenceManager = preferenceManager
        self.currentFilter = initialFilter
        
        // Configure the photo stack collection
        photoStackCollection.configure(
            with: viewContext,
            preferenceManager: preferenceManager,
            initialFilter: initialFilter
        )
        
        // Check current authorization status
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        // Load photos if already authorized
        if (authorizationStatus == .authorized || authorizationStatus == .limited) && !hasLoaded {
            loadPhotoLibrary()
        }
    }
    
    /// Request photo library access permission
    func requestPhotoAccess() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        print("📷 PhotoLibraryService: Current photo authorization status: \(authorizationStatus.rawValue)")
        
        switch authorizationStatus {
        case .notDetermined:
            print("📷 PhotoLibraryService: Authorization not determined, requesting access")
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                DispatchQueue.main.async {
                    print("📷 PhotoLibraryService: Authorization result: \(status.rawValue)")
                    self?.authorizationStatus = status
                    if (status == .authorized || status == .limited) && !(self?.hasLoaded ?? false) {
                        self?.loadPhotoLibrary()
                    }
                }
            }
        case .authorized, .limited:
            if !hasLoaded {
                print("📷 PhotoLibraryService: Already authorized, loading library")
                loadPhotoLibrary()
            } else {
                print("📷 PhotoLibraryService: Already authorized and loaded")
            }
        case .denied, .restricted:
            print("📷 PhotoLibraryService: Access denied or restricted. User needs to go to Settings.")
            // For denied/restricted, we can't do anything programmatically
            // The user needs to go to Settings app to grant permission
        @unknown default:
            print("📷 PhotoLibraryService: Unknown authorization status: \(authorizationStatus.rawValue)")
        }
    }
    
    /// Load or reload the photo library
    func loadPhotoLibrary() {
        guard !isLoading else {
            print("📷 PhotoLibraryService: Already loading, skipping duplicate request")
            return
        }
        
        guard viewContext != nil, preferenceManager != nil else {
            print("❌ PhotoLibraryService: Missing dependencies for loading")
            return
        }
        
        print("📷 PhotoLibraryService: Loading photo library...")
        isLoading = true
        
        Task {
            // Load all photos from library
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            var assets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
            
            print("📷 PhotoLibraryService: Loaded \(assets.count) photo assets from library")
            
            // Load assets into the collection
            await photoStackCollection.loadPhotoAssets(assets)
            
            await MainActor.run {
                isLoading = false
                hasLoaded = true
                lastSyncDate = Date()
                print("📷 PhotoLibraryService: Photo library loaded successfully")
            }
        }
    }
    
    /// Sync the photo collection to pick up new photos
    func syncPhotoCollection() {
        guard hasLoaded else {
            print("📷 PhotoLibraryService: Collection not loaded yet, performing full load")
            loadPhotoLibrary()
            return
        }
        
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            print("📷 PhotoLibraryService: No photo access, skipping sync")
            return
        }
        
        print("📷 PhotoLibraryService: Syncing photo collection...")
        
        Task {
            // Get current photo count
            let oldCount = photoStackCollection.getAllPhotoAssets().count
            
            // Load all photos from library again
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            var assets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
            
            // Reload assets into the collection
            await photoStackCollection.loadPhotoAssets(assets)
            
            await MainActor.run {
                let newCount = photoStackCollection.getAllPhotoAssets().count
                lastSyncDate = Date()
                
                if newCount > oldCount {
                    print("📷 PhotoLibraryService: Sync complete - found \(newCount - oldCount) new photos")
                } else {
                    print("📷 PhotoLibraryService: Sync complete - no new photos")
                }
            }
        }
    }
    
    /// Set a new filter and update the collection
    /// - Parameter filter: The new filter to apply
    func setFilter(_ filter: PhotoFilterType) {
        currentFilter = filter
        photoStackCollection.setFilter(filter)
    }
    
    /// Get the currently applied filter
    var appliedFilter: PhotoFilterType {
        return currentFilter
    }
    
    /// Refresh the collection with the current filter
    func refreshWithCurrentFilter() {
        photoStackCollection.refreshWithCurrentFilter()
    }
    
    // MARK: - Private Methods
    
    private func setupAuthorizationObserver() {
        // Monitor photo library changes via PHPhotoLibraryChangeObserver
        // For now, we'll rely on app state notifications for sync
        print("📷 PhotoLibraryService: Authorization observer setup complete")
    }
    
    private func setupAppStateObserver() {
        // Monitor app becoming active to sync new photos
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.handleAppBecameActive()
                }
            }
            .store(in: &cancellables)
    }
    
    
    private func handleAppBecameActive() {
        guard hasLoaded else { return }
        
        // Only sync if it's been more than 30 seconds since last sync
        if let lastSync = lastSyncDate, Date().timeIntervalSince(lastSync) < 30 {
            return
        }
        
        print("📷 PhotoLibraryService: App became active, syncing photo collection...")
        syncPhotoCollection()
    }
}

// MARK: - Environment Integration

private struct PhotoLibraryServiceKey: EnvironmentKey {
    static let defaultValue = PhotoLibraryService.shared
}

extension EnvironmentValues {
    var photoLibraryService: PhotoLibraryService {
        get { self[PhotoLibraryServiceKey.self] }
        set { self[PhotoLibraryServiceKey.self] = newValue }
    }
}