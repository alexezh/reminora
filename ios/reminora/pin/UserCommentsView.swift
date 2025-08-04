import SwiftUI
import CoreData

struct UserCommentsView: View {
    let userId: String
    let userName: String
    let userHandle: String
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var selectedTab: CommentTab = .received
    @State private var showFollowersOnly = false
    
    enum CommentTab: String, CaseIterable {
        case received = "Received"
        case sent = "Sent"
        
        var icon: String {
            switch self {
            case .received: return "bubble.left"
            case .sent: return "bubble.right"
            }
        }
    }
    
    // Fetch comments received by this user
    @FetchRequest private var receivedComments: FetchedResults<PinComment>
    
    // Fetch comments sent by this user
    @FetchRequest private var sentComments: FetchedResults<PinComment>
    
    init(userId: String, userName: String, userHandle: String) {
        self.userId = userId
        self.userName = userName
        self.userHandle = userHandle
        
        // Comments TO this user
        self._receivedComments = FetchRequest<PinComment>(
            sortDescriptors: [NSSortDescriptor(keyPath: \PinComment.createdAt, ascending: false)],
            predicate: NSPredicate(format: "toUserId == %@", userId),
            animation: .default
        )
        
        // Comments FROM this user
        self._sentComments = FetchRequest<PinComment>(
            sortDescriptors: [NSSortDescriptor(keyPath: \PinComment.createdAt, ascending: false)],
            predicate: NSPredicate(format: "fromUserId == %@", userId),
            animation: .default
        )
    }
    
    private var currentComments: [PinComment] {
        switch selectedTab {
        case .received:
            return Array(receivedComments)
        case .sent:
            return Array(sentComments)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with user info
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text(userInitials)
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(userName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("@\(userHandle)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Close") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Tab selector
                    HStack(spacing: 0) {
                        ForEach(CommentTab.allCases, id: \.self) { tab in
                            Button(action: {
                                selectedTab = tab
                            }) {
                                VStack(spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: tab.icon)
                                        Text(tab.rawValue)
                                        
                                        // Count badge
                                        let count = tab == .received ? receivedComments.count : sentComments.count
                                        if count > 0 {
                                            Text("\(count)")
                                                .font(.caption2)
                                                .foregroundColor(selectedTab == tab ? .white : .blue)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(selectedTab == tab ? Color.blue : Color.blue.opacity(0.2))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                                    
                                    Rectangle()
                                        .fill(selectedTab == tab ? Color.blue : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .background(Color(UIColor.systemBackground))
                
                Divider()
                
                // Comments list
                if currentComments.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: selectedTab.icon)
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 4) {
                            Text("No \(selectedTab.rawValue.lowercased()) comments")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            if selectedTab == .received {
                                Text("Comments from followers will appear here")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Comments you've left will appear here")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(currentComments, id: \.id) { comment in
                                UserCommentCard(comment: comment, isReceivedView: selectedTab == .received)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                }
                
                // Comment input for current user profile
                if selectedTab == .received && isCurrentUser && canReceiveComments {
                    CommentsView(targetUserId: userId)
                        .background(Color(UIColor.systemBackground))
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var userInitials: String {
        let components = userName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return "?"
    }
    
    private var isCurrentUser: Bool {
        authService.currentAccount?.id == userId
    }
    
    private var canReceiveComments: Bool {
        // For now, allow all users to receive comments
        // This could be expanded to check follow status
        true
    }
}

struct UserCommentCard: View {
    let comment: PinComment
    let isReceivedView: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with user info and timestamp
            HStack {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(userInitials)
                            .font(.caption)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("@\(displayHandle)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(timeAgoString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let targetInfo = targetDescription {
                        Text(targetInfo)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            
            // Comment content
            Text((comment.commentText?.isEmpty ?? true) ? "No comment" : comment.commentText!)
                .font(.callout)
                .foregroundColor(.primary)
                .padding(.leading, 44) // Align with user info
            
            // Context info (what photo or user this is about)
            if isReceivedView, let context = contextDescription {
                HStack {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(context)
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .padding(.leading, 44)
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var displayName: String {
        if isReceivedView {
            return (comment.fromUserName?.isEmpty ?? true) ? "Unknown User" : comment.fromUserName!
        } else {
            return (comment.toUserName?.isEmpty ?? true) ? "Unknown User" : comment.toUserName!
        }
    }
    
    private var displayHandle: String {
        if isReceivedView {
            return (comment.fromUserHandle?.isEmpty ?? true) ? "" : comment.fromUserHandle!
        } else {
            return (comment.toUserHandle?.isEmpty ?? true) ? "" : comment.toUserHandle!
        }
    }
    
    private var userInitials: String {
        let name = displayName
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
        
        if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
    
    private var targetDescription: String? {
        if comment.targetPhotoId != nil {
            return "on a photo"
        } else if comment.targetUserId != nil {
            return isReceivedView ? "to you" : "to \(comment.toUserName ?? "someone")"
        }
        return nil
    }
    
    private var contextDescription: String? {
        if let photoId = comment.targetPhotoId {
            return "On photo \(photoId.prefix(8))..."
        } else if let userId = comment.targetUserId {
            return "On profile"
        }
        return nil
    }
}

#Preview {
    UserCommentsView(userId: "user123", userName: "John Doe", userHandle: "johndoe")
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}