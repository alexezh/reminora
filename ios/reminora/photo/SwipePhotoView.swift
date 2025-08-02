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
    let allAssets: [PHAsset] // Full list of all photos
    let photoStacks: [PhotoStack] // Stack information
    let initialAssetId: String // Initial asset to display
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.toolbarManager) private var toolbarManager
    @Environment(\.selectedAssetService) private var selectedAssetService
    @State private var currentIndex: Int = 0
    @State private var expandedStacks: Set<String> = [] // Track which stacks are expanded
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
    @State private var displayAssets: [PHAsset] = [] // Assets to display (includes expanded stacks)
    
    private var preferenceManager: PhotoPreferenceManager {
        PhotoPreferenceManager(viewContext: viewContext)
    }
    
    @StateObject private var photoSharingService = PhotoSharingService.shared
    
    init(allAssets: [PHAsset], photoStacks: [PhotoStack], initialAssetId: String, onDismiss: @escaping () -> Void) {
        self.allAssets = allAssets
        self.photoStacks = photoStacks
        self.initialAssetId = initialAssetId
        self.onDismiss = onDismiss
    }
    
    private var currentAsset: PHAsset {
        guard currentIndex >= 0 && currentIndex < displayAssets.count else {
            return allAssets.first ?? PHAsset()
        }
        return displayAssets[currentIndex]
    }
    
    // Helper function to get stack info for an asset
    private func getStackInfo(for asset: PHAsset) -> (stack: PhotoStack?, isStack: Bool, count: Int) {
        for stack in photoStacks {
            if stack.assets.contains(where: { $0.localIdentifier == asset.localIdentifier }) {
                return (stack: stack, isStack: stack.assets.count > 1, count: stack.assets.count)
            }
        }
        return (stack: nil, isStack: false, count: 1)
    }
    
    // Build display assets based on expanded stacks
    private func buildDisplayAssets() {
        var assets: [PHAsset] = []
        
        for stack in photoStacks {
            let stackId = stack.id.uuidString
            if stack.assets.count > 1 && expandedStacks.contains(stackId) {
                // Stack is expanded - add all assets with separation
                assets.append(contentsOf: stack.assets)
            } else {
                // Single asset or collapsed stack - add primary asset only
                assets.append(stack.primaryAsset)
            }
        }
        
        displayAssets = assets
        
        // Don't try to update currentIndex here to avoid circular dependency
        print("buildDisplayAssets: Built \(displayAssets.count) display assets")
    }
    
    // Expand a stack to show all photos
    private func expandStack(_ stack: PhotoStack?) {
        guard let stack = stack else { return }
        let stackId = stack.id.uuidString
        
        // Store current asset to maintain position
        let currentAsset = displayAssets.count > currentIndex ? displayAssets[currentIndex] : nil
        
        expandedStacks.insert(stackId)
        buildDisplayAssets()
        
        // Update currentIndex to maintain current photo position
        if let currentAsset = currentAsset,
           let newIndex = displayAssets.firstIndex(where: { $0.localIdentifier == currentAsset.localIdentifier }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex = newIndex
            }
        }
        
        print("Expanded stack \(stackId) - now showing \(displayAssets.count) assets")
    }
    
    // Collapse a stack
    private func collapseStack(_ stack: PhotoStack?) {
        guard let stack = stack else { return }
        let stackId = stack.id.uuidString
        
        // Store current asset to maintain position
        let currentAsset = displayAssets.count > currentIndex ? displayAssets[currentIndex] : nil
        
        expandedStacks.remove(stackId)
        buildDisplayAssets()
        
        // Update currentIndex - if current photo was part of collapsed stack, 
        // move to stack's primary asset
        if let currentAsset = currentAsset {
            if let newIndex = displayAssets.firstIndex(where: { $0.localIdentifier == currentAsset.localIdentifier }) {
                // Current photo still exists in display
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentIndex = newIndex
                }
            } else if stack.assets.contains(where: { $0.localIdentifier == currentAsset.localIdentifier }) {
                // Current photo was part of collapsed stack - move to primary asset
                if let primaryIndex = displayAssets.firstIndex(where: { $0.localIdentifier == stack.primaryAsset.localIdentifier }) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentIndex = primaryIndex
                    }
                }
            }
        }
        
        print("Collapsed stack \(stackId) - now showing \(displayAssets.count) assets")
    }
    
    // Get thumbnail spacing for visual stack separation
    private func getThumbnailSpacing(for asset: PHAsset, at index: Int) -> (leading: CGFloat, trailing: CGFloat) {
        let stackInfo = getStackInfo(for: asset)
        
        // Half photo width for separation (30px since thumbnail is 60px)
        let halfPhotoSpacing: CGFloat = 30
        let normalSpacing = LayoutConstants.thumbnailSpacing
        
        guard let stack = stackInfo.stack, stack.assets.count > 1 else {
            // Single photo - use normal spacing
            return (normalSpacing, normalSpacing)
        }
        
        let stackId = stack.id.uuidString
        let isExpanded = expandedStacks.contains(stackId)
        
        if !isExpanded {
            // Collapsed stack - use normal spacing
            return (normalSpacing, normalSpacing)
        }
        
        // Expanded stack - add half-photo separation around the stack group
        let isFirstInStack = asset.localIdentifier == stack.assets.first?.localIdentifier
        let isLastInStack = asset.localIdentifier == stack.assets.last?.localIdentifier
        
        var leadingSpacing: CGFloat = normalSpacing
        var trailingSpacing: CGFloat = normalSpacing
        
        if isFirstInStack {
            // First photo in expanded stack - add half-photo spacing before
            leadingSpacing = halfPhotoSpacing
        }
        
        if isLastInStack {
            // Last photo in expanded stack - add half-photo spacing after
            trailingSpacing = halfPhotoSpacing
        }
        
        return (leadingSpacing, trailingSpacing)
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
    
    // Handle swipe navigation with stack boundary respect
    private func handleStackBoundarySwipe(_ translationWidth: CGFloat) {
        let currentAsset = displayAssets[currentIndex]
        let currentStackInfo = getStackInfo(for: currentAsset)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            if translationWidth > 0 {
                // Swipe right (go to previous photo)
                if currentIndex > 0 {
                    let newIndex = currentIndex - 1
                    
                    // Check if we're in an expanded stack and hitting boundary
                    if let stack = currentStackInfo.stack,
                       expandedStacks.contains(stack.id.uuidString),
                       let firstStackAsset = stack.assets.first,
                       currentAsset.localIdentifier == firstStackAsset.localIdentifier {
                        // At beginning of expanded stack - don't go further
                        print("Blocked swipe: at beginning of expanded stack")
                        return
                    }
                    
                    currentIndex = newIndex
                }
            } else {
                // Swipe left (go to next photo)
                if currentIndex < displayAssets.count - 1 {
                    let newIndex = currentIndex + 1
                    
                    // Check if we're in an expanded stack and hitting boundary
                    if let stack = currentStackInfo.stack,
                       expandedStacks.contains(stack.id.uuidString),
                       let lastStackAsset = stack.assets.last,
                       currentAsset.localIdentifier == lastStackAsset.localIdentifier {
                        // At end of expanded stack - don't go further with regular swipe
                        print("Blocked swipe: at end of expanded stack")
                        return
                    }
                    
                    currentIndex = newIndex
                }
            }
        }
    }
    
    // Handle long-pull navigation (closes stack and moves to next)
    private func handleLongPullNavigation(_ translationWidth: CGFloat) {
        let currentAsset = displayAssets[currentIndex]
        let currentStackInfo = getStackInfo(for: currentAsset)
        
        // If we're in an expanded stack at the boundary, close it and move
        if let stack = currentStackInfo.stack,
           expandedStacks.contains(stack.id.uuidString) {
            
            if translationWidth < 0, // Left swipe
               let lastStackAsset = stack.assets.last,
               currentAsset.localIdentifier == lastStackAsset.localIdentifier {
                // At end of expanded stack - close stack and move to next photo
                print("Long pull: closing stack and moving to next photo")
                collapseStack(stack)
                
                // Move to next photo after stack collapse
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if self.currentIndex < self.displayAssets.count - 1 {
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
        let currentAsset = displayAssets[currentIndex]
        let currentStackInfo = getStackInfo(for: currentAsset)
        
        // Find previous stack boundary
        if let currentStack = currentStackInfo.stack {
            // If in a stack, move to first photo before this stack
            let stackAssets = currentStack.assets
            if let firstStackAsset = stackAssets.first,
               let firstStackIndex = displayAssets.firstIndex(where: { $0.localIdentifier == firstStackAsset.localIdentifier }),
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
        let currentAsset = displayAssets[currentIndex]
        let currentStackInfo = getStackInfo(for: currentAsset)
        
        // Find next stack boundary
        if let currentStack = currentStackInfo.stack {
            // If in a stack, move to first photo after this stack
            let stackAssets = currentStack.assets
            if let lastStackAsset = stackAssets.last,
               let lastStackIndex = displayAssets.firstIndex(where: { $0.localIdentifier == lastStackAsset.localIdentifier }),
               lastStackIndex + 1 < displayAssets.count {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentIndex = lastStackIndex + 1
                }
            }
        } else {
            // If single photo, just move to next photo
            if currentIndex + 1 < displayAssets.count {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentIndex += 1
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Full-screen black background
            Color.black
                .ignoresSafeArea(.all)
            
            // Show the main content immediately
            if true {
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        // Main photo area - single photo view
                        if !displayAssets.isEmpty && currentIndex < displayAssets.count {
                            let currentStackInfo = getStackInfo(for: displayAssets[currentIndex])
                            SwipePhotoImageView(asset: displayAssets[currentIndex], isLoading: $isLoading, stackInfo: currentStackInfo)
                                .scaleEffect(photoTransition ? 0.9 : 1.0) // Photo transition effect
                                .offset(x: swipeOffset) // Swipe offset for animation
                                .opacity(photoTransition ? 0.7 : 1.0) // Fade effect during transition
                                .animation(.easeInOut(duration: 0.3), value: photoTransition)
                                .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: swipeOffset)
                                .gesture(
                                    // Combined gesture for tap, long press, and swipe
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            // Show swipe effect during drag
                                            let translation = value.translation.width
                                            swipeOffset = translation * 0.3 // Damped swipe offset
                                            
                                            if abs(translation) > 20 {
                                                isLoading = true
                                            }
                                        }
                                        .onEnded { value in
                                            isLoading = false
                                            
                                            // Reset swipe offset with spring animation
                                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                                                swipeOffset = 0
                                            }
                                            
                                            // Handle different gesture types
                                            let isHorizontalSwipe = abs(value.translation.width) > abs(value.translation.height)
                                            let distance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                                            
                                            if distance < 10 {
                                                // Tap gesture - check for stack
                                                let stackInfo = getStackInfo(for: displayAssets[currentIndex])
                                                if stackInfo.isStack && stackInfo.count > 1 {
                                                    let stackId = stackInfo.stack!.id.uuidString
                                                    if expandedStacks.contains(stackId) {
                                                        collapseStack(stackInfo.stack)
                                                    } else {
                                                        expandStack(stackInfo.stack)
                                                    }
                                                }
                                            } else if isHorizontalSwipe && abs(value.translation.width) > LayoutConstants.swipeThreshold {
                                                // Trigger photo transition animation
                                                triggerPhotoTransition()
                                                
                                                // Check for long-pull (extended horizontal swipe)
                                                if abs(value.translation.width) > LayoutConstants.swipeThreshold * 2 {
                                                    // Long horizontal pull - close stack and move to next
                                                    handleLongPullNavigation(value.translation.width)
                                                } else {
                                                    // Regular horizontal swipe - navigate photos with stack boundaries
                                                    handleStackBoundarySwipe(value.translation.width)
                                                }
                                            } else if !isHorizontalSwipe && value.translation.height > LayoutConstants.swipeThreshold {
                                                // Long pull down - move to next stack/photo
                                                triggerPhotoTransition()
                                                moveToNextStack()
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
                        
                        // Thumbnail scroll view positioned right below the photo
                        ScrollViewReader { scrollProxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 0) { // Remove default spacing
                                    ForEach(Array(displayAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                        let stackInfo = getStackInfo(for: asset)
                                        let (leadingSpacing, trailingSpacing) = getThumbnailSpacing(for: asset, at: index)
                                        
                                        HStack(spacing: 0) {
                                            // Leading spacing
                                            if leadingSpacing > 0 {
                                                Spacer()
                                                    .frame(width: leadingSpacing)
                                            }
                                            
                                            ThumbnailView(
                                                asset: asset,
                                                isSelected: index == currentIndex,
                                                stackInfo: stackInfo
                                            ) {
                                                // Handle tap - if it's a stack indicator, expand/collapse
                                                if stackInfo.isStack && stackInfo.count > 1 {
                                                    let stackId = stackInfo.stack!.id.uuidString
                                                    if expandedStacks.contains(stackId) {
                                                        collapseStack(stackInfo.stack)
                                                    } else {
                                                        expandStack(stackInfo.stack)
                                                    }
                                                }
                                                currentIndex = index
                                            }
                                            
                                            // Trailing spacing
                                            if trailingSpacing > 0 {
                                                Spacer()
                                                    .frame(width: trailingSpacing)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, LayoutConstants.thumbnailPadding)
                            }
                            .frame(height: LayoutConstants.thumbnailHeight)
                            .onChange(of: currentIndex) { _, newIndex in
                                guard newIndex >= 0 && newIndex < displayAssets.count else { return }
                                // Smooth scroll to new thumbnail with spring animation
                                withAnimation(.interpolatingSpring(stiffness: 200, damping: 20)) {
                                    scrollProxy.scrollTo(displayAssets[newIndex].localIdentifier, anchor: .center)
                                }
                            }
                        }
                        .padding(.top, 20) // Space between photo and thumbnails
                        .padding(.bottom, LayoutConstants.contentToolbarGap)
                        
                        // Spacer to push content above toolbar
                        Spacer()
                    }
                    
                }
                .ignoresSafeArea(.all)
                
                // Floating top navigation overlay
                VStack {
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
                                if let location = currentAsset.location {
                                    Text(formatLocation(location))
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.9))
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                }
                                
                                if let date = currentAsset.creationDate {
                                    Text(formatDate(date))
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.9))
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                }
                            }
                            
                            Spacer()
                            
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
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
                    
                    Spacer()
                    
                    
                }
            }
        }
        .onAppear {
            print("SwipePhotoView onAppear called with \(allAssets.count) total assets and \(photoStacks.count) stacks")
            isLoading = true
            
            // Use allAssets directly to avoid expensive stack processing
            displayAssets = allAssets
            print("Using allAssets directly: \(displayAssets.count) assets - virtualized loading")
            
            // Find initial index based on initialAssetId
            if let initialIndex = displayAssets.firstIndex(where: { $0.localIdentifier == initialAssetId }) {
                currentIndex = initialIndex
                print("Set currentIndex to \(currentIndex) for asset \(initialAssetId)")
            } else {
                currentIndex = 0
                print("Defaulted currentIndex to 0")
            }
            
            print("Starting preference manager initialization...")
            initializePreferenceManager()
            updateQuickListStatus()
            updateFavoriteStatus()
            updateToolbar(false)
            // Set initial current photo in service
            selectedAssetService.setCurrentPhoto(currentAsset)
        }
        .onDisappear {
            // Don't hide the toolbar completely, let the parent view restore it
            print("🔧 SwipePhotoView: onDisappear - not hiding toolbar to allow restoration")
            // Clear current photo from service
            selectedAssetService.setCurrentPhoto(nil)
        }
        .onChange(of: currentIndex) { _, _ in
            updateQuickListStatus()
            updateFavoriteStatus()
            updateToolbar(true)
            // Update current photo in service for ActionSheet integration
            selectedAssetService.setCurrentPhoto(currentAsset)
        }
        .navigationBarHidden(true)
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
                if !showingMap && currentAsset.location != nil {
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
            let request = PHAssetChangeRequest(for: self.currentAsset)
            request.isFavorite = !self.currentAsset.isFavorite
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully toggled favorite status")
                    // Update our state to reflect the change
                    self.isFavorite = !self.isFavorite
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
        photoSharingService.sharePhoto(currentAsset)
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
        guard let location = currentAsset.location else {
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
        let newStatus = RListService.shared.isPhotoInQuickList(currentAsset, context: viewContext, userId: userId)
        print("🔍 Checking Quick List status for photo \(currentAsset.localIdentifier), userId: \(userId), result: \(newStatus)")
        isInQuickList = newStatus
    }
    
    private func updateFavoriteStatus() {
        isFavorite = currentAsset.isFavorite
        print("🔍 Updated favorite status for photo \(currentAsset.localIdentifier): \(isFavorite)")
    }
    
    private func toggleQuickList() {
        let userId = AuthenticationService.shared.currentAccount?.id ?? ""
        let wasInList = isInQuickList
        
        print("🔄 Toggling Quick List for photo \(currentAsset.localIdentifier), userId: \(userId), currently in list: \(wasInList)")
        
        let success = RListService.shared.togglePhotoInQuickList(currentAsset, context: viewContext, userId: userId)
        
        print("🔄 Toggle result: \(success)")
        
        if success {
            isInQuickList = !wasInList
            
            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            print("📝 \(wasInList ? "Removed from" : "Added to") Quick List: \(currentAsset.localIdentifier)")
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
                action: sharePhoto,
                color: .blue
            ),
            ToolbarButtonConfig(
                id: "favorite",
                title: "Favorite",
                systemImage: isFavorite ? "heart.fill" : "heart",
                action: toggleFavorite,
                color: isFavorite ? .red : .primary
            ),
            ToolbarButtonConfig(
                id: "quick",
                title: "Quick List",
                systemImage: isInQuickList ? "plus.square.fill" : "plus.square",
                action: toggleQuickList,
                color: isInQuickList ? .orange : .primary
            ),
//            ToolbarButtonConfig(
//                id: "addpin",
//                title: "Add Pin",
//                systemImage: "mappin.and.ellipse",
//                action: { showingAddPin = true },
//                color: .primary
//            )
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

// MARK: - ThumbnailView
struct ThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool
    let stackInfo: (stack: PhotoStack?, isStack: Bool, count: Int)
    let onTap: () -> Void
    
    @State private var image: UIImage?
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                        .cornerRadius(8)
                        .scaleEffect(isSelected ? 1.1 : 1.0) // Scale selected thumbnail
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.white : Color.clear, lineWidth: isSelected ? 3 : 0)
                                .shadow(color: isSelected ? Color.white.opacity(0.5) : Color.clear, radius: isSelected ? 4 : 0)
                        )
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.5)
                        )
                }
                
                // Stack indicator
                if stackInfo.isStack {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.8))
                                    .frame(width: 16, height: 16)
                                
                                Text("\(stackInfo.count)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                        }
                        Spacer()
                    }
                    .padding(2)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        await withCheckedContinuation { continuation in
            var hasResumed = false
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 120, height: 120),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                
                if !isDegraded {
                    hasResumed = true
                    self.image = image
                    continuation.resume()
                } else if image == nil {
                    hasResumed = true
                    continuation.resume()
                }
            }
        }
    }
}
