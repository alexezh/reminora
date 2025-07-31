import SwiftUI

struct PhotoActionSheet: View {
    let isFavorite: Bool
    let isInQuickList: Bool
    let onShare: () -> Void
    let onToggleFavorite: () -> Void
    let onToggleQuickList: () -> Void
    let onAddPin: () -> Void
    let onFindSimilar: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.vertical, 12)
            
            // Action buttons
            VStack(spacing: 0) {
                ActionButton(
                    icon: "square.and.arrow.up",
                    title: "Share",
                    action: onShare
                )
                
                ActionButton(
                    icon: isFavorite ? "heart.fill" : "heart",
                    title: isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    action: onToggleFavorite
                )
                
                ActionButton(
                    icon: isInQuickList ? "minus.square" : "plus.square",
                    title: isInQuickList ? "Remove from Quick List" : "Add to Quick List",
                    action: onToggleQuickList
                )
                
                ActionButton(
                    icon: "mappin.and.ellipse",
                    title: "Add Pin",
                    action: onAddPin
                )
                
                ActionButton(
                    icon: "rectangle.stack",
                    title: "Find Similar",
                    action: onFindSimilar
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34) // Safe area padding
        }
        .background(Color(.systemBackground))
    }
}

struct ActionButton: View {
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