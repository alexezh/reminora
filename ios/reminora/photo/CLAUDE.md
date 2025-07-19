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