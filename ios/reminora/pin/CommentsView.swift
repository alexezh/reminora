import SwiftUI
import CoreData

struct CommentsView: View {
    let targetUserId: String?
    let targetPhotoId: String?
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var newCommentText = ""
    @State private var showAllComments = false
    @State private var isLoading = false
    @State private var showingAuthentication = false
    @FocusState private var isCommentFieldFocused: Bool
    
    @FetchRequest private var comments: FetchedResults<PinComment>
    
    init(targetUserId: String? = nil, targetPhotoId: String? = nil) {
        self.targetUserId = targetUserId
        self.targetPhotoId = targetPhotoId
        
        // Create predicate based on target type
        var predicate: NSPredicate
        if let photoId = targetPhotoId {
            predicate = NSPredicate(format: "targetPhotoId == %@", photoId)
        } else if let userId = targetUserId {
            predicate = NSPredicate(format: "targetUserId == %@", userId)
        } else {
            predicate = NSPredicate(value: false) // No results if no target
        }
        
        self._comments = FetchRequest<PinComment>(
            sortDescriptors: [NSSortDescriptor(keyPath: \PinComment.createdAt, ascending: true)],
            predicate: predicate,
            animation: .default
        )
    }
    
    private var displayedComments: [PinComment] {
        let allComments = Array(comments)
        if showAllComments || allComments.count <= 5 {
            return allComments
        }
        return Array(allComments.prefix(5))
    }
    
    private var hasMoreComments: Bool {
        comments.count > 5 && !showAllComments
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Comments")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if comments.count > 0 {
                    Text("\(comments.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            
            // Comments list
            if comments.isEmpty {
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading comments...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                } else if canComment {
                    Text("Be the first to leave a comment!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                } else {
                    Text("No comments yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(displayedComments, id: \.id) { comment in
                        CommentRowView(comment: comment)
                    }
                    
                    if hasMoreComments {
                        Button("Show more comments") {
                            withAnimation {
                                showAllComments = true
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Comment input
            if canComment {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    HStack(spacing: 12) {
                        // User avatar placeholder
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(currentUserInitials)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            )
                        
                        // Comment input field
                        TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                            .lineLimit(1...4)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .focused($isCommentFieldFocused)
                        
                        // Send button
                        if !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: submitComment) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            .disabled(isLoading)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
        .onAppear {
            loadComments()
        }
        .sheet(isPresented: $showingAuthentication) {
            AuthenticationView()
        }
    }
    
    // MARK: - Computed Properties
    
    private var canComment: Bool {
        // Must be authenticated to comment
        guard let currentUser = authService.currentAccount,
              authService.currentSession != nil else { 
            return false 
        }
        
        // Can always comment on photos if authenticated
        if targetPhotoId != nil {
            return true
        }
        
        // Can comment on users you follow (this would need to be implemented)
        // For now, allow commenting on any user if authenticated
        if targetUserId != nil {
            return true
        }
        
        return false
    }
    
    private var currentUserInitials: String {
        guard let user = authService.currentAccount else { return "?" }
        let name = user.display_name
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return "?"
    }
    
    // MARK: - Actions
    
    private func loadComments() {
        // Comments are automatically loaded via @FetchRequest
        // This could be extended to sync with cloud if needed
    }
    
    private func submitComment() {
        // Check authentication first and trigger login if needed
        guard let currentUser = authService.currentAccount else {
            print("❌ No account found - authentication required")
            showingAuthentication = true
            return
        }
        
        guard authService.currentSession != nil else {
            print("❌ No session found - authentication required")
            showingAuthentication = true
            return
        }
        
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ Comment text is empty")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Create local comment
                await MainActor.run {
                    let comment = PinComment(context: viewContext)
                    comment.id = UUID().uuidString
                    comment.fromUserId = currentUser.id
                    comment.fromUserName = currentUser.display_name
                    comment.fromUserHandle = currentUser.handle ?? currentUser.username
                    comment.commentText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    comment.type = "comment"
                    comment.isReaction = false
                    comment.createdAt = Date()
                    
                    if let photoId = targetPhotoId {
                        comment.targetPhotoId = photoId
                    }
                    
                    if let userId = targetUserId {
                        comment.targetUserId = userId
                        // Also populate target user info if available
                        comment.toUserId = userId
                    }
                    
                    do {
                        try viewContext.save()
                        newCommentText = ""
                        isCommentFieldFocused = false
                        
                        // TODO: Sync to cloud backend
                        // await syncCommentToCloud(comment)
                        
                    } catch {
                        print("Failed to save comment: \(error)")
                    }
                    
                    isLoading = false
                }
            }
        }
    }
}

struct CommentRowView: View {
    let comment: PinComment
    @State private var showingUserProfile = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User avatar - clickable
            Button(action: {
                showingUserProfile = true
            }) {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(userInitials)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                // User name and handle
                HStack {
                    Text((comment.fromUserName?.isEmpty ?? true) ? "Unknown User" : comment.fromUserName!)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let handle = comment.fromUserHandle, !handle.isEmpty && handle != "unknown" {
                        Text("@\(handle)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(timeAgoString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Comment text
                Text((comment.commentText?.isEmpty ?? true) ? "No comment" : comment.commentText!)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Reaction indicators
                if comment.isReaction {
                    HStack(spacing: 4) {
                        Image(systemName: reactionIcon)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(reactionText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .sheet(isPresented: $showingUserProfile) {
            if let userId = comment.fromUserId {
                UserProfileView(
                    userId: userId,
                    userName: comment.fromUserName ?? "Unknown User",
                    userHandle: comment.fromUserHandle
                )
            }
        }
    }
    
    private var userInitials: String {
        let name = (comment.fromUserName?.isEmpty ?? true) ? "Unknown User" : comment.fromUserName!
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return "?"
    }
    
    private var timeAgoString: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(comment.createdAt ?? Date())
        
        if timeInterval < 60 {
            return "now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        }
    }
    
    private var reactionIcon: String {
        switch comment.type ?? "comment" {
        case "like":
            return "heart.fill"
        case "reaction":
            return "face.smiling"
        default:
            return "bubble.left"
        }
    }
    
    private var reactionText: String {
        switch comment.type ?? "comment" {
        case "like":
            return "liked this"
        case "reaction":
            return "reacted"
        default:
            return ""
        }
    }
}

#Preview {
    CommentsView(targetUserId: "user123")
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
