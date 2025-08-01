//
//  DynamicToolbar.swift
//  reminora
//
//  Created by Claude on 7/21/25.
//

import SwiftUI

// MARK: - Toolbar Button Configuration

struct ToolbarButtonConfig: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let action: () -> Void
    let isEnabled: Bool
    let color: Color
    let isFAB: Bool
    
    static func == (lhs: ToolbarButtonConfig, rhs: ToolbarButtonConfig) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.systemImage == rhs.systemImage &&
               lhs.isEnabled == rhs.isEnabled &&
               lhs.color == rhs.color &&
               lhs.isFAB == rhs.isFAB
    }
    
    init(
        id: String,
        title: String,
        systemImage: String,
        action: @escaping () -> Void,
        isEnabled: Bool = true,
        color: Color = .primary,
        isFAB: Bool = false
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.action = action
        self.isEnabled = isEnabled
        self.color = color
        self.isFAB = isFAB
    }
}

// MARK: - Toolbar Position

enum ToolbarPosition {
    case top
    case bottom
}

// MARK: - Dynamic Toolbar Component

struct DynamicToolbar: View {
    let buttons: [ToolbarButtonConfig]
    let position: ToolbarPosition
    let backgroundColor: Color
    let isVisible: Bool
    let version: Int
    let showOnlyFAB: Bool
    
    init(
        buttons: [ToolbarButtonConfig],
        position: ToolbarPosition = .bottom,
        backgroundColor: Color = .clear,
        isVisible: Bool = true,
        version: Int = 0,
        showOnlyFAB: Bool = false
    ) {
        self.buttons = buttons
        self.position = position
        self.backgroundColor = backgroundColor
        self.isVisible = isVisible
        self.version = version
        self.showOnlyFAB = showOnlyFAB
    }
    
    var body: some View {
        if isVisible && !buttons.isEmpty {
            let regularButtons = buttons.filter { !$0.isFAB }
            let fabButton = buttons.first { $0.isFAB }
            
            if showOnlyFAB {
                // FAB-only mode: show centered floating FAB button with no background
                if let fab = fabButton {
                    Button(action: fab.action) {
                        Image(systemName: fab.systemImage)
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(fab.isEnabled ? fab.color : Color.gray)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .disabled(!fab.isEnabled)
                }
            } else {
                // Normal mode: full toolbar
                let leftButtons = Array(regularButtons.prefix(regularButtons.count / 2))
                let rightButtons = Array(regularButtons.suffix(from: regularButtons.count / 2))
                
                VStack(spacing: 0) {
                    // Main toolbar content
                    ZStack {
                        // Background with border - reduced height
                        backgroundColor
                            .frame(height: 60) // Reduced from 70 to 60
                            .overlay(
                                Rectangle()
                                    .fill(Color(.separator))
                                    .frame(height: 0.5),
                                alignment: position == .bottom ? .top : .bottom
                            )
                        
                        HStack(spacing: 0) {
                            // Left buttons
                            ForEach(leftButtons) { button in
                                ToolbarButton(button: button)
                            }
                            
                            // Center spacer for FAB
                            if fabButton != nil {
                                Spacer().frame(width: 80) // Space for centered FAB
                            }
                            
                            // Right buttons
                            ForEach(rightButtons) { button in
                                ToolbarButton(button: button)
                            }
                        }
                        .frame(height: 60) // Match background height
                        
                        // Centered FAB button - positioned lower
                        if let fab = fabButton {
                            Button(action: fab.action) {
                                Image(systemName: fab.systemImage)
                                    .font(.title)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(fab.isEnabled ? fab.color : Color.gray)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                            }
                            .disabled(!fab.isEnabled)
                            .offset(y: position == .bottom ? 5 : -5) // Move lower in toolbar
                        }
                    }
                    
                    // Extend to bottom edge with safe area
                    Rectangle()
                        .fill(backgroundColor)
                        .frame(height: 34) // Approximate safe area bottom height
                }
            }
        }
    }
}

// MARK: - Toolbar Provider Protocol

protocol ToolbarProvider {
    func getToolbarButtons() -> [ToolbarButtonConfig]
    func getToolbarPosition() -> ToolbarPosition
    func shouldShowToolbar() -> Bool
}

// MARK: - Default Implementations

extension ToolbarProvider {
    func getToolbarPosition() -> ToolbarPosition {
        return .bottom
    }
    
