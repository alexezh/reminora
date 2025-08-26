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
    let action: (() -> Void)
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
    
    // Legacy initializer for backward compatibility
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
                VStack(spacing: 0) {
                    // Main toolbar content - 60px height
                    ZStack {
                        // Background with border
                        backgroundColor
                            .frame(height: LayoutConstants.toolbarHeight)
                            .overlay(
                                Rectangle()
                                    .fill(Color(.separator))
                                    .frame(height: 0.5),
                                alignment: position == .bottom ? .top : .bottom
                            )
                        
                        // Button layout with FAB positioned higher than regular buttons
                        ZStack {
                            // Regular buttons at bottom
                            VStack(spacing: 0) {
                                Spacer()
                                Spacer()
                                
                                HStack {
                                    // Left side buttons
                                    HStack(spacing: 16) {
                                        ForEach(regularButtons.prefix(2)) { button in
                                            ToolbarButton(button: button)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 16)
                                    
                                    // Center spacer for FAB
                                    Spacer()
                                        .frame(width: LayoutConstants.fabButtonSize + 16)
                                    
                                    // Right side buttons
                                    HStack(spacing: 16) {
                                        ForEach(regularButtons.suffix(from: min(2, regularButtons.count))) { button in
                                            ToolbarButton(button: button)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.trailing, 16)
                                }
                                .padding(.bottom, LayoutConstants.buttonBottomPadding)
                            }
                            
                            // FAB button positioned higher and centered
                            if let fab = fabButton {
                                VStack {
                                    Spacer()
                                    Button(action: fab.action) {
                                        Image(systemName: fab.systemImage)
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .frame(width: LayoutConstants.fabButtonSize, height: LayoutConstants.fabButtonSize)
                                            .background(fab.isEnabled ? fab.color : Color.gray)
                                            .clipShape(Circle())
                                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                                    }
                                    .disabled(!fab.isEnabled)
                                    .padding(.bottom, LayoutConstants.fabBottomPadding)
                                }
                            }
                        }
                        .frame(height: LayoutConstants.toolbarHeight)
                    }
                    
                    // Safe area extension - reduced height like iOS Photos
                    Rectangle()
                        .fill(backgroundColor)
                        .frame(height: LayoutConstants.toolbarSafeAreaHeight)
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
    static let shared = ToolbarManager()

    @Published var customButtons: [ToolbarButtonConfig] = []
    @Published var showCustomToolbar = false
    @Published var version = 0
    @Published var showActionSheet = false
    @Published var showOnlyFAB = false // Show only the FAB button, hide toolbar background and other buttons
    
    init() {
        // ActionRouter will be configured later in ContentView to avoid circular dependency
    }
    
    // Universal FAB button that appears on all toolbars
    private var universalFABButton: ToolbarButtonConfig {
        return ToolbarButtonConfig(
            id: "universal_fab",
            title: "",
            systemImage: "r.circle.fill",
            action: { ActionRouter.shared.showActionSheet() },
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
            .frame(width: LayoutConstants.regularButtonSize, height: LayoutConstants.regularButtonSize)
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
