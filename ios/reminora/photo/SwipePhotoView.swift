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

// Photo group info for stack display
struct PhotoGroup {
    let stackId: String
    let assets: [PHAsset]
    let isExpanded: Bool = false
}

// presented as overlay; takes whole screen
struct SwipePhotoView: View {
    let allAssets: [PHAsset] // Full list of all photos
    let photoStacks: [PhotoStack] // Stack information
    let initialAssetId: String // Initial asset to display
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.toolbarManager) private var toolbarManager
    @State private var currentIndex: Int = 0
    @State private var expandedStacks: Set<String> = [] // Track which stacks are expanded
    @State private var showingNearbyPhotos = false
    @State private var showingAddPin = false
    @State private var showingSimilarImages = false
    @State private var showingSimilarGridView = false
    @State private var showingMenu = false
    @State private var shareData: PhotoShareData?
    @State private var isLoading = false
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
        expandedStacks.insert(stackId)
        buildDisplayAssets()
    }
    
    // Collapse a stack
    private func collapseStack(_ stack: PhotoStack?) {
        guard let stack = stack else { return }
        let stackId = stack.id.uuidString
        expandedStacks.remove(stackId)
        buildDisplayAssets()
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
                            SwipePhotoImageView(asset: displayAssets[currentIndex], isLoading: $isLoading)
                                .gesture(
                                    DragGesture()
                                        .onEnded { value in
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if value.translation.width > 100 && currentIndex > 0 {
                                                    currentIndex -= 1
                                                } else if value.translation.width < -100 && currentIndex < displayAssets.count - 1 {
                                                    currentIndex += 1
                                                }
                                            }
                                        }
                                )
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
                        
                        // Bottom thumbnail area
                        VStack(spacing: 8) {
                            // Thumbnail scroll view
                            ScrollViewReader { scrollProxy in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 2) {
                                        ForEach(Array(displayAssets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                            ThumbnailView(
                                                asset: asset,
                                                isSelected: index == currentIndex,
                                                stackInfo: getStackInfo(for: asset)
                                            ) {
                                                currentIndex = index
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .frame(height: 60)
                                .onChange(of: currentIndex) { _, newIndex in
                                    guard newIndex >= 0 && newIndex < displayAssets.count else { return }
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        scrollProxy.scrollTo(displayAssets[newIndex].localIdentifier, anchor: .center)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 8) // Small gap above toolbar
                    }
                }
                .padding(.bottom, 72) // Account for toolbar space (60px + 12px)
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
            setupToolbar()
        }
        .onDisappear {
            // Don't hide the toolbar completely, let the parent view restore it
            print("🔧 SwipePhotoView: onDisappear - not hiding toolbar to allow restoration")
        }
        .onChange(of: currentIndex) { _, _ in
            updateQuickListStatus()
            updateFavoriteStatus()
            updateToolbar()
        }
        .sheet(isPresented: $showingAddPin) {
            NavigationView {
                AddPinFromPhotoView(
                    asset: currentAsset,
                    onDismiss: {
                        showingAddPin = false
                    }
                )
            }
        }
        .sheet(item: $shareData) { data in
            let _ = print("PhotoStackView ShareSheet - text: '\(data.message)', url: '\(data.link)'")
            ShareSheet(text: data.message, url: data.link)
        }
        .sheet(isPresented: $showingSimilarImages) {
            PhotoSimilarityView(targetAsset: currentAsset)
        }
        .sheet(isPresented: $showingSimilarGridView) {
            SimilarPhotosGridView(targetAsset: currentAsset)
        }
        .sheet(isPresented: $showingActionSheet) {
            PhotoActionSheet(
                isFavorite: isFavorite,
                isInQuickList: isInQuickList,
                onShare: sharePhoto,
                onToggleFavorite: toggleFavorite,
                onToggleQuickList: toggleQuickList,
                onAddPin: { showingAddPin = true },
                onFindSimilar: { showingSimilarGridView = true }
            )
            .presentationDetents([.medium])
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
    
    private func showSimilarImages() {
        // Simply show the photo similarity view with the current asset
        showingSimilarImages = true
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
    

    // MARK: - Toolbar Setup
    
    private func setupToolbar() {
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
            ToolbarButtonConfig(
                id: "addpin",
                title: "Add Pin",
                systemImage: "mappin.and.ellipse",
                action: { showingAddPin = true },
                color: .primary
            )
        ]
        
        toolbarManager.setCustomToolbar(buttons: toolbarButtons)
    }
    
    private func updateToolbar() {
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
            ToolbarButtonConfig(
                id: "addpin",
                title: "Add Pin",
                systemImage: "mappin.and.ellipse",
                action: { showingAddPin = true },
                color: .primary
            )
        ]
        
        toolbarManager.updateCustomToolbar(buttons: toolbarButtons)
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                        )
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
