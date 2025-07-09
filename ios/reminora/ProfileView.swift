import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var cloudSync = CloudSyncService.shared
    @State private var showingFollowers = false
    @State private var showingFollowing = false
    @State private var showingComments = false
    @State private var isSigningOut = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    if case .authenticated(let account, _) = authService.authState {
                        VStack(spacing: 16) {
                            // Avatar
                            AsyncImage(url: URL(string: account.avatar_url ?? "")) { image in
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
                                Text(account.display_name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                if let handle = account.handle {
                                    Text("@\(handle)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Stats Section
                    HStack(spacing: 30) {
                        VStack {
                            Text("0")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Photos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: { showingFollowers = true }) {
                            VStack {
                                Text("0")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Followers")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { showingFollowing = true }) {
                            VStack {
                                Text("0")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Following")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { showingComments = true }) {
                            VStack {
                                Text("0")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("Comments")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    
                    // Sync Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cloud Sync")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack {
                            Image(systemName: cloudSync.isSyncing ? "icloud.and.arrow.up" : "icloud.and.arrow.down")
                                .foregroundColor(cloudSync.isSyncing ? .blue : .green)
                            
                            VStack(alignment: .leading) {
                                Text(cloudSync.isSyncing ? "Syncing..." : "Synced")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if let lastSync = cloudSync.lastSyncTime {
                                    Text("Last sync: \(lastSync, formatter: dateFormatter)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Never synced")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if !cloudSync.isSyncing {
                                Button("Sync Now") {
                                    Task {
                                        await cloudSync.syncToCloud()
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Settings Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Settings")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 1) {
                            SettingsRow(
                                icon: "person.2",
                                title: "Manage Following",
                                action: { showingFollowing = true }
                            )
                            
                            SettingsRow(
                                icon: "bell",
                                title: "Notifications",
                                action: { /* Open notifications settings */ }
                            )
                            
                            SettingsRow(
                                icon: "lock",
                                title: "Privacy",
                                action: { /* Open privacy settings */ }
                            )
                            
                            SettingsRow(
                                icon: "questionmark.circle",
                                title: "Help & Support",
                                action: { /* Open help */ }
                            )
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Sign Out
                    Button(action: signOut) {
                        HStack {
                            if isSigningOut {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.right.square")
                                Text("Sign Out")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSigningOut)
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Profile")
            .refreshable {
                await cloudSync.syncToCloud()
            }
        }
        .sheet(isPresented: $showingFollowers) {
            FollowersView()
        }
        .sheet(isPresented: $showingFollowing) {
            FollowingView()
        }
        .sheet(isPresented: $showingComments) {
            if case .authenticated(let account, _) = authService.authState {
                UserCommentsView(
                    userId: account.id,
                    userName: account.display_name,
                    userHandle: account.handle ?? account.username
                )
            }
        }
    }
    
    private func signOut() {
        isSigningOut = true
        Task {
            await authService.signOut()
            await MainActor.run {
                isSigningOut = false
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.blue)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FollowersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var followers: [UserProfile] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            List(followers) { follower in
                HStack {
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text(follower.display_name)
                            .fontWeight(.medium)
                        Text("@\(follower.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Followers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadFollowers()
            }
            .overlay {
                if isLoading {
                    ProgressView()
                } else if followers.isEmpty {
                    Text("No followers yet")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func loadFollowers() {
        Task {
            do {
                let result = try await APIService.shared.getFollowers()
                await MainActor.run {
                    self.followers = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Failed to load followers: \(error)")
            }
        }
    }
}

struct FollowingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var following: [UserProfile] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            List(following) { user in
                HStack {
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text(user.display_name)
                            .fontWeight(.medium)
                        Text("@\(user.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Unfollow") {
                        unfollowUser(user)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadFollowing()
            }
            .overlay {
                if isLoading {
                    ProgressView()
                } else if following.isEmpty {
                    Text("Not following anyone yet")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func loadFollowing() {
        Task {
            do {
                let result = try await APIService.shared.getFollowing()
                await MainActor.run {
                    self.following = result
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Failed to load following: \(error)")
            }
        }
    }
    
    private func unfollowUser(_ user: UserProfile) {
        Task {
            do {
                try await APIService.shared.unfollowUser(userId: user.id)
                await MainActor.run {
                    following.removeAll { $0.id == user.id }
                }
            } catch {
                print("Failed to unfollow user: \(error)")
            }
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthenticationService.shared)
    }
}