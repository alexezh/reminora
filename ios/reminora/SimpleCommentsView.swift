import SwiftUI
import CoreData

struct SimpleCommentsView: View {
    let targetUserId: String?
    let targetPhotoId: String?
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var newCommentText = ""
    @State private var showAllComments = false
    @State private var isLoading = false
    @FocusState private var isCommentFieldFocused: Bool
    
    @FetchRequest private var comments: FetchedResults<Comment>
    
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
        
        self._comments = FetchRequest<Comment>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Comment.createdAt, ascending: true)],
            predicate: predicate,
            animation: .default
        )
    }
    
    private var displayedComments: [Comment] {
        let allComments = Array(comments)
        if showAllComments || allComments.count <= 3 {
            return allComments
        }
        return Array(allComments.prefix(3))
    }
    
    private var hasMoreComments: Bool {
        comments.count > 3 && !showAllComments
    }
    
    private var canComment: Bool {
        authService.currentAccount != nil
    }
    
    private var currentUserInitials: String {
        guard let user = authService.currentAccount else { return "?" }
        let components = user.name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if let first = components.first {
            return String(first.prefix(1))
        }
        return "?"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Comments list (no header, no box)
            if !comments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(displayedComments, id: \.id) { comment in
                        SimpleCommentRowView(comment: comment)
                    }
                    
                    if hasMoreComments {
                        Button("View all \(comments.count) comments") {
                            withAnimation {
                                showAllComments = true
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Comment input (simplified)
            if canComment {
                HStack(spacing: 12) {
                    // User avatar placeholder
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(currentUserInitials)
                                .font(.caption2)
                                .foregroundColor(.blue)
                        )
                    
                    // Comment input field
                    TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                        .lineLimit(1...3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .focused($isCommentFieldFocused)
                    
                    // Send button
                    if !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(action: submitComment) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }
    
    private func submitComment() {
        guard let currentUser = authService.currentAccount,
              !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isLoading = true
        
        let comment = Comment(context: viewContext)
        comment.id = UUID().uuidString
        comment.commentText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        comment.createdAt = Date()
        comment.fromUserId = currentUser.id
        comment.fromUserName = currentUser.name
        comment.fromUserHandle = currentUser.handle
        comment.type = "comment"
        comment.isReaction = false
        
        if let photoId = targetPhotoId {
            comment.targetPhotoId = photoId
        } else if let userId = targetUserId {
            comment.targetUserId = userId
        }
        
        do {
            try viewContext.save()
            newCommentText = ""
            isCommentFieldFocused = false
            
            // TODO: Send to server if needed
            
        } catch {
            print("Failed to save comment: \(error)")
        }
        
        isLoading = false
    }
}

struct SimpleCommentRowView: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // User avatar
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(userInitials)
                        .font(.caption2)
                        .foregroundColor(.gray)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(comment.fromUserName ?? "Unknown")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(comment.createdAt ?? Date(), formatter: commentDateFormatter)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(comment.commentText ?? "")
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var userInitials: String {
        guard let name = comment.fromUserName else { return "?" }
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if let first = components.first {
            return String(first.prefix(1))
        }
        return "?"
    }
}

private let commentDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    SimpleCommentsView(targetPhotoId: "sample-photo-id")
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}