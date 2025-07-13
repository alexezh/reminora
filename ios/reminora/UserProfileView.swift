import SwiftUI
import CoreData
import MapKit

struct UserProfileView: View {
    let userId: String
    let userName: String
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var authService = AuthenticationService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var userPins: [UserPin] = []
    @State private var isLoading = true
    @State private var isFollowing = false
    @State private var isCheckingFollowStatus = true
    @State private var selectedPin: UserPin?
    @State private var showingPinDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with user info and follow button
                VStack(spacing: 16) {
                    // User avatar placeholder
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(String(userName.prefix(1)).uppercased())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        )
                    
                    // User name
                    Text("@\(userName)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Stats
                    HStack(spacing: 24) {
                        VStack {
                            Text("\(userPins.count)")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Pins")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("0") // TODO: Get from backend
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Followers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("0") // TODO: Get from backend
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("Following")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Follow button
                    if isCheckingFollowStatus {
                        ProgressView()
                            .frame(height: 36)
                    } else if !isCurrentUser {
                        Button(action: toggleFollow) {
                            HStack {
                                if isFollowing {
                                    Image(systemName: "checkmark")
                                    Text("Following")
                                } else {
                                    Image(systemName: "plus")
                                    Text("Follow")
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isFollowing ? .primary : .white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                            .cornerRadius(20)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Pins list
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading pins...")
                        Spacer()
                    }
                } else if userPins.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No pins shared")
                            .font(.title3)
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        Text("This user hasn't shared any pins yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(userPins, id: \.id) { pin in
                                UserPinCard(pin: pin) {
                                    selectedPin = pin
                                    showingPinDetail = true
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPinDetail) {
            if let pin = selectedPin {
                UserPinDetailView(pin: pin) {
                    showingPinDetail = false
                    selectedPin = nil
                }
            }
        }
        .onAppear {
            loadUserPins()
            checkFollowStatus()
        }
    }
    
    private var isCurrentUser: Bool {
        return userId == authService.currentAccount?.id
    }
    
    private func loadUserPins() {
        Task {
            do {
                print("🔍 Loading pins for user: \(userName) (ID: \(userId))")
                let pins = try await APIService.shared.getUserPins(userId: userId)
                
                await MainActor.run {
                    self.userPins = pins
                    self.isLoading = false
                    print("🔍 ✅ Loaded \(pins.count) pins for user: \(userName)")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("🔍 ❌ Failed to load pins for user \(userName): \(error)")
                }
            }
        }
    }
    
    private func checkFollowStatus() {
        guard let currentUser = authService.currentAccount, !isCurrentUser else {
            isCheckingFollowStatus = false
            return
        }
        
        // Check local Core Data first
        let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let existingFollows = try viewContext.fetch(fetchRequest)
            isFollowing = !existingFollows.isEmpty
            isCheckingFollowStatus = false
            print("🔍 Follow status for \(userName): \(isFollowing)")
        } catch {
            print("🔍 ❌ Failed to check follow status: \(error)")
            isCheckingFollowStatus = false
        }
    }
    
    private func toggleFollow() {
        guard let currentUser = authService.currentAccount else { return }
        
        Task {
            do {
                if isFollowing {
                    // Unfollow
                    try await APIService.shared.unfollowUser(userId: userId)
                    
                    // Remove from local Core Data
                    let fetchRequest: NSFetchRequest<UserList> = UserList.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
                    
                    let existingFollows = try viewContext.fetch(fetchRequest)
                    for follow in existingFollows {
                        viewContext.delete(follow)
                    }
                    try viewContext.save()
                    
                    await MainActor.run {
                        self.isFollowing = false
                        print("🔍 ✅ Unfollowed user: \(userName)")
                    }
                } else {
                    // Follow
                    try await APIService.shared.followUser(userId: userId)
                    
                    // Add to local Core Data
                    let follow = UserList(context: viewContext)
                    follow.id = UUID().uuidString
                    follow.userId = userId
                    follow.name = userName
                    follow.createdAt = Date()
                    
                    try viewContext.save()
                    
                    await MainActor.run {
                        self.isFollowing = true
                        print("🔍 ✅ Followed user: \(userName)")
                    }
                }
            } catch {
                print("🔍 ❌ Failed to toggle follow for \(userName): \(error)")
            }
        }
    }
}

struct UserPinCard: View {
    let pin: UserPin
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Pin image placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pin.name)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    if let description = pin.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(String(format: "%.4f, %.4f", pin.latitude, pin.longitude))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

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

#Preview {
    UserProfileView(userId: "test123", userName: "johndoe")
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}