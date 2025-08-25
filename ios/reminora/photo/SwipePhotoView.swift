//
//  SwipePhotoView.swift
//  reminora
//
//  Created by alexezh on 7/14/25.
//


import SwiftUI
import Photos
import PhotosUI
import UIKit
import CoreData
import MapKit
import CoreLocation

// presented as overlay; takes whole screen
struct SwipePhotoView: View {
    @ObservedObject var photoStackCollection: RPhotoStackCollection
    let initialStack: RPhotoStack // Initial stack to display
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.toolbarManager) private var toolbarManager
    @Environment(\.selectedAssetService) private var selectedAssetService
    @Environment(\.sheetStack) private var sheetStack
    @ObservedObject private var selectionService = SelectionService.shared
    @State private var showingMenu = false
    @State private var isLoading = false
    @State private var isPreferenceManagerReady = false
    @State private var isInQuickList = false
    @State private var showingMap = false
    @State private var isFavorite = false
    @State private var showingActionSheet = false
    @State private var isViewReady = false // Prevent flash during initialization
    @State private var photoTransition = false // For photo transition animation
    @State private var currentIndex: Int = 0;

    private var preferenceManager: PhotoPreferenceManager {
        PhotoPreferenceManager(viewContext: viewContext)
    }
    
    @StateObject private var photoSharingService = PhotoSharingService.shared
    
    init(photoStackCollection: RPhotoStackCollection, initialStack: RPhotoStack, onDismiss: @escaping () -> Void) {
        self._photoStackCollection = ObservedObject(wrappedValue: photoStackCollection)
        self.initialStack = initialStack
        self.onDismiss = onDismiss
        
        // Check if there's already a selected photo in SelectionService, use that instead of initialStack
        if let currentSelectedPhoto = SelectionService.shared.selectedPhotosArray.first,
           let selectedIndex = photoStackCollection.firstIndex(where: { $0.localIdentifier == currentSelectedPhoto.localIdentifier }) {
            self._currentIndex = State(initialValue: selectedIndex)
            print("🔧 SwipePhotoView: Restored to selected photo at index \(selectedIndex)")
        } else {
            let initialIndex = photoStackCollection.firstIndex(where: { $0.localIdentifier == initialStack.localIdentifier }) ?? 0
            self._currentIndex = State(initialValue: initialIndex)
            print("🔧 SwipePhotoView: Starting with initial photo at index \(initialIndex)")
        }
    }
    
    private var currentPhotoStack: RPhotoStack {
        return self.photoStackCollection[self.currentIndex];
    }
    
    private var currentIndexBinding: Binding<Int> {
        Binding(
            get: { self.currentIndex },
            set: { newIndex in
                self.navigateToPhoto(at: newIndex)
            }
        )
    }
    
    // Expand a stack to show all photos
    private func expandStack(_ stack: RPhotoStack?) {
        guard let stack = stack else { return }
        photoStackCollection.expandStack(stack.id)
    }
    
    // Collapse a stack
    private func collapseStack(_ stack: RPhotoStack?) {
        guard let stack = stack else { return }
        photoStackCollection.collapseStack(stack.id)
    }
    
    // Navigate to specific photo stack
    private func navigateToPhoto(at index: Int) {
        guard index >= 0 && index < photoStackCollection.count else { return }
        currentIndex = index
        let newStack = photoStackCollection[index]
        selectionService.setSelectedPhoto(newStack)
        triggerPhotoTransition()
    }
    
    // Navigate to next photo
    private func navigateToNext() {
        let nextIndex = currentIndex + 1
        navigateToPhoto(at: nextIndex)
    }
    
    // Navigate to previous photo
    private func navigateToPrevious() {
        let previousIndex = currentIndex - 1
        navigateToPhoto(at: previousIndex)
    }
    
    // Trigger photo transition animation
    private func triggerPhotoTransition() {
        withAnimation(.easeInOut(duration: 0.2)) {
            photoTransition = true
        }
        
        // Reset transition state after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                photoTransition = false
            }
        }
    }
    
    // Animate to previous image
    private func animateToPreviousImage() {
        guard currentIndex > 0 else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            navigateToPrevious()
        }
    }
    
    // Animate to next image
    private func animateToNextImage() {
        guard currentIndex < photoStackCollection.count - 1 else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
            navigateToNext()
        }
    }
    
    // MARK: - ScrollView Snap Logic (inlined to avoid type issues)
    
    
    
    // Handle swipe navigation with stack boundary respect
    private func handleStackBoundarySwipe(_ translationWidth: CGFloat) {
        let stack = currentPhotoStack
        let currentAsset = stack.primaryAsset
        
        if translationWidth > 0 {
            // Swipe right (go to previous photo)
            if currentIndex > 0 {
                // Check if we're in an expanded stack and hitting boundary
                if stack.count > 1 && photoStackCollection.isStackExpanded(stack.id),
                   let firstStackAsset = stack.assets.first,
                   currentAsset.localIdentifier == firstStackAsset.localIdentifier {
                    // At beginning of expanded stack - don't go further
                    print("Blocked swipe: at beginning of expanded stack")
                    return
                }
                
                // Use animation system for smooth transition
                animateToPreviousImage()
            }
        } else {
            // Swipe left (go to next photo)
            if currentIndex < photoStackCollection.count - 1 {
                // Check if we're in an expanded stack and hitting boundary
                if stack.count > 1 && photoStackCollection.isStackExpanded(stack.id),
                   let lastStackAsset = stack.assets.last,
                   currentAsset.localIdentifier == lastStackAsset.localIdentifier {
                    // At end of expanded stack - don't go further with regular swipe
                    print("Blocked swipe: at end of expanded stack")
                    return
                }
                
                // Use animation system for smooth transition
                animateToNextImage()
            }
        }
    }
    

    
    // Move to next stack or photo (long pull/press action)
    private func moveToNextStack() {
        let stack = currentPhotoStack
        
        // Find next stack boundary
        if stack.count > 1 {
            // If in a stack, move to first photo after this stack
            if let lastStackAsset = stack.assets.last,
               let lastStackIndex = photoStackCollection.firstIndex(where: { $0.localIdentifier == lastStackAsset.localIdentifier }),
               lastStackIndex + 1 < photoStackCollection.count {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                    navigateToPhoto(at: lastStackIndex + 1)
                }
            }
        } else {
            // If single photo, just move to next photo
            if currentIndex + 1 < photoStackCollection.count {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
                    navigateToNext()
                }
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
            HStack {
                // Navigation-style back button
                Button(action: {
                    // Send notifications to restore toolbar and scroll position
                    NotificationCenter.default.post(name: NSNotification.Name("RestoreScrollPosition"), object: nil)
                    NotificationCenter.default.post(name: NSNotification.Name("RestoreToolbar"), object: nil)
                    onDismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                }
                
                Spacer()
                
                // Location and date info (centered)
                VStack(spacing: 2) {
                    if let location = currentPhotoStack.location {
                        Text(formatLocation(location))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    }
                    
                    if let date = currentPhotoStack.primaryCreationDate {
                        Text(formatDate(date))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
    }
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                
                // Header
                headerView
                    .frame(height: LayoutConstants.headerHeight)

                // Main photo area - Unified SwipePhotoImageView with integrated paging
                if isViewReady && !photoStackCollection.isEmpty && currentIndex < photoStackCollection.count {
                    SwipePhotoImageView(
                        photoStackCollection: photoStackCollection,
                        currentIndex: currentIndexBinding,
                        isLoading: $isLoading,
                        onIndexChanged: { newIndex in
                            print("📜 SwipePhotoImageView: Index changed to \(newIndex)")
                            // The binding will handle updating SelectionService
                            // UI state updates will happen via onChange(of: selectionService.getCurrentPhotoStack?.localIdentifier)
                        },
                        onVerticalPull: {
                            // Handle vertical pull to dismiss
                            NotificationCenter.default.post(name: NSNotification.Name("RestoreScrollPosition"), object: nil)
                            NotificationCenter.default.post(name: NSNotification.Name("RestoreToolbar"), object: nil)
                            onDismiss()
                        }
                    )
                    .onTapGesture {
                        // Handle tap to expand/collapse stacks
                        let stack = currentPhotoStack
                        if stack.count > 1 {
                            if photoStackCollection.isStackExpanded(stack.id) {
                                collapseStack(stack)
                            } else {
                                expandStack(stack)
                            }
                        }
                    }
                    .frame(
                        maxWidth: geo.size.width,
                        maxHeight: geo.size.height
                            - LayoutConstants.headerHeight
                            - LayoutConstants.thumbnailHeight
                            - LayoutConstants.totalToolbarHeight
                    )
                    .onLongPressGesture(minimumDuration: LayoutConstants.longPressThreshold) {
                        moveToNextStack()
                    }
                } else {
                    // Show loading state while view is initializing or if no photos
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        if !isViewReady {
                            Text("Initializing...")
                                .foregroundColor(.white)
                                .font(.caption)
                        } else {
                            Text("Loading photos…")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Thumbnails pinned above toolbar
                ThumbnailListView(
                    photoStackCollection: photoStackCollection,
                    currentIndex: currentIndexBinding,
                    onThumbnailTap: { index in navigateToPhoto(at: index) },
                    onStackExpand: expandStack,
                    onStackCollapse: collapseStack
                )
                .frame(height: LayoutConstants.thumbnailHeight)
                //.padding(.bottom, LayoutConstants.totalToolbarHeight)
                //.background(Color.red.opacity(0.3)) // debug
                .background(Color.black)
                .padding(.bottom, LayoutConstants.totalToolbarHeight + 10)
                //.padding(.bottom, geo.safeAreaInsets.bottom)
            }
            .background(Color.black)
            //.ignoresSafeArea(.all)
            //.frame(maxWidth: .infinity, maxHeight: .infinity)
            //.padding(.bottom, 0)
        }
        .onAppear {
            print("SwipePhotoView onAppear called with \(photoStackCollection.count) stacks")
            
            // Initialize state to prevent flash
            isLoading = true
            
            print("🔧 Initial state set for LazySnapPager")
            
            // Set initial selected photo in SelectionService
            selectionService.setSelectedPhoto(currentPhotoStack)
            
            initializePreferenceManager()
            updateQuickListStatus()
            updateFavoriteStatus()
            updateToolbar(false)
            
            // Set view as ready to display
            isViewReady = true
            
            // Preload the current image
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if currentPhotoStack.primaryImage == nil {
                    currentPhotoStack.loadImages()
                }
            }
            
            let initialIndex = currentIndex
            print("🔧 SwipePhotoView onAppear completed - initial stack set, computed currentIndex: \(initialIndex), isViewReady: \(isViewReady)")
        }
        .onDisappear {
            selectionService.clearSelectedPhotos()
        }
        .onChange(of: currentPhotoStack.localIdentifier) { _, _ in
            // Update UI state when SelectionService currentPhotoStack changes
            updateQuickListStatus()
            updateFavoriteStatus()
            updateToolbar(true)
        }
        .onChange(of: selectionService.selectedPhotosArray) { _, newSelection in
            // Keep currentIndex in sync with SelectionService changes from external sources
            if let selectedPhoto = newSelection.first,
               let newIndex = photoStackCollection.firstIndex(where: { $0.localIdentifier == selectedPhoto.localIdentifier }),
               newIndex != currentIndex {
                currentIndex = newIndex
                print("🔧 SwipePhotoView: Synced currentIndex to \(newIndex) from SelectionService change")
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Scroll Gesture Handlers
    
    private func toggleFavorite() {
        print("Toggling favorite for photo at index \(currentIndex)")
        
        // Toggle the iOS native favorite status
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest(for: self.currentPhotoStack.primaryAsset)
            request.isFavorite = !self.currentPhotoStack.primaryAsset.isFavorite
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully toggled favorite status")
                    // Update our state to reflect the change
                    self.isFavorite = !self.isFavorite
                    // Update toolbar to reflect new state
                    self.updateToolbar(true)
                    // Provide haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                } else {
                    print("❌ Failed to toggle favorite: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func sharePhoto() {
        // Use stock photo app style sharing
        photoSharingService.sharePhoto(currentPhotoStack.primaryAsset)
    }
    
    
    private func createShareURL(for place: PinData) {
        let coord = coordinate(for: place)
        let placeId = place.objectID.uriRepresentation().absoluteString
        let encodedName = (place.post ?? "Shared Photo").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let lat = coord.latitude
        let lon = coord.longitude
        
        // Add owner information from auth service
        let authService = AuthenticationService.shared
        let ownerId = authService.currentAccount?.id ?? ""
        let ownerHandle = authService.currentAccount?.handle ?? ""
        let encodedOwnerHandle = ownerHandle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let reminoraLink = "reminora://place/\(placeId)?name=\(encodedName)&lat=\(lat)&lon=\(lon)&ownerId=\(ownerId)&ownerHandle=\(encodedOwnerHandle)"
        
        let message = "Check out this photo on Reminora!"
        print("Share message: \(message)")
        print("Share URL: \(reminoraLink)")
    }
    
    private func coordinate(for place: PinData) -> CLLocationCoordinate2D {
        if let locationData = place.value(forKey: "coordinates") as? Data,
           let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation {
            return location.coordinate
        }
        // Default to San Francisco if no location
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }
    
    
    private func getPhotoLocation() -> CLLocationCoordinate2D? {
        guard let location = currentPhotoStack.location else {
            return nil
        }
        return location.coordinate
    }
    
    private func initializePreferenceManager() {
        initializePreferenceManager(retryCount: 0)
    }
    
    private func initializePreferenceManager(retryCount: Int) {
        // Add a timeout after 30 retries (3 seconds)
        if retryCount > 30 {
            print("Core Data initialization timeout, proceeding anyway")
            isPreferenceManagerReady = true
            return
        }
        
        // Wait for Core Data context to be ready
        DispatchQueue.main.async {
            // Check if the viewContext is properly initialized
            if viewContext.persistentStoreCoordinator != nil {
                print("SwipePhotoView: Core Data ready after \(retryCount) retries")
                isPreferenceManagerReady = true
            } else {
                // Wait a bit longer and try again
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    initializePreferenceManager(retryCount: retryCount + 1)
                }
            }
        }
    }
    
    
    // MARK: - Quick List Management
    
    private func updateQuickListStatus() {
        let userId = AuthenticationService.shared.currentAccount?.id ?? ""
        let newStatus = RListService.shared.isPhotoStackInQuickList(currentPhotoStack, context: viewContext)
        print("🔍 Checking Quick List status for photo \(currentPhotoStack.localIdentifier), userId: \(userId), result: \(newStatus)")
        isInQuickList = newStatus
    }
    
    private func updateFavoriteStatus() {
        isFavorite = currentPhotoStack.primaryAsset.isFavorite
        print("🔍 Updated favorite status for photo \(currentPhotoStack.localIdentifier): \(isFavorite)")
    }
    
    private func toggleQuickList() {
        let userId = AuthenticationService.shared.currentAccount?.id ?? ""
        let wasInList = isInQuickList
        
        print("🔄 Toggling Quick List for photo \(currentPhotoStack.localIdentifier), userId: \(userId), currently in list: \(wasInList)")
        
        let success = RListService.shared.togglePhotoStackInQuickList(currentPhotoStack, context: viewContext)
        
        print("🔄 Toggle result: \(success)")
        
        if success {
            isInQuickList = !wasInList
            
            // Update toolbar to reflect new state
            updateToolbar(true)
            
            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            print("📝 \(wasInList ? "Removed from" : "Added to") Quick List: \(currentPhotoStack.localIdentifier)")
            print("📝 New button state: \(isInQuickList)")
            
            // Force save context to ensure persistence
            do {
                try viewContext.save()
                print("📝 ✅ Context saved successfully")
            } catch {
                print("📝 ❌ Failed to save context: \(error)")
            }
        } else {
            print("❌ Failed to toggle Quick List status")
        }
    }
        
    private func addPin() {
        // Navigate to AddPinFromPhotoView with current photo
        ActionRouter.shared.addPinFromPhoto(currentPhotoStack)
    }
    
    private func updateToolbar(_ update: Bool) {
        // Update toolbar when photo changes - explicitly replace buttons
        print("📱 SwipePhotoView: Updating toolbar for photo \(currentIndex)")
        let toolbarButtons = [
            ToolbarButtonConfig(
                id: "share",
                title: "Share",
                systemImage: "square.and.arrow.up",
                action: { ActionRouter.shared.sharePhoto(currentPhotoStack) },
                color: .blue
            ),
            ToolbarButtonConfig(
                id: "favorite",
                title: "Favorite",
                systemImage: isFavorite ? "heart.fill" : "heart",
                action: toggleFavorite, // Use custom action to update local state immediately
                color: isFavorite ? .red : .primary
            ),
            ToolbarButtonConfig(
                id: "addpin",
                title: "Add Pin",
                systemImage: "mappin.and.ellipse",
                action: addPin,
                color: .green
            ),
            ToolbarButtonConfig(
                id: "quick",
                title: "Quick List",
                systemImage: isInQuickList ? "plus.square.fill" : "plus.square",
                action: toggleQuickList, // Keep custom action for immediate local state updates
                color: isInQuickList ? .orange : .primary
            )
        ]

        if update {
            toolbarManager.updateCustomToolbar(buttons: toolbarButtons)
        } else {
            toolbarManager.setCustomToolbar(buttons: toolbarButtons)
        }
    }

    // MARK: - Formatting Helpers
    
    private func formatLocation(_ location: CLLocation) -> String {
        let formatter = CLGeocoder()
        return String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}


struct PhotoMapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}


