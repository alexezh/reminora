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
    @State private var currentIndex: Int = 0
    @State private var showingMenu = false
    @State private var shareData: PhotoShareData?
    @State private var isLoading = false
    @State private var swipeOffset: CGFloat = 0
    @State private var photoTransition: Bool = false
    @State private var isPreferenceManagerReady = false
    @State private var isInQuickList = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showingMap = false
    @State private var isFavorite = false
    @State private var showingActionSheet = false
    @State private var verticalOffset: CGFloat = 0 // For swipe down to dismiss
    
    // Two-image animation state
    @State private var nextPhotoStack: RPhotoStack? = nil
    @State private var previousPhotoStack: RPhotoStack? = nil
    @State private var nextImageOffset: CGFloat = 0
    @State private var previousImageOffset: CGFloat = 0
    @State private var isAnimatingToNext = false
    @State private var isAnimatingToPrevious = false
    
    private var preferenceManager: PhotoPreferenceManager {
        PhotoPreferenceManager(viewContext: viewContext)
    }
    
    @StateObject private var photoSharingService = PhotoSharingService.shared
    
    init(photoStackCollection: RPhotoStackCollection, initialStack: RPhotoStack, onDismiss: @escaping () -> Void) {
        self._photoStackCollection = ObservedObject(wrappedValue: photoStackCollection)
        self.initialStack = initialStack
        self.onDismiss = onDismiss
    }
    
    private var currentPhotoStack: RPhotoStack {
        guard currentIndex >= 0 && currentIndex < photoStackCollection.count else {
            // Create a fallback stack with the first asset or empty if no assets
            return RPhotoStack(assets: [])
        }
        
        return photoStackCollection[currentIndex]
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
    
    // MARK: - Two-Image Animation Helpers
    
    private func prepareNextImage() {
        guard currentIndex + 1 < photoStackCollection.count else {
            nextPhotoStack = nil
            return
        }
        nextPhotoStack = photoStackCollection[currentIndex + 1]
        nextImageOffset = UIScreen.main.bounds.width // Start off-screen to the right
    }
    
    private func preparePreviousImage() {
        guard currentIndex > 0 else {
            previousPhotoStack = nil
            return
        }
        previousPhotoStack = photoStackCollection[currentIndex - 1]
        previousImageOffset = -UIScreen.main.bounds.width // Start off-screen to the left
    }
    
    private func animateToNextImage() {
        guard nextPhotoStack != nil else { return }
        
        isAnimatingToNext = true
        nextImageOffset = 0 // Animate to center
        
        // Complete animation and update state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            currentIndex += 1
            isAnimatingToNext = false
            nextPhotoStack = nil
            prepareNextImage() // Prepare for next transition
            preparePreviousImage() // Update previous
        }
    }
    
    private func animateToPreviousImage() {
        guard previousPhotoStack != nil else { return }
        
        isAnimatingToPrevious = true
        previousImageOffset = 0 // Animate to center
        
        // Complete animation and update state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            currentIndex -= 1
            isAnimatingToPrevious = false
            previousPhotoStack = nil
            prepareNextImage() // Update next
            preparePreviousImage() // Prepare for previous transition
        }
    }
    
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
            if currentIndex < photoStackCollection.allAssets().count - 1 {
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
    
    // Handle long-pull navigation (closes stack and moves to next)
    private func handleLongPullNavigation(_ translationWidth: CGFloat) {
        let stack = currentPhotoStack
        let currentAsset = stack.primaryAsset
        
        // If we're in an expanded stack at the boundary, close it and move
        if stack.count > 1 && photoStackCollection.isStackExpanded(stack.id) {
            
            if translationWidth < 0, // Left swipe
               let lastStackAsset = stack.assets.last,
               currentAsset.localIdentifier == lastStackAsset.localIdentifier {
                // At end of expanded stack - close stack and move to next photo
                print("Long pull: closing stack and moving to next photo")
                collapseStack(stack)
                
                // Move to next photo after stack collapse
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if self.currentIndex < self.photoStackCollection.allAssets().count - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.currentIndex += 1
                        }
                    }
                }
                return
            }
            
            if translationWidth > 0, // Right swipe
               let firstStackAsset = stack.assets.first,
               currentAsset.localIdentifier == firstStackAsset.localIdentifier {
                // At beginning of expanded stack - close stack and move to previous photo
                print("Long pull: closing stack and moving to previous photo")
                collapseStack(stack)
                
                // Move to previous photo after stack collapse
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if self.currentIndex > 0 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.currentIndex -= 1
                        }
                    }
                }
                return
            }
        }
        
        // If not at stack boundary, use regular moveToNextStack logic
        if translationWidth < 0 {
            moveToNextStack()
        } else {
            moveToPreviousStack()
        }
    }
    
    // Move to previous stack or photo
    private func moveToPreviousStack() {
        let stack = currentPhotoStack
        
        // Find previous stack boundary
        if stack.count > 1 {
            // If in a stack, move to first photo before this stack
            if let firstStackAsset = stack.assets.first,
               let firstStackIndex = photoStackCollection.allAssets().firstIndex(where: { $0.localIdentifier == firstStackAsset.localIdentifier }),
               firstStackIndex > 0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentIndex = firstStackIndex - 1
                }
            }
        } else {
            // If single photo, just move to previous photo
            if currentIndex > 0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentIndex -= 1
                }
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
               let lastStackIndex = photoStackCollection.allAssets().firstIndex(where: { $0.localIdentifier == lastStackAsset.localIdentifier }),
               lastStackIndex + 1 < photoStackCollection.allAssets().count {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentIndex = lastStackIndex + 1
                }
            }
        } else {
            // If single photo, just move to next photo
            if currentIndex + 1 < photoStackCollection.allAssets().count {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentIndex += 1
                }
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 4) {
            HStack {
                // Navigation-style back button
                Button(action: {
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
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.3),
                    Color.clear
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    var body: some View {
        GeometryReader { screenGeometry in
            VStack(spacing: 0) {
                // Header at top
                headerView
                    .frame(height: LayoutConstants.headerHeight)
                
                // Photo content area (takes remaining space)
                ZStack {
                        // Main photo area
                    if !photoStackCollection.isEmpty && currentIndex < photoStackCollection.count {
                        ZStack {
                            // Current image
                            SwipePhotoImageView(stack: currentPhotoStack, isLoading: $isLoading)
                                .scaleEffect(photoTransition ? 0.9 : 1.0)
                                .offset(x: swipeOffset, y: verticalOffset)
                                .opacity(photoTransition ? 0.7 : (isAnimatingToNext || isAnimatingToPrevious ? 0.0 : 1.0))
                                .animation(.easeInOut(duration: 0.3), value: photoTransition)
                                .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: swipeOffset)
                                .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: verticalOffset)
                                .animation(.easeOut(duration: 0.2), value: isAnimatingToNext)
                                .animation(.easeOut(duration: 0.2), value: isAnimatingToPrevious)
                            
                            // Next image (slides in from right)
                            if let nextStack = nextPhotoStack, isAnimatingToNext {
                                SwipePhotoImageView(stack: nextStack, isLoading: .constant(false))
                                    .offset(x: nextImageOffset, y: 0)
                                    .animation(.easeOut(duration: 0.25), value: nextImageOffset)
                            }
                            
                            // Previous image (slides in from left)
                            if let previousStack = previousPhotoStack, isAnimatingToPrevious {
                                SwipePhotoImageView(stack: previousStack, isLoading: .constant(false))
                                    .offset(x: previousImageOffset, y: 0)
                                    .animation(.easeOut(duration: 0.25), value: previousImageOffset)
                            }
                        }
                        .gesture(
                            // Combined gesture for tap, long press, and swipe
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Show swipe effect during drag
                                    let translationX = value.translation.width
                                    let translationY = value.translation.height
                                    
                                    // Handle horizontal swipe for navigation
                                    swipeOffset = translationX * 0.3 // Damped swipe offset
                                    
                                    // Handle vertical swipe for dismiss (only down) - provide visual feedback
                                    if translationY > 0 {
                                        verticalOffset = min(translationY * 0.5, 200) // Damped feedback with max limit
                                    }
                                    
                                    if abs(translationX) > 20 || abs(translationY) > 20 {
                                        isLoading = true
                                    }
                                }
                                .onEnded { value in
                                    isLoading = false
                                    
                                    // Check for swipe down to dismiss first
                                    let translationY = value.translation.height
                                    let translationX = value.translation.width
                                    let velocityY = value.velocity.height
                                    let isVerticalSwipe = abs(translationY) > abs(translationX)
                                    
                                    if isVerticalSwipe && (translationY > 150 || velocityY > 800) { // Distance or velocity threshold
                                        // Dismiss immediately - let parent handle animation
                                        onDismiss()
                                        return
                                    }
                                    
                                    // Reset both offsets with spring animation
                                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                                        swipeOffset = 0
                                        verticalOffset = 0
                                    }
                                    
                                    // Handle different gesture types
                                    let isHorizontalSwipe = abs(translationX) > abs(translationY)
                                    let distance = sqrt(pow(translationX, 2) + pow(translationY, 2))
                                    
                                    if distance < 10 {
                                        // Tap gesture - check for stack
                                        let stack = currentPhotoStack
                                        if stack.count > 1 {
                                            if photoStackCollection.isStackExpanded(stack.id) {
                                                collapseStack(stack)
                                            } else {
                                                expandStack(stack)
                                            }
                                        }
                                    } else if isHorizontalSwipe && abs(translationX) > LayoutConstants.swipeThreshold {
                                        // Trigger photo transition animation
                                        triggerPhotoTransition()
                                        
                                        // Check for long-pull (extended horizontal swipe)
                                        if abs(translationX) > LayoutConstants.swipeThreshold * 2 {
                                            // Long horizontal pull - close stack and move to next
                                            handleLongPullNavigation(translationX)
                                        } else {
                                            // Regular horizontal swipe - navigate photos with stack boundaries
                                            handleStackBoundarySwipe(translationX)
                                        }
                                    }
                                }
                        )
                        .onLongPressGesture(minimumDuration: LayoutConstants.longPressThreshold) {
                            // Long press - move to next stack
                            moveToNextStack()
                        }
                    } else {
                        // Fallback when no display assets
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            Text("Loading photos...")
                                .foregroundColor(.white)
                                .padding(.top, 16)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    // Space for thumbnails at bottom
                    Color.clear
                        .frame(height: LayoutConstants.totalToolbarHeight)
                }
                                
                // Thumbnail overlay (positioned at bottom)
                VStack {
                    Spacer()
                    
                    ThumbnailListView(
                        photoStackCollection: photoStackCollection,
                        currentIndex: $currentIndex,
                        onThumbnailTap: { index in
                            currentIndex = index
                        },
                        onStackExpand: { stack in
                            expandStack(stack)
                        },
                        onStackCollapse: { stack in
                            collapseStack(stack)
                        }
                    )
                    .frame(height: LayoutConstants.thumbnailHeight)
                    .background(Color.red.opacity(0.3)) // Debug background to see thumbnail area
                    
                    // Bottom padding to account for toolbar button space
                    Color.clear
                        .frame(height: LayoutConstants.totalToolbarHeight - LayoutConstants.thumbnailHeight)
                }
                .zIndex(2)
            }
            .onAppear {
                print("SwipePhotoView onAppear called with \(photoStackCollection.allAssets().count) total assets and \(photoStackCollection.count) stacks")
                isLoading = true
                
                // Set ActionSheet context for SwipePhotoView
                UniversalActionSheetModel.shared.setContext(.swipePhoto)
                
                // Use allAssets directly to avoid expensive stack processing
                print("Using allAssets directly: \(photoStackCollection.allAssets().count) assets - virtualized loading")
                
                // Find initial index based on initialStack's primary asset
                let initialAssetId = initialStack.primaryAsset.localIdentifier
                if let initialIndex = photoStackCollection.allAssets().firstIndex(where: { $0.localIdentifier == initialAssetId }) {
                    currentIndex = initialIndex
                    print("Set currentIndex to \(currentIndex) for stack \(initialStack.id) with primary asset \(initialAssetId)")
                } else {
                    currentIndex = 0
                    print("Defaulted currentIndex to 0")
                }
                
                print("Starting preference manager initialization...")
                initializePreferenceManager()
                updateQuickListStatus()
                updateFavoriteStatus()
                updateToolbar(false)
                // Set initial current photo stack in service
                selectedAssetService.setCurrentPhotoStack(initialStack)
                
                // Initialize next/previous images for smooth transitions
                prepareNextImage()
                preparePreviousImage()
            }
            .onDisappear {
                // Don't hide the toolbar completely, let the parent view restore it
                print("🔧 SwipePhotoView: onDisappear - not hiding toolbar to allow restoration")
                // Clear current photo stack from service
                selectedAssetService.setCurrentPhotoStack(nil)
                // Reset ActionSheet context - will be set by parent view
            }
            .onChange(of: currentIndex) { _, _ in
                // Update current photo stack immediately for gesture responsiveness
                selectedAssetService.setCurrentPhotoStack(currentPhotoStack)
                
                // Debounce expensive operations to improve performance
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    updateQuickListStatus()
                    updateFavoriteStatus()
                    updateToolbar(true)
                }
            }
            .navigationBarHidden(true)
            
        }
    }
    
    // MARK: - Scroll Gesture Handlers
    
    private func handleScrollGesture(value: DragGesture.Value, geometry: GeometryProxy) {
        // Handle vertical scroll gestures - we don't need to manually track offset since ScrollView handles it
        // This is just for feedback during drag
    }
    
    private func handleScrollEnd(value: DragGesture.Value, geometry: GeometryProxy, scrollTo: @escaping (AnyHashable, UnitPoint) -> Void) {
        let translation = value.translation
        let velocity = value.velocity.height
        
        // Only handle gestures that are primarily vertical
        let isVerticalSwipe = abs(translation.height) > abs(translation.width) * 1.5
        
        if isVerticalSwipe {
            // Handle swipe up
            if translation.height < -100 || velocity < -500 {
                if !showingMap && currentPhotoStack.location != nil {
                    // Show map and hide thumbnails
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        scrollTo("map", .top)
                        showingMap = true
                    }
                }
            }
            // Handle swipe down
            else if translation.height > 100 || velocity > 500 {
                if showingMap {
                    // Close map and show thumbnails
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        scrollTo("photo", .top)
                        showingMap = false
                    }
                } else {
                    // Close the entire view
                    onDismiss()
                }
            }
        }
    }
    
    
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
        
        shareData = PhotoShareData(message: message, link: reminoraLink)
        print("PhotoStackView - After assignment - shareData:", shareData?.message ?? "nil", shareData?.link ?? "nil")
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
        let newStatus = RListService.shared.isPhotoStackInQuickList(currentPhotoStack, context: viewContext, userId: userId)
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
        
        let success = RListService.shared.togglePhotoStackInQuickList(currentPhotoStack, context: viewContext, userId: userId)
        
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
        
    private func updateToolbar(_ update: Bool) {
        // Update toolbar when photo changes - explicitly replace buttons
        print("📱 SwipePhotoView: Updating toolbar for photo \(currentIndex)")
        let toolbarButtons = [
            ToolbarButtonConfig(
                id: "share",
                title: "Share",
                systemImage: "square.and.arrow.up",
                actionType: .sharePhoto(currentPhotoStack.primaryAsset),
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


