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
    @State private var dragOffset: CGSize = .zero
    @State private var currentPreference: PhotoPreferenceType = .neutral
    @State private var isPreferenceManagerReady = false
    @State private var isInQuickList = false
    @State private var swipeUpOffset: CGFloat = 0
    @State private var showingMap = false
    @State private var mapDragOffset: CGFloat = 0
    
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
                    let bottomSafeArea: CGFloat = showingMap ? 0 : (stack.assets.count > 1 ? 80 : 20) // Space for thumbnails only
                    let photoHeight = geometry.size.height - topSafeArea - bottomSafeArea
                    
                    VStack(spacing: 0) {
                        // Top spacer for navigation
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: topSafeArea)
                        
                        // Photo display area (constrained to avoid overlap)
                        if !stack.assets.isEmpty {
                            TabView(selection: $currentIndex) {
                                ForEach(Array(stack.assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                                    SwipePhotoImageView(asset: asset, isLoading: $isLoading)
                                        .tag(index)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                            .frame(height: photoHeight)
                            .offset(y: swipeUpOffset)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        handleSwipeUpGesture(value: value, geometry: geometry)
                                    }
                                    .onEnded { value in
                                        handleSwipeUpEnd(value: value, geometry: geometry)
                                    }
                            )
                        } else {
                            // Fallback for empty stack
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(height: photoHeight)
                        }
                        
                        // Bottom spacer (will be covered by UI)
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: bottomSafeArea)
                    }
                }
                .ignoresSafeArea(.all)
                
                // Map overlay (iOS Photos style)
                if showingMap {
                    VStack {
                        Spacer()
                        
                        MapViewForPhoto(location: currentAsset.location)
                            .frame(height: UIScreen.main.bounds.height * 0.4)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .offset(y: mapDragOffset)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        // Only allow downward drag to dismiss
                                        if value.translation.height > 0 {
                                            mapDragOffset = value.translation.height
                                        }
                                    }
                                    .onEnded { value in
                                        if value.translation.height > 100 {
                                            // Dismiss map
                                            withAnimation(.spring()) {
                                                showingMap = false
                                                mapDragOffset = 0
                                                swipeUpOffset = 0
                                            }
                                        } else {
                                            // Snap back
                                            withAnimation(.spring()) {
                                                mapDragOffset = 0
                                            }
                                        }
                                    }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 40)
                    }
                    .background(Color.clear)
                    .zIndex(10)
                }
                
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
                            
                            // Menu button (vertical dots) - iOS 16 style popup
                            Menu {
                                Button("Find Similar") {
                                    showingSimilarGridView = true
                                }
                                Button("Add Pin", action: {
                                    showingAddPin = true
                                })
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .rotationEffect(.degrees(90))
                                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        
                        // Location and date info
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
                        .padding(.horizontal, 16)
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
                    
                    // Floating bottom section with thumbnails and action buttons (hide when map is shown)
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
                            
                            // Floating action buttons (iOS Photos style)
                            HStack {
                                Spacer()
                                
                                HStack(spacing: 20) {
                                    // Share button
                                    Button(action: sharePhoto) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.black.opacity(0.7))
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                        }
                                    }
                                    
                                    // Favorite button
                                    Button(action: toggleFavorite) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.black.opacity(0.7))
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: currentAsset.isFavorite ? "heart.fill" : "heart")
                                                .font(.title2)
                                                .foregroundColor(currentAsset.isFavorite ? .red : .white)
                                        }
                                    }
                                    
                                    // Quick List button
                                    Button(action: toggleQuickList) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.black.opacity(0.7))
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: isInQuickList ? "circle.fill" : "circle")
                                                .font(.title2)
                                                .foregroundColor(isInQuickList ? .orange : .white)
                                        }
                                    }
                                    
                                    // Reject button
                                    Button(action: thumbsDown) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.black.opacity(0.7))
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: currentPreference == .dislike ? "x.circle.fill" : "x.circle")
                                                .font(.title2)
                                                .foregroundColor(currentPreference == .dislike ? .orange : .white)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.bottom, 8)
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
                    }
                }
            }
        }
        .offset(y: dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only respond to primarily vertical drags (more vertical than horizontal)
                    let translation = value.translation
                    let isVerticalDrag = abs(translation.height) > abs(translation.width) * 1.5
                    
                    // Only allow vertical downward drags that are primarily vertical
                    if translation.height > 0 && isVerticalDrag {
                        dragOffset = CGSize(width: 0, height: translation.height)
                    }
                }
                .onEnded { value in
                    let translation = value.translation
                    let isVerticalDrag = abs(translation.height) > abs(translation.width) * 1.5
                    
                    // Only dismiss if it was a primarily vertical drag
                    if translation.height > 150 && isVerticalDrag {
                        onDismiss()
                    } else {
                        // Snap back to original position
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .onAppear {
            print("SwipePhotoView onAppear called with stack of \(stack.assets.count) assets")
            isLoading = true
            // Ensure the current index is valid
            if currentIndex >= stack.assets.count {
                currentIndex = 0
            }
            print("Starting preference manager initialization...")
            initializePreferenceManager()
        }
        .onChange(of: currentIndex) { _, _ in
            updateCurrentPreference()
            updateQuickListStatus()
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
    
    // MARK: - Swipe Up Gesture Handlers
    
    private func handleSwipeUpGesture(value: DragGesture.Value, geometry: GeometryProxy) {
        // Only handle upward swipes
        let translation = value.translation.height
        if translation < 0 {
            let progress = min(abs(translation) / (geometry.size.height * 0.3), 1.0)
            
            // Stage 1: Move photo up
            if progress < 0.5 {
                swipeUpOffset = translation * 0.5 // Dampen the movement
            } else {
                // Stage 2: Show map preview
                swipeUpOffset = -(geometry.size.height * 0.15)
                if !showingMap {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showingMap = true
                    }
                }
            }
        }
    }
    
    private func handleSwipeUpEnd(value: DragGesture.Value, geometry: GeometryProxy) {
        let translation = value.translation.height
        let velocity = value.velocity.height
        
        // Check if this was an upward swipe with sufficient velocity or distance
        if translation < -100 || velocity < -500 {
            // Complete the swipe up - show map fully
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showingMap = true
                swipeUpOffset = -(geometry.size.height * 0.2)
            }
        } else {
            // Snap back to original position
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showingMap = false
                swipeUpOffset = 0
                mapDragOffset = 0
            }
        }
    }
    
    private func thumbsUp() {
        guard isPreferenceManagerReady else { return }
        
        preferenceManager.setPreference(for: currentAsset, preference: .like)
        print("Thumbs up for photo at index \(currentIndex)")
        
        // Update UI state immediately
        currentPreference = .like
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func thumbsDown() {
        guard isPreferenceManagerReady else { return }
        
        preferenceManager.setPreference(for: currentAsset, preference: .dislike)
        print("Thumbs down for photo at index \(currentIndex)")
        
        // Update UI state immediately
        currentPreference = .dislike
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Auto-dismiss after marking as disliked
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
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
    
    
    private func createShareURL(for place: Place) {
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
    
    private func coordinate(for place: Place) -> CLLocationCoordinate2D {
        if let locationData = place.value(forKey: "location") as? Data,
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
            updateCurrentPreference()
            return
        }
        
        // Wait for Core Data context to be ready
        DispatchQueue.main.async {
            // Check if the viewContext is properly initialized
            if viewContext.persistentStoreCoordinator != nil {
                print("SwipePhotoView: Core Data ready after \(retryCount) retries")
                isPreferenceManagerReady = true
                updateCurrentPreference()
            } else {
                // Wait a bit longer and try again
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    initializePreferenceManager(retryCount: retryCount + 1)
                }
            }
        }
    }
    
    private func updateCurrentPreference() {
        guard isPreferenceManagerReady else { 
            print("Preference manager not ready, skipping preference update")
            return 
        }
        
        do {
            currentPreference = preferenceManager.getPreference(for: currentAsset)
            print("Updated preference for asset: \(currentPreference)")
        } catch {
            print("Error getting preference: \(error)")
            // Fallback to neutral if there's an error
            currentPreference = .neutral
        }
        
        // Also update Quick List status
        updateQuickListStatus()
    }
    
    // MARK: - Quick List Management
    
    private func updateQuickListStatus() {
        let userId = AuthenticationService.shared.currentAccount?.id ?? ""
        let newStatus = QuickListService.shared.isPhotoInQuickList(currentAsset, context: viewContext, userId: userId)
        print("🔍 Checking Quick List status for photo \(currentAsset.localIdentifier), userId: \(userId), result: \(newStatus)")
        isInQuickList = newStatus
    }
    
    private func toggleQuickList() {
        let userId = AuthenticationService.shared.currentAccount?.id ?? ""
        let wasInList = isInQuickList
        
        print("🔄 Toggling Quick List for photo \(currentAsset.localIdentifier), userId: \(userId), currently in list: \(wasInList)")
        
        let success = QuickListService.shared.togglePhotoInQuickList(currentAsset, context: viewContext, userId: userId)
        
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
