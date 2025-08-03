//
//  LayoutConstants.swift
//  reminora
//
//  Created by Claude on 7/31/25.
//

import Foundation

/// Shared layout constants for consistent UI positioning across the app
enum LayoutConstants {

    // MARK: - Toolbar Dimensions

    /// Main toolbar content height (buttons and FAB area)
    static let toolbarHeight: CGFloat = 60

    /// Safe area extension below toolbar (minimal like iOS Photos)
    static let toolbarSafeAreaHeight: CGFloat = 8

    /// Total toolbar height including safe area
    static let totalToolbarHeight: CGFloat = toolbarHeight + toolbarSafeAreaHeight

    /// FAB button size
    static let fabButtonSize: CGFloat = 56

    /// Regular button size
    static let regularButtonSize: CGFloat = 44

    /// Bottom padding for FAB to keep it above spacers
    static let fabBottomPadding: CGFloat = 8

    /// Bottom padding for regular buttons (minimal like iOS Photos)
    static let buttonBottomPadding: CGFloat = 2

    // MARK: - Content Spacing

    /// Gap between content and toolbar
    static let contentToolbarGap: CGFloat = 8

    /// Thumbnail scroll area height
    static let thumbnailHeight: CGFloat = 60

    /// Thumbnail spacing
    static let thumbnailSpacing: CGFloat = 2

    /// Thumbnail padding from edges
    static let thumbnailPadding: CGFloat = 16

    // MARK: - Gestures

    /// Minimum horizontal drag distance to trigger swipe navigation
    static let swipeThreshold: CGFloat = 100

    /// Long press duration for stack navigation
    static let longPressThreshold: TimeInterval = 0.6
}
