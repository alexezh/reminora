# Scroll Position Preservation Fix

## Problem
Back navigation from SwipePhotoView does not preserve scroll position in PhotoMainView. Users would lose their place in the photo grid when returning from the full-screen photo viewer.

## Solution
Implemented scroll position preservation using SwiftUI's ScrollViewReader and NotificationCenter:

### Changes Made

#### 1. PhotoMainView.swift
- Added `@State private var scrollPosition: String?` and `savedScrollPosition: String?` 
- Wrapped RListView in ScrollViewReader to control scroll position
- Save scroll position before navigating to SwipePhotoView
- Listen for "RestoreScrollPosition" notification to restore saved position
- Pass scrollPosition binding to RListView

#### 2. RListView.swift
- Added `@Binding var scrollPosition: String?` parameter
- Added scroll position tracking with row IDs (`row_0`, `row_1`, etc.)
- Update scrollPosition binding as user scrolls using `.onAppear` on each row
- Added row IDs using `.id("row_\(index)")` for scroll targeting

#### 3. SwipePhotoView.swift
- Send "RestoreScrollPosition" notification when dismissing via:
  - Back button tap
  - Vertical pull to dismiss
  - Swipe down gesture

## How It Works

1. **Save Position**: When user taps a photo in PhotoMainView, the current `scrollPosition` is saved to `savedScrollPosition`

2. **Track Position**: As user scrolls through RListView, the `scrollPosition` binding is updated with the currently visible row ID

3. **Restore Position**: When SwipePhotoView is dismissed, it sends a notification that PhotoMainView listens for, then uses ScrollViewReader to animate back to the saved position

## Benefits
- Seamless user experience when browsing photos
- Maintains scroll position even after viewing multiple photos in SwipePhotoView
- Uses native SwiftUI animations for smooth restoration
- Backwards compatible - other RListView usages unaffected due to default parameter

## Testing
To test:
1. Scroll down in PhotoMainView photo grid
2. Tap any photo to open SwipePhotoView
3. Dismiss SwipePhotoView (back button, swipe down, or pull down)
4. Verify scroll position is restored to where you left off