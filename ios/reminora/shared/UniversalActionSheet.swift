//
//  UniversalActionSheet.swift
//  reminora
//
//  Created by alexezh on 7/31/25.
//

import CoreData
import MapKit
import PhotosUI
import SwiftUI

// MARK: - Universal Action Sheet
struct UniversalActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.selectedAssetService) private var selectedAssetService
    @StateObject private var actionSheetModel = UniversalActionSheetModel.shared
    let selectedTab: String
    let onRefreshLists: () -> Void
    let onAddPin: () -> Void
    let onAddOpenInvite: () -> Void
    let onToggleSort: () -> Void
    let onScrollingStateChanged: ((Bool) -> Void)?

    @State private var scrollOffset: CGFloat = 0
    @State private var hasScrolled: Bool = false
    @State private var isActivelyScrolling: Bool = false
    @State private var scrollEndTimer: Timer?

    // Helper computed properties
    private var hasSelectedAssets: Bool {
        return selectedAssetService.selectedPhotoCount > 0
    }

    init(
        selectedTab: String,
        onRefreshLists: @escaping () -> Void,
        onAddPin: @escaping () -> Void,
        onAddOpenInvite: @escaping () -> Void,
        onToggleSort: @escaping () -> Void,
        onScrollingStateChanged: ((Bool) -> Void)? = nil
    ) {
        self.selectedTab = selectedTab
        self.onRefreshLists = onRefreshLists
        self.onAddPin = onAddPin
        self.onAddOpenInvite = onAddOpenInvite
        self.onToggleSort = onToggleSort
        self.onScrollingStateChanged = onScrollingStateChanged
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // Modern toolbar section - spread buttons across full width
            HStack(spacing: 0) {
                ModernToolbarButton(
                    icon: "photo",
                    title: "Photos",
                    isSelected: selectedTab == "Photo",
                    action: {
                        dismiss()
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SwitchToTab"), object: "Photo")
                    }
                )
                .frame(maxWidth: .infinity)

                ModernToolbarButton(
                    icon: "map",
                    title: "Map",
                    isSelected: selectedTab == "Map",
                    action: {
                        dismiss()
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SwitchToTab"), object: "Map")
                    }
                )
                .frame(maxWidth: .infinity)

                ModernToolbarButton(
                    icon: "mappin.and.ellipse",
                    title: "Pins",
                    isSelected: selectedTab == "Pin",
                    action: {
                        dismiss()
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SwitchToTab"), object: "Pin")
                    }
                )
                .frame(maxWidth: .infinity)

                ModernToolbarButton(
                    icon: "list.bullet.circle",
                    title: "Lists",
                    isSelected: selectedTab == "Lists",
                    action: {
                        dismiss()
                        // Post notification to auto-open quick list
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SwitchToTab"), object: "Lists")
                        NotificationCenter.default.post(
                            name: NSNotification.Name("AutoOpenQuickList"), object: nil)
                    }
                )
                .frame(maxWidth: .infinity)

                // Editor button - only shown when there's an active editor
                if let currentEditor = actionSheetModel.currentEditor {
                    ModernToolbarButton(
                        icon: currentEditor.iconName,
                        title: currentEditor.displayName,
                        isSelected: false,
                        action: {
                            dismiss()
                            NotificationCenter.default.post(
                                name: NSNotification.Name("OpenCurrentEditor"), object: currentEditor)
                        }
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    // Spacer to maintain layout when no editor
                    Spacer()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Separator line
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 20)

            // Scrollable actions section
            ScrollView(.vertical, showsIndicators: false) {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("scroll")).minY)
                }
                .frame(height: 0)

                LazyVStack(spacing: 0) {
                    switch actionSheetModel.context {
                    case .photos:
                        photosTabActions()
                    case .map:
                        mapTabActions()
                    case .pins:
                        pinsTabActions()
                    case .lists:
                        listsTabActions()
                    case .quickList:
                        quickListActions()
                    case .profile:
                        profileTabActions()
                    case .swipePhoto(let stack):
                        swipePhotoActions(stack: stack)
                    case .pinDetail:
                        pinDetailActions()
                    case .ecard:
                        ecardActions()
                    case .clip:
                        clipActions()
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxHeight: 300)  // Limit scrollable area height
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                let newOffset = value
                let scrollDistance = abs(newOffset - scrollOffset)

                if scrollDistance > 5 {
                    hasScrolled = true
                }

                // Track if actively scrolling (offset is changing)
                let wasScrolling = isActivelyScrolling

                // Cancel previous timer
                scrollEndTimer?.invalidate()

                if scrollDistance > 0.5 {
                    if !isActivelyScrolling {
                        isActivelyScrolling = true
                        onScrollingStateChanged?(true)
                    }

                    // Set timer to detect when scrolling ends
                    scrollEndTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) {
                        _ in
                        if isActivelyScrolling {
                            isActivelyScrolling = false
                            onScrollingStateChanged?(false)
                        }
                    }
                }

                scrollOffset = newOffset
            }
        }
        .padding(.bottom, 20)
        .background(Color(.systemBackground))
    }

    // MARK: - Common Actions
    
    @ViewBuilder
    private func settingsAction() -> some View {
        ActionListItem(
            icon: "gear", title: "Settings", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: "Profile")
        }
    }
    
    // MARK: - Tab Action Functions

    @ViewBuilder
    private func photosTabActions() -> some View {
        ActionListItem(
            icon: "archivebox", title: "Archive", isEnabled: hasSelectedAssets, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.archive)
        }
        ActionListItem(
            icon: "trash", title: "Delete", isEnabled: hasSelectedAssets, isDestructive: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.delete)
        }
        ActionListItem(
            icon: "doc.on.doc", title: "Duplicate", isEnabled: hasSelectedAssets, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.duplicate)
        }
        ActionListItem(
            icon: "plus.square", title: "Add to Quick List", isEnabled: hasSelectedAssets,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.addToQuickList(nil)
        }
        ActionListItem(
            icon: "rectangle.stack", title: "Make ECard", isEnabled: hasSelectedAssets, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.makeECard([])
        }
        ActionListItem(
            icon: "video.circle", title: "Make Clip", isEnabled: hasSelectedAssets, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeClip([]))
        }
        ActionListItem(
            icon: "magnifyingglass", title: "Find Similar", isEnabled: hasSelectedAssets,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.findSimilar(nil))
        }
        ActionListItem(
            icon: "doc.on.doc.fill", title: "Find Duplicates", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.findDuplicates(nil))
        }
        ActionListItem(
            icon: "square.grid.2x2", title: "Make Collage", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeCollage([]))
        }
        
        settingsAction()
    }

    @ViewBuilder
    private func mapTabActions() -> some View {
        ActionListItem(
            icon: "plus.circle", title: "Add Pin", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.addPin)
        }
        ActionListItem(
            icon: "person.3", title: "Add Open Invite", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.addOpenInvite)
        }
        ActionListItem(
            icon: "arrow.up.arrow.down", title: "Toggle Sort", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.toggleSort)
        }

        ActionListItem(icon: "photo", title: "Photos", isEnabled: true, hasScrolled: $hasScrolled) {
            dismiss()
            ActionRouter.shared.execute(.switchToTab("Photo"))
        }
        ActionListItem(
            icon: "mappin.and.ellipse", title: "Pins", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.switchToTab("Pin"))
        }
        
        settingsAction()
    }

    @ViewBuilder
    private func pinsTabActions() -> some View {
        ActionListItem(
            icon: "plus.circle", title: "Add Pin", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.addPin)
        }
        ActionListItem(
            icon: "person.3", title: "Add Open Invite", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.addOpenInvite)
        }
        ActionListItem(
            icon: "arrow.up.arrow.down", title: "Toggle Sort", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.toggleSort)
        }

        ActionListItem(
            icon: "archivebox", title: "Archive", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.archive)
        }
        ActionListItem(
            icon: "trash", title: "Delete", isEnabled: true, isDestructive: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.delete)
        }
        ActionListItem(
            icon: "doc.on.doc", title: "Duplicate", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.duplicate)
        }
        ActionListItem(
            icon: "plus.square", title: "Add to Quick List", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.addToQuickList(nil)
        }
        ActionListItem(
            icon: "magnifyingglass", title: "Find Similar", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.findSimilar(nil)
        }
        ActionListItem(
            icon: "doc.on.doc.fill", title: "Find Duplicates", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.findDuplicates(nil))
        }
        ActionListItem(
            icon: "rectangle.stack", title: "Make ECard", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeECard([]))
        }
        ActionListItem(
            icon: "video.circle", title: "Make Clip", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeClip([]))
        }
        ActionListItem(
            icon: "square.grid.2x2", title: "Make Collage", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeCollage([]))
        }
        
        settingsAction()
    }

    @ViewBuilder
    private func quickListActions() -> some View {
        ActionListItem(
            icon: "trash", title: "Empty Quick List", isEnabled: true, isDestructive: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.emptyQuickList)
        }
        ActionListItem(
            icon: "plus.rectangle.on.folder", title: "Create List", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.createListFromQuickList)
        }
        ActionListItem(
            icon: "folder.badge.plus", title: "Add to List", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.addQuickListToExistingList)
        }
        ActionListItem(
            icon: "video", title: "Make Clip", isEnabled: hasSelectedAssets,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeClip([]))
        }
        
        settingsAction()
    }

    @ViewBuilder
    private func listsTabActions() -> some View {
        ActionListItem(
            icon: "arrow.clockwise", title: "Refresh", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.refreshLists)
        }

        ActionListItem(
            icon: "video", title: "Make Clip", isEnabled: hasSelectedAssets,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeClip([]))
        }

        ActionListItem(
            icon: "archivebox", title: "Archive", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.archive)
        }
        ActionListItem(
            icon: "trash", title: "Delete", isEnabled: true, isDestructive: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.delete)
        }
        ActionListItem(
            icon: "doc.on.doc", title: "Duplicate", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.duplicate)
        }
        ActionListItem(
            icon: "plus.square", title: "Add to Quick List", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.addToQuickList(nil)
        }
        ActionListItem(
            icon: "magnifyingglass", title: "Find Similar", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.findSimilar(nil)
        }
        ActionListItem(
            icon: "doc.on.doc.fill", title: "Find Duplicates", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.findDuplicates(nil)
        }
        ActionListItem(
            icon: "rectangle.stack", title: "Make ECard", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeECard([]))
        }
        ActionListItem(
            icon: "video.circle", title: "Make Clip", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeClip([]))
        }
        ActionListItem(
            icon: "square.grid.2x2", title: "Make Collage", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeCollage([]))
        }
        
        settingsAction()
    }

    @ViewBuilder
    private func swipePhotoActions(stack: RPhotoStack) -> some View {
        ActionListItem(
            icon: "heart", title: "Favorite", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.toggleFavorite(stack)
        }
        ActionListItem(
            icon: "square.and.arrow.up", title: "Share", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.sharePhoto(stack)
        }
        ActionListItem(
            icon: "plus.square", title: "Add to Quick List", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.addToQuickList(stack)
        }
        ActionListItem(
            icon: "rectangle.stack", title: "Make ECard", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeECard([]))
        }
        ActionListItem(
            icon: "video.circle", title: "Make Clip", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeClip([]))
        }
        ActionListItem(
            icon: "magnifyingglass", title: "Find Similar", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.findSimilar(nil))
        }
        ActionListItem(
            icon: "mappin.and.ellipse", title: "Add Pin", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.addPinFromPhoto(stack)
        }
        
        settingsAction()
    }

    @ViewBuilder
    private func pinDetailActions() -> some View {
        ActionListItem(
            icon: "square.and.arrow.up", title: "Share", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.sharePhoto(nil)
        }
        ActionListItem(
            icon: "plus.square", title: "Add to Quick List", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.addToQuickList(nil)
        }
        
        settingsAction()
    }

    @ViewBuilder
    private func ecardActions() -> some View {
        ActionListItem(
            icon: "textformat", title: "Edit Caption", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.editCaption()
        }
        ActionListItem(
            icon: "photo", title: "Select Image", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.selectImage()
        }
        ActionListItem(
            icon: "square.and.arrow.down", title: "Save Photo", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.savePhoto()
        }
        
        settingsAction()
    }

    @ViewBuilder
    private func clipActions() -> some View {
        ActionListItem(
            icon: "play.circle", title: "Preview", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            // TODO: Implement preview action
            print("📹 Preview clip action")
        }
        ActionListItem(
            icon: "square.and.arrow.up", title: "Export", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            // TODO: Implement export action
            print("📹 Export clip action")
        }
        ActionListItem(
            icon: "photo.on.rectangle.angled", title: "Add Images", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            // TODO: Implement add images action
            print("📹 Add images to clip action")
        }
        
        settingsAction()
    }

    @ViewBuilder
    private func profileTabActions() -> some View {
        ActionListItem(
            icon: "archivebox", title: "Archive", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.archive)
        }
        ActionListItem(
            icon: "trash", title: "Delete", isEnabled: true, isDestructive: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.delete)
        }
        ActionListItem(
            icon: "doc.on.doc", title: "Duplicate", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.duplicate)
        }
        ActionListItem(
            icon: "plus.square", title: "Add to Quick List", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.addToQuickList()
        }
        ActionListItem(
            icon: "magnifyingglass", title: "Find Similar", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.findSimilar(nil))
        }
        ActionListItem(
            icon: "doc.on.doc.fill", title: "Find Duplicates", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.findDuplicates(nil))
        }
        ActionListItem(
            icon: "rectangle.stack", title: "Make ECard", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeECard([]))
        }
        ActionListItem(
            icon: "video.circle", title: "Make Clip", isEnabled: true, hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeClip([]))
        }
        ActionListItem(
            icon: "square.grid.2x2", title: "Make Collage", isEnabled: true,
            hasScrolled: $hasScrolled
        ) {
            dismiss()
            ActionRouter.shared.execute(.makeCollage([]))
        }
        
        settingsAction()
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Modern Toolbar Button
struct ModernToolbarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? Color.accentColor : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActionListItem: View {
    let icon: String
    let title: String
    let isEnabled: Bool
    let isDestructive: Bool
    let action: () -> Void
    @Binding var hasScrolled: Bool

    init(
        icon: String, title: String, isEnabled: Bool = true, isDestructive: Bool = false,
        hasScrolled: Binding<Bool> = .constant(false), action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.isEnabled = isEnabled
        self.isDestructive = isDestructive
        self._hasScrolled = hasScrolled
        self.action = action
    }

    var body: some View {
        Button(
            action: isEnabled
                ? {
                    if !hasScrolled {
                        action()
                    }
                    hasScrolled = false  // Reset scroll state after any tap
                } : {}
        ) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(
                        isEnabled ? (isDestructive ? .red : .accentColor) : .secondary.opacity(0.5)
                    )
                    .frame(width: 20)

                Text(title)
                    .font(.body)
                    .foregroundColor(
                        isEnabled ? (isDestructive ? .red : .primary) : .secondary.opacity(0.5))

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .background(
            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .opacity(isEnabled ? 0 : 1)
        )
    }
}

// Keep legacy button for compatibility
struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .clipShape(Circle())

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct UniversalActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
