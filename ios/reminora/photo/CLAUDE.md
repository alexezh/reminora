# photo/ Directory

## Purpose
Photo library access, viewing, management, and photo-related AI features.

## Contents

### Photo Viewing
- **PhotoLibraryView.swift** - Photo library browser with thumbnail grid
- **FullPhotoView.swift** - Full-screen photo viewer
- **SwipePhotoView.swift** - Swipeable photo viewing interface
- **SwipePhotoImageView.swift** - Individual photo display component
- **PhotoStackView.swift** - Stack-based photo navigation

### Photo Management
- **AddPinFromPhotoView.swift** - Add location pins from photos
- **PhotoPreference.swift** - User preferences for photos (like/dislike)
- **PhotoSharingService.swift** - Share photos via system share sheet

### AI Features
- **ImageEmbeddingService.swift** - Generate image embeddings for similarity
- **PhotoEmbeddingService.swift** - Photo-specific embedding operations
- **PhotoSimilarityView.swift** - Find similar photos interface
- **SimilarPhotosGridView.swift** - Display grid of similar photos

## Key Features
- Photo library integration (Photos framework)
- Full-screen photo viewing with gestures
- AI-powered photo similarity detection
- Photo preference tracking (like/dislike)
- GPS extraction from EXIF data
- Photo sharing capabilities
- Image downsampling for storage
- Machine learning embeddings for photo analysis

## UI/UX Guidelines

### Full-Screen Photo Viewing (MUST MAINTAIN)
- **SwipePhotoView MUST ALWAYS be presented as overlay**, not as sheet or navigation push
- Use `.overlay { SwipePhotoView(...) }` with `.zIndex(999)` for full-screen presentation
- Include proper transitions: `.transition(.asymmetric(insertion: .scale(scale: 0.1).combined(with: .opacity), removal: .scale(scale: 0.1).combined(with: .opacity)))`
- Background MUST be `Color.black.ignoresSafeArea(.all)` for true full-screen experience
- **MUST hide navigation bar and toolbar** with `.navigationBarHidden(true)` to prevent ContentView toolbar showing

### Favorite Button Behavior (MUST MAINTAIN)
- Favorite button in SwipePhotoView MUST toggle native iOS favorite status using `PHAssetChangeRequest`
- Use `currentAsset.isFavorite` to show current state (heart.fill vs heart)
- Red color for favorited photos, white for unfavorited
- Provide haptic feedback on successful toggle

### Menu Style (MUST MAINTAIN - iOS 16+ ONLY)
- **ALL menus MUST use iOS 16 style popup menus, NEVER bottom sheets**
- Use `Menu { ... } label: { ... }` instead of `.confirmationDialog` or `.actionSheet`
- Add `.menuStyle(.borderlessButton)` and `.menuIndicator(.hidden)` for clean appearance
- Menus should appear next to the button that triggered them, not at bottom of screen
- This applies to ALL views: SwipePhotoView, PhotoStackView, and any other photo-related views

### Code Examples
```swift
// ✅ CORRECT - Full-screen overlay
.overlay {
    if let selectedStack = selectedStack {
        SwipePhotoView(...)
            .transition(.asymmetric(...))
            .zIndex(999)
    }
}

// ✅ CORRECT - SwipePhotoView with hidden toolbar
var body: some View {
    ZStack {
        Color.black.ignoresSafeArea(.all)
        // ... photo content
    }
    .navigationBarHidden(true)  // Hide ContentView toolbar
}

// ✅ CORRECT - iOS 16 style menu
Menu {
    Button("Find Similar") { ... }
    Button("Share Photo") { ... }
} label: {
    Image(systemName: "ellipsis")
}
.menuStyle(.borderlessButton)
.menuIndicator(.hidden)

// ✅ CORRECT - Native favorite toggle
private func toggleFavorite() {
    PHPhotoLibrary.shared().performChanges({
        let request = PHAssetChangeRequest(for: self.currentAsset)
        request.isFavorite = !self.currentAsset.isFavorite
    })
}

// ❌ WRONG - Sheet presentation
.sheet(isPresented: $showingPhoto) {
    SwipePhotoView(...)
}

// ❌ WRONG - Bottom sheet menu
.confirmationDialog("Options", isPresented: $showingMenu) {
    Button("Action") { ... }
}
```