    func shouldShowToolbar() -> Bool {
        return true
    }
}

// MARK: - Toolbar Manager Environment

class ToolbarManager: ObservableObject {
    @Published var customButtons: [ToolbarButtonConfig] = []
    @Published var showCustomToolbar = false
    @Published var version = 0
    @Published var showActionSheet = false
    @Published var showOnlyFAB = false // Show only the FAB button, hide toolbar background and other buttons
    
    // Universal FAB button that appears on all toolbars
    private var universalFABButton: ToolbarButtonConfig {
        return ToolbarButtonConfig(
            id: "universal_fab",
            title: "",
            systemImage: "r.circle.fill",
            action: { self.showActionSheet = true },
            color: .blue,
            isFAB: true
        )
    }
    
    func setCustomToolbar(buttons: [ToolbarButtonConfig]) {
        print("🔧 ToolbarManager: Setting \(buttons.count) toolbar buttons with IDs: \(buttons.map { $0.id })")
        
        // Remove any existing FAB buttons and add the universal one
        let nonFABButtons = buttons.filter { !$0.isFAB }
        customButtons = nonFABButtons + [universalFABButton]
        showCustomToolbar = !customButtons.isEmpty
        showOnlyFAB = false // Reset FAB-only mode
    }
    
    func updateCustomToolbar(buttons: [ToolbarButtonConfig]) {
        print("🔄 ToolbarManager: Updating toolbar buttons (replacing existing)")
        
        // Remove any existing FAB buttons and add the universal one
        let nonFABButtons = buttons.filter { !$0.isFAB }
        customButtons = nonFABButtons + [universalFABButton]
        showCustomToolbar = !customButtons.isEmpty
        version += 1 // Force UI update
    }
    
    func hideCustomToolbar() {
        showCustomToolbar = false
        showOnlyFAB = false
        customButtons = []
    }
    
    func setFABOnlyMode() {
        print("🔧 ToolbarManager: Setting FAB-only mode")
        customButtons = [universalFABButton]
        showCustomToolbar = true
        showOnlyFAB = true
        version += 1 // Force UI update
    }
}

// Environment key for toolbar manager
private struct ToolbarManagerKey: EnvironmentKey {
    static let defaultValue = ToolbarManager()
}

extension EnvironmentValues {
    var toolbarManager: ToolbarManager {
        get { self[ToolbarManagerKey.self] }
        set { self[ToolbarManagerKey.self] = newValue }
    }
}

// MARK: - Helper Views

struct ToolbarButton: View {
    let button: ToolbarButtonConfig
    
    var body: some View {
        Button(action: button.action) {
            VStack(spacing: 2) {
                Image(systemName: button.systemImage)
                    .font(.system(size: 20))
                    .foregroundColor(button.isEnabled ? button.color : .gray)
                
                if !button.title.isEmpty {
                    Text(button.title)
                        .font(.caption2)
                        .foregroundColor(button.isEnabled ? button.color : .gray)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 60) // Match reduced toolbar height
            .padding(.vertical, 4)
            .offset(y: 8) // Move buttons lower in the toolbar
        }
        .disabled(!button.isEnabled)
    }
}

#Preview {
    VStack {
        Spacer()
        
        DynamicToolbar(
            buttons: [
                ToolbarButtonConfig(
                    id: "home",
                    title: "Home",
                    systemImage: "house",
                    action: { print("Home tapped") }
                ),
                ToolbarButtonConfig(
                    id: "search",
                    title: "Search",
                    systemImage: "magnifyingglass",
                    action: { print("Search tapped") }
                ),
                ToolbarButtonConfig(
                    id: "favorite",
                    title: "Favorite",
                    systemImage: "heart",
                    action: { print("Favorite tapped") },
                    color: .red
                ),
                ToolbarButtonConfig(
                    id: "profile",
                    title: "Profile",
                    systemImage: "person.circle",
                    action: { print("Profile tapped") },
                    isEnabled: false
                )
            ],
            version: 1
        )
    }
}