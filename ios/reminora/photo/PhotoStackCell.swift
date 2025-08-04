//
//  PhotoStackCell.swift
//  reminora
//
//  Created by alexezh on 8/3/25.
//


import CoreData
import CoreLocation
import MapKit
import Photos
import PhotosUI
import SwiftUI
import UIKit

/// Represents a group of related photos that can be displayed as a stack
struct PhotoStack: Identifiable {
    let id = UUID()
    let assets: [PHAsset]

    var isStack: Bool {
        return assets.count > 1
    }

    var primaryAsset: PHAsset {
        return assets.first!
    }

    var count: Int {
        return assets.count
    }
}

struct PhotoStackCell: View {
    let stack: PhotoStack
    let onTap: () -> Void

    @Environment(\.managedObjectContext) private var viewContext
    @State private var image: UIImage?
    @State private var isInQuickList = false

    private var preferenceManager: PhotoPreferenceManager {
        PhotoPreferenceManager(viewContext: viewContext)
    }

    private var stackHasFavorite: Bool {
        stack.assets.contains { $0.isFavorite }
    }

    private var primaryAssetPreference: PhotoPreferenceType {
        preferenceManager.getPreference(for: stack.primaryAsset)
    }

    private var shouldShowFavoriteIcon: Bool {
        if stack.isStack {
            return stackHasFavorite
        } else {
            return stack.primaryAsset.isFavorite
        }
    }

    private var shouldShowDislikeIcon: Bool {
        !stack.isStack && primaryAssetPreference == .archive
    }

    private var shouldShowQuickListButton: Bool {
        !stack.isStack  // Only show for individual photos, not stacks
    }

    var body: some View {
        ZStack {
            // Background image with tap gesture
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onTapGesture {
                print("PhotoStackCell onTapGesture triggered")
                onTap()
            }

            // Overlay indicators
            VStack {
                HStack {
                    // Favorite indicator (top-left)
                    if shouldShowFavoriteIcon {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 24, height: 24)

                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        .padding(4)
                    }

                    Spacer()

                    // Stack indicator (top-right)
                    if stack.isStack {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 28, height: 28)

                            HStack(spacing: 1) {
                                Image(systemName: "rectangle.stack.fill")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                Text("\(stack.count)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(4)
                    }

                    // Quick List button (top-right for individual photos)
                    if shouldShowQuickListButton {
                        Button(action: {
                            toggleQuickList()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.7))
                                    .frame(width: 24, height: 24)

                                Image(systemName: isInQuickList ? "circle.fill" : "circle")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(4)
                    }
                }

                Spacer()

                // Dislike indicator (bottom-right)
                if shouldShowDislikeIcon {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 24, height: 24)

                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        .padding(4)
                    }
                }
            }
        }
        .onAppear {
            loadThumbnail()
            updateQuickListStatus()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSNotification.Name("RListDatasChanged"))
        ) { _ in
            updateQuickListStatus()
        }
    }

    private func loadThumbnail() {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic

        let targetSize = CGSize(width: 300, height: 300)

        imageManager.requestImage(
            for: stack.primaryAsset, targetSize: targetSize, contentMode: .aspectFill,
            options: options
        ) { loadedImage, _ in
            DispatchQueue.main.async {
                image = loadedImage
            }
        }
    }

    private func updateQuickListStatus() {
        guard shouldShowQuickListButton else { return }

        let userId = AuthenticationService.shared.currentAccount?.id ?? ""
        let newStatus = RListService.shared.isPhotoInQuickList(
            stack.primaryAsset, context: viewContext, userId: userId)

        print(
            "🔍 DEBUG updateQuickListStatus: assetId=\(stack.primaryAsset.localIdentifier), oldStatus=\(isInQuickList), newStatus=\(newStatus)"
        )

        isInQuickList = newStatus
    }

    private func toggleQuickList() {
        guard shouldShowQuickListButton else { return }

        let userId = AuthenticationService.shared.currentAccount?.id ?? ""
        let wasInList = isInQuickList

        print(
            "🔍 DEBUG toggleQuickList: wasInList=\(wasInList), userId=\(userId), assetId=\(stack.primaryAsset.localIdentifier)"
        )

        let success = RListService.shared.togglePhotoInQuickList(
            stack.primaryAsset, context: viewContext, userId: userId)

        print("🔍 DEBUG toggleQuickList: success=\(success)")

        if success {
            isInQuickList = !wasInList
            print("🔍 DEBUG toggleQuickList: Updated state - isInQuickList=\(isInQuickList)")

            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            print(
                "📝 \(wasInList ? "Removed from" : "Added to") Quick List: \(stack.primaryAsset.localIdentifier)"
            )
        } else {
            print("❌ Failed to toggle Quick List status")
        }
    }
}
