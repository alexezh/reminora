//
//  DynamicToolbar.swift
//  reminora
//
//  Created by Claude on 7/21/25.
//

import SwiftUI

// MARK: - Toolbar Button Configuration

struct ToolbarButtonConfig: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let action: () -> Void
    let isEnabled: Bool
    let color: Color
    
    init(
        title: String,
        systemImage: String,
        action: @escaping () -> Void,
        isEnabled: Bool = true,
        color: Color = .primary
    ) {
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
    
    init(
        buttons: [ToolbarButtonConfig],
        position: ToolbarPosition = .bottom,
        backgroundColor: Color = .clear,
        isVisible: Bool = true
    ) {
        self.buttons = buttons
        self.position = position
        self.backgroundColor = backgroundColor
        self.isVisible = isVisible
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
    
    func setCustomToolbar(buttons: [ToolbarButtonConfig], hideDefaultTabBar: Bool = true) {
        customButtons = buttons
        showCustomToolbar = !buttons.isEmpty
        self.hideDefaultTabBar = hideDefaultTabBar
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
                    title: "Home",
                    systemImage: "house",
                    action: { print("Home tapped") }
                ),
                ToolbarButtonConfig(
                    title: "Search",
                    systemImage: "magnifyingglass",
                    action: { print("Search tapped") }
                ),
                ToolbarButtonConfig(
                    title: "Favorite",
                    systemImage: "heart",
                    action: { print("Favorite tapped") },
                    color: .red
                ),
                ToolbarButtonConfig(
                    title: "Profile",
                    systemImage: "person.circle",
                    action: { print("Profile tapped") },
                    isEnabled: false
                )
            ]
        )
    }
}