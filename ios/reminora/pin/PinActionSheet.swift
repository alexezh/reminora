import SwiftUI

struct PinActionSheet: View {
    let isInQuickCollection: Bool
    let onMap: () -> Void
    let onPhotos: () -> Void
    let onToggleQuick: () -> Void
    let onEditLocations: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.vertical, 12)
            
            // Action buttons
            VStack(spacing: 0) {
                PinActionButton(
                    icon: "map",
                    title: "Map",
                    action: onMap
                )
                
                PinActionButton(
                    icon: "photo",
                    title: "Photos",
                    action: onPhotos
                )
                
                PinActionButton(
                    icon: isInQuickCollection ? "checkmark.square.fill" : "plus.square",
                    title: isInQuickCollection ? "Remove from Quick" : "Add to Quick",
                    action: onToggleQuick
                )
                
                PinActionButton(
                    icon: "location.circle",
                    title: "Edit Locations",
                    action: onEditLocations
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34) // Safe area padding
        }
        .background(Color(.systemBackground))
    }
}

struct PinActionButton: View {
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