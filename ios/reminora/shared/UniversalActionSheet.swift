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
    let selectedTab: Int
    let hasPhotoSelection: Bool  // Whether photos are selected in PhotoMainView
    let onRefreshLists: () -> Void
    let onAddPin: () -> Void
    let onAddOpenInvite: () -> Void
    let onToggleSort: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            // Modern toolbar section - compact horizontal buttons
            HStack(spacing: 12) {
                ModernToolbarButton(
                    icon: "photo",
                    title: "Photos",
                    isSelected: selectedTab == 0,
                    action: {
                        dismiss()
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: 0)
                    }
                )
                
                ModernToolbarButton(
                    icon: "map",
                    title: "Map",
                    isSelected: selectedTab == 1,
                    action: {
                        dismiss()
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: 1)
                    }
                )
                
                ModernToolbarButton(
                    icon: "mappin.and.ellipse",
                    title: "Pins",
                    isSelected: selectedTab == 2,
                    action: {
                        dismiss()
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: 2)
                    }
                )
                
                ModernToolbarButton(
                    icon: "list.bullet.circle",
                    title: "Lists",
                    isSelected: selectedTab == 3,
                    action: {
                        dismiss()
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: 3)
                    }
                )
                
                ModernToolbarButton(
                    icon: "gear",
                    title: "Settings",
                    isSelected: selectedTab == 4,
                    action: {
                        dismiss()
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToTab"), object: 4)
                    }
                )
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
                LazyVStack(spacing: 0) {
                    if selectedTab == 0 {
                        // Photos tab actions
                        ActionSectionHeader("Photo Actions")
                        ActionListItem(icon: "archivebox", title: "Archive", isEnabled: hasPhotoSelection) {
                            dismiss()
                            // TODO: Implement archive
                        }
                        ActionListItem(icon: "trash", title: "Delete", isEnabled: hasPhotoSelection, isDestructive: true) {
                            dismiss()
                            // TODO: Implement delete
                        }
                        ActionListItem(icon: "doc.on.doc", title: "Duplicate", isEnabled: hasPhotoSelection) {
                            dismiss()
                            // TODO: Implement duplicate
                        }
                        ActionListItem(icon: "plus.square", title: "Add to Quick List", isEnabled: hasPhotoSelection) {
                            dismiss()
                            // TODO: Implement add to quick list
                        }
                        ActionListItem(icon: "magnifyingglass", title: "Find Similar", isEnabled: hasPhotoSelection) {
                            dismiss()
                            // TODO: Implement find similar
                        }
                        ActionListItem(icon: "doc.on.doc.fill", title: "Find Duplicates", isEnabled: true) {
                            dismiss()
                            // TODO: Implement find duplicates
                        }
                        ActionListItem(icon: "rectangle.stack", title: "Make ECard", isEnabled: hasPhotoSelection) {
                            dismiss()
                            // TODO: Implement make ecard
                        }
                        ActionListItem(icon: "square.grid.2x2", title: "Make Collage", isEnabled: hasPhotoSelection) {
                            dismiss()
                            // TODO: Implement make collage
                        }
                    } else if selectedTab == 1 {
                        // Map tab actions
                        ActionSectionHeader("Photo Actions")
                        ActionListItem(icon: "archivebox", title: "Archive", isEnabled: true) {
                            dismiss()
                            // TODO: Implement archive
                        }
                        ActionListItem(icon: "trash", title: "Delete", isEnabled: true, isDestructive: true) {
                            dismiss()
                            // TODO: Implement delete
                        }
                        ActionListItem(icon: "doc.on.doc", title: "Duplicate", isEnabled: true) {
                            dismiss()
                            // TODO: Implement duplicate
                        }
                        ActionListItem(icon: "plus.square", title: "Add to Quick List", isEnabled: true) {
                            dismiss()
                            // TODO: Implement add to quick list
                        }
                        ActionListItem(icon: "magnifyingglass", title: "Find Similar", isEnabled: true) {
                            dismiss()
                            // TODO: Implement find similar
                        }
                        ActionListItem(icon: "doc.on.doc.fill", title: "Find Duplicates", isEnabled: true) {
                            dismiss()
                            // TODO: Implement find duplicates
                        }
                        ActionListItem(icon: "rectangle.stack", title: "Make ECard", isEnabled: true) {
                            dismiss()
                            // TODO: Implement make ecard
                        }
                        ActionListItem(icon: "square.grid.2x2", title: "Make Collage", isEnabled: true) {
                            dismiss()
                            // TODO: Implement make collage
                        }
                    } else if selectedTab == 2 {
                        // Pins tab actions
                        ActionSectionHeader("Pin Actions")
                        ActionListItem(icon: "plus.circle", title: "Add Pin", isEnabled: true) {
                            dismiss()
                            onAddPin()
                        }
                        ActionListItem(icon: "envelope.open", title: "Open Invite", isEnabled: true) {
                            dismiss()
                            onAddOpenInvite()
                        }
                        ActionListItem(icon: "arrow.up.arrow.down", title: "Sort", isEnabled: true) {
                            dismiss()
                            onToggleSort()
                        }
                        
                        ActionSectionHeader("Photo Actions")
                        ActionListItem(icon: "archivebox", title: "Archive", isEnabled: true) {
                            dismiss()
                            // TODO: Implement archive
                        }
                        ActionListItem(icon: "trash", title: "Delete", isEnabled: true, isDestructive: true) {
                            dismiss()
                            // TODO: Implement delete
                        }
                        ActionListItem(icon: "doc.on.doc", title: "Duplicate", isEnabled: true) {
                            dismiss()
                            // TODO: Implement duplicate
                        }
                        ActionListItem(icon: "plus.square", title: "Add to Quick List", isEnabled: true) {
                            dismiss()
                            // TODO: Implement add to quick list
                        }
                        ActionListItem(icon: "magnifyingglass", title: "Find Similar", isEnabled: true) {
                            dismiss()
                            // TODO: Implement find similar
                        }
                        ActionListItem(icon: "doc.on.doc.fill", title: "Find Duplicates", isEnabled: true) {
                            dismiss()
                            // TODO: Implement find duplicates
                        }
                        ActionListItem(icon: "rectangle.stack", title: "Make ECard", isEnabled: true) {
                            dismiss()
                            // TODO: Implement make ecard
                        }
                        ActionListItem(icon: "square.grid.2x2", title: "Make Collage", isEnabled: true) {
                            dismiss()
                            // TODO: Implement make collage
                        }
                    } else if selectedTab == 3 {
                        // Lists tab actions
                        ActionSectionHeader("List Actions")
                        ActionListItem(icon: "arrow.clockwise", title: "Refresh", isEnabled: true) {
                            dismiss()
                            onRefreshLists()
                        }
                        
                        ActionSectionHeader("Photo Actions")
                        ActionListItem(icon: "archivebox", title: "Archive", isEnabled: true) {
                            dismiss()
                            // TODO: Implement archive
                        }
                        ActionListItem(icon: "trash", title: "Delete", isEnabled: true, isDestructive: true) {
                            dismiss()
                            // TODO: Implement delete
                        }
                        ActionListItem(icon: "doc.on.doc", title: "Duplicate", isEnabled: true) {
                            dismiss()
                            // TODO: Implement duplicate
                        }
                        ActionListItem(icon: "plus.square", title: "Add to Quick List", isEnabled: true) {
                            dismiss()
                            // TODO: Implement add to quick list
                        }
                        ActionListItem(icon: "magnifyingglass", title: "Find Similar", isEnabled: true) {
                            dismiss()
                            // TODO: Implement find similar
                        }
                        ActionListItem(icon: "doc.on.doc.fill", title: "Find Duplicates", isEnabled: true) {
                            dismiss()
                            // TODO: Implement find duplicates
                        }
                        ActionListItem(icon: "rectangle.stack", title: "Make ECard", isEnabled: true) {
                            dismiss()
                            // TODO: Implement make ecard
                        }
                        ActionListItem(icon: "square.grid.2x2", title: "Make Collage", isEnabled: true) {
                            dismiss()
                            // TODO: Implement make collage
                        }
                    } else {
                        // Profile/Settings tab
                        ActionSectionHeader("Photo Actions")
                        ActionListItem(icon: "archivebox", title: "Archive", isEnabled: true) {
                            dismiss()
                            // TODO: Implement archive
                        }
                        ActionListItem(icon: "trash", title: "Delete", isEnabled: true, isDestructive: true) {
                            dismiss()
                            // TODO: Implement delete
                        }
                        ActionListItem(icon: "doc.on.doc", title: "Duplicate", isEnabled: true) {
                            dismiss()
                            // TODO: Implement duplicate
                        }
                        ActionListItem(icon: "plus.square", title: "Add to Quick List", isEnabled: true) {
                            dismiss()
                            // TODO: Implement add to quick list
                        }
                        ActionListItem(icon: "magnifyingglass", title: "Find Similar", isEnabled: true) {
                            dismiss()
                            // TODO: Implement find similar
                        }
                        ActionListItem(icon: "doc.on.doc.fill", title: "Find Duplicates", isEnabled: true) {
                            dismiss()
                            // TODO: Implement find duplicates
                        }
                        ActionListItem(icon: "rectangle.stack", title: "Make ECard", isEnabled: true) {
                            dismiss()
                            // TODO: Implement make ecard
                        }
                        ActionListItem(icon: "square.grid.2x2", title: "Make Collage", isEnabled: true) {
                            dismiss()
                            // TODO: Implement make collage
                        }
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxHeight: 300) // Limit scrollable area height
        }
        .padding(.bottom, 20)
        .background(Color(.systemBackground))
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

// MARK: - Action List Components
struct ActionSectionHeader: View {
    let title: String
    
    init(_ title: String) {
        self.title = title
    }
    
    var body: some View {
        Text(title)
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
}

struct ActionListItem: View {
    let icon: String
    let title: String
    let isEnabled: Bool
    let isDestructive: Bool
    let action: () -> Void
    
    init(icon: String, title: String, isEnabled: Bool = true, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isEnabled = isEnabled
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: isEnabled ? action : {}) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isEnabled ? (isDestructive ? .red : .accentColor) : .secondary.opacity(0.5))
                    .frame(width: 20)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(isEnabled ? (isDestructive ? .red : .primary) : .secondary.opacity(0.5))
                
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
