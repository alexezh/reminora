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
    let stack: PhotoStack
    let initialIndex: Int
    let onDismiss: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.toolbarManager) private var toolbarManager
    @State private var currentIndex: Int
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
    
    private var preferenceManager: PhotoPreferenceManager {
        PhotoPreferenceManager(viewContext: viewContext)
    }
    
    @StateObject private var photoSharingService = PhotoSharingService.shared
    
    init(stack: PhotoStack, initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.stack = stack
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    private var currentAsset: PHAsset {
        return stack.assets[currentIndex]
    }
    
    var body: some View {
        ZStack {
            // Full-screen black background
            Color.black
                .ignoresSafeArea(.all)
            
            if !isPreferenceManagerReady {
                // Show loading UI while preference manager is initializing
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .foregroundColor(.white)
                        .padding(.top, 16)
                }
            } else {
                GeometryReader { geometry in
                    // Calculate safe area for photo to avoid overlap with UI
                    let topSafeArea: CGFloat = 120 // Space for top navigation
                    let bottomSafeArea: CGFloat = stack.assets.count > 1 ? 80 : 20 // Space for thumbnails
                    let availableHeight = geometry.size.height - topSafeArea - bottomSafeArea
                    
                    VStack(spacing: 0) {
                        // Top spacer for navigation
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: topSafeArea)
                        
                        // Scrollable photo and map area
                        ScrollViewReader { scrollProxy in
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 0) {
                                    // Photo section
                                    if !stack.assets.isEmpty {
                                        TabView(selection: $currentIndex) {
                                            ForEach(Array(stack.assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                                SwipePhotoImageView(asset: asset, isLoading: $isLoading)
                                                    .tag(index)
                                            }
                                        }
                                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                        .frame(height: availableHeight)
                                        .id("photo")
                                    } else {
                                        // Fallback for empty stack
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .frame(height: availableHeight)
                                            .id("photo")
                                    }
                                    
                                    // Map section (only show if photo has location)
                                    if currentAsset.location != nil {
                                        VStack(spacing: 16) {
                                            // Section header
                                            HStack {
                                                Image(systemName: "map")
                                                    .font(.title2)
                                                    .foregroundColor(.white)
                                                Text("Location")
                                                    .font(.title2)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.white)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.top, 20)
                                            
                                            // Map view
                                            MapViewForPhoto(location: currentAsset.location)
                                                .frame(height: availableHeight * 0.8)
                                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                                .padding(.horizontal, 20)
                                            
                                            // Location details
                                            if let location = currentAsset.location {
                                                VStack(spacing: 8) {
                                                    Text("Coordinates")
                                                        .font(.headline)
                                                        .foregroundColor(.white.opacity(0.9))
                                                    Text(formatLocation(location))
                                                        .font(.body)
                                                        .foregroundColor(.white.opacity(0.7))
                                                        .multilineTextAlignment(.center)
                                                }
                                                .padding(.horizontal, 20)
                                            }
                                            
                                            // Bottom spacing
                                            Rectangle()
                                                .fill(Color.clear)
                                                .frame(height: 60)
                                        }
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.clear,
                                                    Color.black.opacity(0.3),
                                                    Color.black.opacity(0.6)
                                                ]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .id("map")
                                    }
                                }
                            }
                            .frame(height: availableHeight)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        handleScrollGesture(value: value, geometry: geometry)
                                    }
                                    .onEnded { value in
                                        handleScrollEnd(value: value, geometry: geometry) { id, anchor in
                                            scrollProxy.scrollTo(id, anchor: anchor)
                                        }
                                    }
                            )
                            .onChange(of: currentIndex) { _, _ in
                                // Reset to photo view and show thumbnails when changing photos
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scrollProxy.scrollTo("photo", anchor: .top)
                                    showingMap = false
                                }
                            }
                        }
                        
                        // Bottom spacer (will be covered by UI)
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: bottomSafeArea)
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
                            
                            // Menu button (vertical dots) - iOS 16 style popup
                            Menu {
                                Button("Find Similar") {
                                    showingSimilarGridView = true
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                                    .padding(8)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
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
                    
                    // Floating bottom section with thumbnails (hide when map is showing)
                    if !showingMap {
                        VStack(spacing: 12) {
                            // Thumbnail strip (iOS Photos style)
                            if stack.assets.count > 1 {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 4) {
                                        ForEach(Array(stack.assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                            PhotoThumbnailView(
                                                asset: asset,
                                                isSelected: index == currentIndex,
                                                onTap: {
                                                    currentIndex = index
                                                }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .frame(height: 60)
                            }
                        }
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    Color.black.opacity(0.3),
                                    Color.black.opacity(0.6)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(.bottom, 34) // Safe area padding
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .onAppear {
            print("SwipePhotoView onAppear called with stack of \(stack.assets.count) assets")
            isLoading = true
            // Ensure the current index is valid
            if currentIndex >= stack.assets.count {
                currentIndex = 0
            }
            print("Starting preference manager initialization...")
            initializePreferenceManager()
            updateQuickListStatus()
            updateFavoriteStatus()
            setupToolbar()
        }
        .onDisappear {
            toolbarManager.hideCustomToolbar()
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
                    // Update the toolbar to reflect the new favorite state
                    self.updateToolbar()
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
        
        toolbarManager.setCustomToolbar(buttons: toolbarButtons, hideDefaultTabBar: true)
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

// MARK: - MapView Component

struct MapViewForPhoto: View {
    let location: CLLocation?
    @State private var region: MKCoordinateRegion
    
    init(location: CLLocation?) {
        self.location = location
        
        if let location = location {
            self._region = State(initialValue: MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            // Default to San Francisco if no location
            self._region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
    
    var body: some View {
        if let location = location {
            Map(coordinateRegion: $region, annotationItems: [PhotoMapAnnotationItem(coordinate: location.coordinate)]) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white).scaleEffect(0.8))
                }
            }
            .disabled(true) // Disable interaction to prevent conflicts with swipe gestures
        } else {
            // Show message when no location available
            VStack {
                Image(systemName: "location.slash")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("No location data")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray6))
        }
    }
}

struct PhotoMapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
