import CoreData
import SwiftUI

struct UserPin {
    let id: String
    let name: String
    let description: String?
    let latitude: Double
    let longitude: Double
    let imageUrl: String?
    let createdAt: Date
    let isPublic: Bool
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
    @State private var recentPins: [Place] = []
    @State private var recentComments: [Comment] = []
    @State private var showingAllPins = false
    @State private var showingAllComments = false

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

                        // Stats Section
                        HStack(spacing: 30) {
                            VStack {
                                Text("\(recentPins.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Pins")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack {
                                Text("0")  // TODO: Get from API
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Followers")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack {
                                Text("0")  // TODO: Get from API
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Following")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack {
                                Text("\(recentComments.count)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Comments")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()

                        // Recent Pins Section
                        if !recentPins.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Recent Pins")
                                        .font(.headline)

                                    Spacer()

                                    if recentPins.count > 3 {
                                        Button("View All") {
                                            showingAllPins = true
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(Array(recentPins.prefix(5)), id: \.id) { pin in
                                            PinThumbnailView(pin: pin)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }

                        // Recent Comments Section
                        if !recentComments.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Recent Comments")
                                        .font(.headline)

                                    Spacer()

                                    if recentComments.count > 3 {
                                        Button("View All") {
                                            showingAllComments = true
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal)

                                VStack(spacing: 8) {
                                    ForEach(Array(recentComments.prefix(3)), id: \.id) { comment in
                                        CommentPreviewView(comment: comment)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Empty State
                        if recentPins.isEmpty && recentComments.isEmpty && !isLoading {
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
        .sheet(isPresented: $showingAllPins) {
            UserPinsView(userId: userId, userName: userProfile?.display_name ?? userName)
        }
        .sheet(isPresented: $showingAllComments) {
            UserCommentsView(
                userId: userId,
                userName: userProfile?.display_name ?? userName,
                userHandle: userProfile?.handle ?? userHandle ?? ""
            )
        }
    }

    private func loadUserProfile() async {
        isLoading = true

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

            // Load recent pins from local database
            let pinFetchRequest: NSFetchRequest<Place> = Place.fetchRequest()

            // Check if this is the current user's profile
            let isCurrentUser = userId == AuthenticationService.shared.currentAccount?.id

            if isCurrentUser {
                // For current user, show ALL pins (local and shared)
                pinFetchRequest.predicate = nil
            } else {
                // For other users, only show shared pins
                pinFetchRequest.predicate = NSPredicate(format: "cloudId != nil")
            }

            pinFetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]
            pinFetchRequest.fetchLimit = 5

            let pins = try viewContext.fetch(pinFetchRequest)

            // Load recent comments from local database
            let commentFetchRequest: NSFetchRequest<Comment> = Comment.fetchRequest()
            commentFetchRequest.predicate = NSPredicate(format: "fromUserId == %@", userId)
            commentFetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            commentFetchRequest.fetchLimit = 3

            let comments = try viewContext.fetch(commentFetchRequest)

            // Check if currently following this user (skip for current user)
            let following: Bool
            if isCurrentUser {
                following = false
            } else {
                do {
                    following = try await APIService.shared.isFollowing(userId: userId)
                } catch {
                    print("Cannot check follow status, defaulting to not following: \(error)")
                    following = false
                }
            }

            await MainActor.run {
                self.userProfile = profile
                self.recentPins = pins
                self.recentComments = comments
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

    private func toggleFollow() {
        isFollowActionLoading = true

        Task {
            do {
                if isFollowing {
                    try await APIService.shared.unfollowUser(userId: userId)
                } else {
                    try await APIService.shared.followUser(userId: userId)
                }

                await MainActor.run {
                    self.isFollowing.toggle()
                    self.isFollowActionLoading = false
                }
            } catch {
                print("Failed to toggle follow (API unavailable): \(error)")
                await MainActor.run {
                    // In offline mode, just toggle the UI state locally
                    self.isFollowing.toggle()
                    self.isFollowActionLoading = false
                    print("Follow status changed locally (offline mode)")
                }
            }
        }
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
