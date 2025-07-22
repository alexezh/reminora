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
    
    static func == (lhs: ToolbarButtonConfig, rhs: ToolbarButtonConfig) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.systemImage == rhs.systemImage &&
               lhs.isEnabled == rhs.isEnabled &&
               lhs.color == rhs.color
    }
    
    init(
        id: String,
        title: String,
        systemImage: String,
        action: @escaping () -> Void,
        isEnabled: Bool = true,
        color: Color = .primary
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.action = action
        self.isEnabled = isEnabled
        self.color = color
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
    
    init(
        buttons: [ToolbarButtonConfig],
        position: ToolbarPosition = .bottom,
        backgroundColor: Color = .clear,
        isVisible: Bool = true,
        version: Int = 0
    ) {
        self.buttons = buttons
        self.position = position
        self.backgroundColor = backgroundColor
        self.isVisible = isVisible
        self.version = version
    }
    
    var body: some View {
        if isVisible && !buttons.isEmpty {
            HStack(spacing: 0) {
                ForEach(buttons) { button in
                    Button(action: button.action) {
                        VStack(spacing: 4) {
                            Image(systemName: button.systemImage)
                                .font(.system(size: 20))
                                .foregroundColor(button.isEnabled ? button.color : .gray)
                            
                            if !button.title.isEmpty {
                                Text(button.title)
                                    .font(.caption2)
                                    .foregroundColor(button.isEnabled ? button.color : .gray)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .disabled(!button.isEnabled)
                }
            }
            .background(backgroundColor)
            .overlay(
                // Top border for bottom toolbar, bottom border for top toolbar
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 0.5),
                alignment: position == .bottom ? .top : .bottom
            )
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
    @Published var hideDefaultTabBar = false
    @Published var version = 0
    
    func setCustomToolbar(buttons: [ToolbarButtonConfig], hideDefaultTabBar: Bool = true) {
        print("🔧 ToolbarManager: Setting \(buttons.count) toolbar buttons with IDs: \(buttons.map { $0.id })")
        customButtons = buttons
        showCustomToolbar = !buttons.isEmpty
        self.hideDefaultTabBar = hideDefaultTabBar
    }
    
    func updateCustomToolbar(buttons: [ToolbarButtonConfig]) {
        print("🔄 ToolbarManager: Updating toolbar buttons (replacing existing)")
        customButtons = buttons
        showCustomToolbar = !buttons.isEmpty
        version += 1 // Force UI update
    }
    
    func hideCustomToolbar() {
        showCustomToolbar = false
        hideDefaultTabBar = false
        customButtons = []
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