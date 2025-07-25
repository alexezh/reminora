import CoreData
import SwiftUI
import CoreLocation
import UIKit
import Photos

// In-memory representation of user content for profile display
struct UserContentItem: RListViewItem {
    let id: String
    let date: Date
    let itemType: RListItemType
    let sourceType: UserContentSourceType
}

enum UserContentSourceType {
    case userPin(Place)
    case userComment(UserCommentData)
}

// In-memory comment data structure
struct UserCommentData {
    let id: String
    let text: String
    let createdAt: Date
    let targetInfo: String // Info about what the comment is on
}

struct UserProfileView: View {
    let userId: String
    let userName: String
    let userHandle: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var userProfile: UserProfile?
    @State private var isLoading = true
    @State private var isFollowing = false
    @State private var isFollowActionLoading = false
    @State private var contentItems: [UserContentItem] = []
    @State private var selectedPin: Place?
    @State private var selectedPhotoStack: PhotoStack?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading profile...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Profile Header
                        VStack(spacing: 16) {
                            // Avatar
                            AsyncImage(url: URL(string: userProfile?.avatar_url ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())

                            // Name and Handle
                            VStack(spacing: 4) {
                                Text(userProfile?.display_name ?? userName)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                if let handle = userProfile?.handle ?? userHandle {
                                    Text("@\(handle)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                            // Follow/Unfollow Button (only for other users)
                            if userId != AuthenticationService.shared.currentAccount?.id {
                                Button(action: toggleFollow) {
                                    HStack {
                                        if isFollowActionLoading {
                                            ProgressView()
                                                .progressViewStyle(
                                                    CircularProgressViewStyle(tint: .white)
                                                )
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(
                                                systemName: isFollowing
                                                    ? "person.badge.minus" : "person.badge.plus")
                                            Text(isFollowing ? "Unfollow" : "Follow")
                                        }
                                    }
                                    .frame(width: 120, height: 36)
                                    .background(isFollowing ? Color.gray : Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(18)
                                }
                                .disabled(isFollowActionLoading)
                            }
                        }
                        .padding()

                        // Content Section - Using RListView for pins and comments
                        if !contentItems.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("User Content (\(contentItems.count) items)")
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                
                                RListView(
                                    dataSource: .mixed(contentItems),
                                    onPhotoTap: { asset in
                                        // Handle photo tap if needed
                                    },
                                    onPinTap: { place in
                                        selectedPin = place
                                    },
                                    onPhotoStackTap: { assets in
                                        // Handle photo stack tap if needed
                                    },
                                    onLocationTap: { location in
                                        // Handle location tap if needed
                                    }
                                )
                                .frame(minHeight: 400)
                            }
                        } else if !isLoading {
                            VStack(spacing: 16) {
                                Text("Debug: contentItems is empty")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding()
                            }
                        }


                        // Empty State
                        if contentItems.isEmpty && !isLoading {
                            VStack(spacing: 16) {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)

                                Text("No activity yet")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                Text("This user hasn't shared any pins or comments yet")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle(userProfile?.display_name ?? userName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadUserProfile()
        }
        .refreshable {
            await refreshUserProfile()
        }
        .overlay {
            if let selectedPin = selectedPin {
                PinDetailView(
                    place: selectedPin,
                    allPlaces: [],
                    onBack: {
                        self.selectedPin = nil
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.1).combined(with: .opacity),
                    removal: .scale(scale: 0.1).combined(with: .opacity)
                ))
            }
        }
    }

    private func loadUserProfile() async {
        isLoading = true

        // Check authentication before loading profile
        guard AuthenticationService.shared.currentSession != nil else {
            print("❌ Authentication required to view user profiles")
            await MainActor.run {
                isLoading = false
            }
            return
        }

        do {
            // Try to load user profile from API, but handle failures gracefully
            let profile: UserProfile
            do {
                profile = try await APIService.shared.getUserProfile(userId: userId)
            } catch {
                print("API unavailable, creating offline profile: \(error)")
                // Create a fallback profile for offline mode
                profile = UserProfile(
                    id: userId,
                    username: userHandle ?? "unknown_user",
                    display_name: userHandle ?? "Unknown User",
                    created_at: Date().timeIntervalSince1970,
                    avatar_url: nil,
                    handle: userHandle
                )
            }

            // Check if this is the current user's profile
            let isCurrentUser = userId == AuthenticationService.shared.currentAccount?.id

            // Check if currently following this user (skip for current user)
            let following: Bool
            if isCurrentUser {
                following = false
            } else {
                // First check local follow status
                let localFollowing = await checkLocalFollowStatus()
                
                // Try to sync with API and use local as fallback
                do {
                    let apiFollowing = try await APIService.shared.isFollowing(userId: userId)
                    
                    // If API status differs from local, sync local to match API
                    if apiFollowing != localFollowing {
                        print("🔄 Syncing follow status: API=\(apiFollowing), Local=\(localFollowing)")
                        await persistFollowStatus(apiFollowing)
                        following = apiFollowing
                    } else {
                        following = localFollowing
                    }
                } catch {
                    print("API unavailable for follow status, using local: \(localFollowing)")
                    following = localFollowing
                }
            }

            // Load user content (pins and comments)
            let userContentItems = await loadUserContent()

            await MainActor.run {
                self.userProfile = profile
                self.contentItems = userContentItems
                self.isFollowing = following
                self.isLoading = false
            }
        } catch {
            print("Failed to load user profile: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func refreshUserProfile() async {
        print("🔄 Refreshing user profile for \(userId)")
        await loadUserProfile()
    }

    private func toggleFollow() {
        isFollowActionLoading = true

        Task {
            do {
                if isFollowing {
                    try await APIService.shared.unfollowUser(userId: userId)
                    // Persist unfollow to local storage
                    await persistFollowStatus(false)
                } else {
                    try await APIService.shared.followUser(userId: userId)
                    // Persist follow to local storage
                    await persistFollowStatus(true)
                }

                await MainActor.run {
                    self.isFollowing.toggle()
                    self.isFollowActionLoading = false
                }
            } catch {
                print("Failed to toggle follow (API unavailable): \(error)")
                
                // In offline mode, persist locally and toggle UI state
                let newFollowStatus = !isFollowing
                await persistFollowStatus(newFollowStatus)
                
                await MainActor.run {
                    self.isFollowing = newFollowStatus
                    self.isFollowActionLoading = false
                    print("Follow status changed locally (offline mode): \(newFollowStatus)")
                }
            }
        }
    }
    
    private func persistFollowStatus(_ following: Bool) async {
        await MainActor.run {
            guard let currentUser = AuthenticationService.shared.currentAccount else { return }
            
            let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
            
            do {
                let existingFollows = try viewContext.fetch(fetchRequest)
                
                if following {
                    // Add follow relationship if not exists
                    if existingFollows.isEmpty {
                        let follow = UserList(context: viewContext)
                        follow.id = UUID().uuidString
                        follow.userId = userId
                        follow.name = userName
                        follow.createdAt = Date()
                        print("💾 Created follow relationship for user: \(userName)")
                    }
                } else {
                    // Remove follow relationship
                    for follow in existingFollows {
                        viewContext.delete(follow)
                        print("💾 Removed follow relationship for user: \(userName)")
                    }
                }
                
                try viewContext.save()
                print("💾 Follow status persisted locally: \(following)")
                
            } catch {
                print("❌ Failed to persist follow status: \(error)")
            }
        }
    }
    
    private func checkLocalFollowStatus() async -> Bool {
        return await MainActor.run {
            let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
            
            do {
                let existingFollows = try viewContext.fetch(fetchRequest)
                let isFollowing = !existingFollows.isEmpty
                print("📱 Local follow status for \(userId): \(isFollowing)")
                return isFollowing
            } catch {
                print("❌ Failed to check local follow status: \(error)")
                return false
            }
        }
    }
    
    private func loadUserContent() async -> [UserContentItem] {
        var contentItems: [UserContentItem] = []
        
        // Always try to load from backend first, but also maintain local cache
        do {
            // Use CloudSyncService to fetch and sync user pins
            let photos = try await CloudSyncService.shared.syncUserPins(userId: userId, limit: 50)
            
            for photo in photos {
                // Convert Photo to a Core Data Place for RListView using CloudSyncService
                let place = CloudSyncService.shared.convertPhotoToPlace(photo, context: viewContext)
                
                let contentItem = UserContentItem(
                    id: photo.id,
                    date: Date(timeIntervalSince1970: photo.created_at),
                    itemType: .pin(place),
                    sourceType: .userPin(place)
                )
                contentItems.append(contentItem)
            }
            
        } catch {
            print("❌ Failed to load user pins from cloud: \(error)")
            // Fallback to local data if cloud fails
            await loadLocalUserContent(&contentItems)
        }
        
        // Sort all content by date (most recent first)
        contentItems.sort { $0.date > $1.date }
        
        // Limit to 50 most recent items total
        if contentItems.count > 50 {
            contentItems = Array(contentItems.prefix(50))
        }
        
        print("📋 Loaded \(contentItems.count) total content items for user \(userId)")
        return contentItems
    }
    
    
    private func loadLocalUserContent(_ contentItems: inout [UserContentItem]) async {
        await MainActor.run {
            print("📱 Falling back to local data for user: \(userId)")
            
            // Load user's pins from local Core Data as fallback
            let pinFetchRequest: NSFetchRequest<Place> = Place.fetchRequest()
            
            // Check if this is current user or other user
            let isCurrentUser = userId == AuthenticationService.shared.currentAccount?.id
            
            if isCurrentUser {
                // For current user, show pins where originalUserId is nil (user's own pins) OR originalUserId matches current user
                let currentUserId = AuthenticationService.shared.currentAccount?.id ?? ""
                pinFetchRequest.predicate = NSPredicate(format: "originalUserId == nil OR originalUserId == %@", currentUserId)
            } else {
                // For other users, show pins where originalUserId matches the target user
                pinFetchRequest.predicate = NSPredicate(format: "originalUserId == %@", userId)
            }
            
            pinFetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]
            pinFetchRequest.fetchLimit = 30 // Limit for fallback
            
            do {
                let pins = try viewContext.fetch(pinFetchRequest)
                for pin in pins {
                    let contentItem = UserContentItem(
                        id: pin.objectID.uriRepresentation().absoluteString,
                        date: pin.dateAdded ?? Date(),
                        itemType: .pin(pin),
                        sourceType: .userPin(pin)
                    )
                    contentItems.append(contentItem)
                }
                print("📱 Loaded \(pins.count) local pins as fallback")
            } catch {
                print("❌ Failed to load local pins: \(error)")
            }
            
            // Load user's comments from local Core Data
            let commentFetchRequest: NSFetchRequest<Comment> = Comment.fetchRequest()
            commentFetchRequest.predicate = NSPredicate(format: "fromUserId == %@", userId)
            commentFetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            commentFetchRequest.fetchLimit = 20 // Limit for comments
            
            do {
                let comments = try viewContext.fetch(commentFetchRequest)
                for comment in comments {
                    // Create a virtual place for the comment to display in RListView
                    let virtualPlace = createVirtualPlaceForComment(comment, in: viewContext)
                    
                    let commentData = UserCommentData(
                        id: comment.id ?? UUID().uuidString,
                        text: comment.commentText ?? "",
                        createdAt: comment.createdAt ?? Date(),
                        targetInfo: comment.targetPhotoId != nil ? "on a photo" : "on a profile"
                    )
                    
                    let contentItem = UserContentItem(
                        id: comment.id ?? UUID().uuidString,
                        date: comment.createdAt ?? Date(),
                        itemType: .pin(virtualPlace),
                        sourceType: .userComment(commentData)
                    )
                    contentItems.append(contentItem)
                }
                print("📱 Loaded \(comments.count) local comments as fallback")
            } catch {
                print("❌ Failed to load local comments: \(error)")
            }
        }
    }
    
    
    
    
    // Create a virtual place for comment display in RListView
    private func createVirtualPlaceForComment(_ comment: Comment, in context: NSManagedObjectContext) -> Place {
        // Note: This is an in-memory only object, not saved to Core Data
        let virtualPlace = Place(context: context)
        virtualPlace.post = comment.commentText ?? "Comment"
        virtualPlace.dateAdded = comment.createdAt ?? Date()
        virtualPlace.url = "virtual-comment-\(comment.id ?? UUID().uuidString)"
        virtualPlace.isPrivate = false
        
        // Create a placeholder location if needed
        if let locationData = try? NSKeyedArchiver.archivedData(
            withRootObject: CLLocation(latitude: 0, longitude: 0),
            requiringSecureCoding: false
        ) {
            virtualPlace.setValue(locationData, forKey: "coordinates")
        }
        
        // Create placeholder image data for comments
        virtualPlace.imageData = createCommentPlaceholderImageData()
        
        // Ensure this doesn't get saved to Core Data
        context.refresh(virtualPlace, mergeChanges: false)
        
        return virtualPlace
    }
    
    private func createCommentPlaceholderImageData() -> Data? {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Create a comment-themed placeholder
            UIColor.systemBlue.withAlphaComponent(0.2).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add comment icon
            let iconSize: CGFloat = 80
            let iconRect = CGRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            
            UIColor.systemBlue.setFill()
            let iconPath = UIBezierPath(ovalIn: iconRect)
            iconPath.fill()
            
            // Add text
            let text = "💬"
            let font = UIFont.systemFont(ofSize: 40)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        return image.jpegData(compressionQuality: 0.8)
    }
}

// MARK: - Pin Thumbnail View
struct PinThumbnailView: View {
    let pin: Place

    var body: some View {
        VStack(spacing: 4) {
            // Pin Image
            if let imageData = pin.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "mappin.circle")
                            .font(.title2)
                            .foregroundColor(.gray)
                    )
            }

            // Pin Caption (if any)
            if let post = pin.post, !post.isEmpty {
                Text(post)
                    .font(.caption)
                    .lineLimit(2)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Comment Preview View
struct CommentPreviewView: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.commentText ?? "")
                    .font(.body)
                    .lineLimit(3)

                Spacer()
            }

            if let createdAt = comment.createdAt {
                Text(formatDate(createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - User Pins View
struct UserPinsView: View {
    let userId: String
    let userName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var pins: [Place] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading pins...")
                } else if pins.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)

                        Text("No pins yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 4),
                                GridItem(.flexible(), spacing: 4),
                                GridItem(.flexible(), spacing: 4),
                            ], spacing: 4
                        ) {
                            ForEach(pins, id: \.id) { pin in
                                PinGridItemView(pin: pin)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("\(userName)'s Pins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadPins()
        }
    }

    private func loadPins() async {
        isLoading = true

        let fetchRequest: NSFetchRequest<Place> = Place.fetchRequest()

        // Check if this is the current user's profile
        let isCurrentUser = userId == AuthenticationService.shared.currentAccount?.id

        if isCurrentUser {
            // For current user, show ALL pins (local and shared)
            fetchRequest.predicate = nil
        } else {
            // For other users, only show shared pins
            fetchRequest.predicate = NSPredicate(format: "cloudId != nil")
        }

        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]

        do {
            let loadedPins = try viewContext.fetch(fetchRequest)
            await MainActor.run {
                self.pins = loadedPins
                self.isLoading = false
            }
        } catch {
            print("Failed to load pins: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Pin Grid Item View
struct PinGridItemView: View {
    let pin: Place

    var body: some View {
        if let imageData = pin.imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 110, height: 110)
                .overlay(
                    Image(systemName: "mappin.circle")
                        .font(.title2)
                        .foregroundColor(.gray)
                )
        }
    }
}
