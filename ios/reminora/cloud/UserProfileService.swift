//
//  UserProfileService.swift
//  reminora
//
//  Created by Claude on 8/16/25.
//

import Foundation
import CoreData
import SwiftUI

/// Service for managing user profiles and follow relationships
class UserProfileService: ObservableObject {
    static let shared = UserProfileService()
    
    // MARK: - Published Properties
    
    @Published private(set) var isLoading = false
    @Published private(set) var followingUsers: [UserFollowing] = []
    @Published private(set) var lastSyncDate: Date?
    
    // MARK: - Private Properties
    
    private var viewContext: NSManagedObjectContext?
    private let apiService = APIService.shared
    private let authService = AuthenticationService.shared
    
    // MARK: - Initialization
    
    private init() {}
    
    /// Initialize the service with Core Data context
    /// - Parameter viewContext: Core Data managed object context
    func initialize(with viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        loadFollowingFromLocal()
    }
    
    // MARK: - Follow Management
    
    /// Follow a user
    /// - Parameters:
    ///   - userId: ID of the user to follow
    ///   - userName: Name of the user to follow
    ///   - displayName: Display name of the user (optional)
    func followUser(userId: String, userName: String, displayName: String? = nil) async throws {
        guard let viewContext = viewContext else {
            throw UserProfileServiceError.contextNotInitialized
        }
        
        // Check if already following
        if isFollowing(userId: userId) {
            print("🔗 Already following user: \(userName)")
            return
        }
        
        // Follow on server
        try await apiService.followUser(userId: userId)
        
        // Persist locally
        do {
            try await MainActor.run {
                let follow = UserFollowing(context: viewContext)
                follow.id = UUID().uuidString
                follow.userId = userId
                follow.userName = userName
                follow.displayName = displayName ?? userName
                follow.followedAt = Date()
                follow.isActive = true
                
                try viewContext.save()
                loadFollowingFromLocal()
                print("✅ Successfully followed user: \(userName)")
            }
        } catch {
            print("❌ Failed to save follow relationship: \(error)")
            throw UserProfileServiceError.saveError(error)
        }
    }
    
    /// Unfollow a user
    /// - Parameter userId: ID of the user to unfollow
    func unfollowUser(userId: String) async throws {
        guard let viewContext = viewContext else {
            throw UserProfileServiceError.contextNotInitialized
        }
        
        // Unfollow on server
        try await apiService.unfollowUser(userId: userId)
        
        // Remove locally
        do {
            try await MainActor.run {
                let fetchRequest: NSFetchRequest<UserFollowing> = UserFollowing.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "userId == %@ AND isActive == YES", userId)
                
                let existing = try viewContext.fetch(fetchRequest)
                for follow in existing {
                    follow.isActive = false // Soft delete
                    follow.unfollowedAt = Date()
                }
                try viewContext.save()
                loadFollowingFromLocal()
                print("✅ Successfully unfollowed user: \(userId)")
            }
        } catch {
            print("❌ Failed to remove follow relationship: \(error)")
            throw UserProfileServiceError.saveError(error)
        }
    }
    
    /// Check if currently following a user
    /// - Parameter userId: ID of the user to check
    /// - Returns: True if following, false otherwise
    func isFollowing(userId: String) -> Bool {
        return followingUsers.contains { $0.userId == userId && $0.isActive }
    }
    
    /// Get all users being followed
    /// - Returns: Array of UserFollowing entities
    func getFollowingUsers() -> [UserFollowing] {
        return followingUsers.filter { $0.isActive }
    }
    
    /// Sync following list from server
    func syncFollowingFromServer() async throws {
        guard let viewContext = viewContext else {
            throw UserProfileServiceError.contextNotInitialized
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get following list from server
            let serverFollowing = try await apiService.getFollowing()
            
            await MainActor.run {
                // Update local storage with server data
                updateLocalFollowing(with: serverFollowing, context: viewContext)
                lastSyncDate = Date()
                print("✅ Successfully synced following list from server")
            }
        } catch {
            print("❌ Failed to sync following list: \(error)")
            throw error
        }
    }
    
    /// Check if sync is needed (based on time since last sync)
    func shouldPerformSync() -> Bool {
        guard let lastSync = lastSyncDate else { return true }
        return Date().timeIntervalSince(lastSync) > 300 // 5 minutes
    }
    
    /// Perform sync if needed
    func syncIfNeeded() async {
        guard shouldPerformSync() else { return }
        
        do {
            try await syncFollowingFromServer()
        } catch {
            print("❌ Background sync failed: \(error)")
            // Don't throw - this is a background operation
        }
    }
    
    // MARK: - Private Methods
    
    private func loadFollowingFromLocal() {
        guard let viewContext = viewContext else { return }
        
        let fetchRequest: NSFetchRequest<UserFollowing> = UserFollowing.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "followedAt", ascending: false)]
        
        do {
            followingUsers = try viewContext.fetch(fetchRequest)
            print("📱 Loaded \(followingUsers.count) following relationships from local storage")
        } catch {
            print("❌ Failed to load following relationships: \(error)")
            followingUsers = []
        }
    }
    
    private func updateLocalFollowing(with serverUsers: [UserProfile], context: NSManagedObjectContext) {
        // Get current local following
        let fetchRequest: NSFetchRequest<UserFollowing> = UserFollowing.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            let localFollowing = try context.fetch(fetchRequest)
            let localUserIds = Set(localFollowing.map { $0.userId ?? "" })
            let serverUserIds = Set(serverUsers.map { $0.id })
            
            // Add new follows from server
            for serverUser in serverUsers {
                if !localUserIds.contains(serverUser.id) {
                    let follow = UserFollowing(context: context)
                    follow.id = UUID().uuidString
                    follow.userId = serverUser.id
                    follow.userName = serverUser.username
                    follow.displayName = serverUser.display_name
                    follow.followedAt = Date()
                    follow.isActive = true
                }
            }
            
            // Mark unfollowed users as inactive
            for localFollow in localFollowing {
                if let userId = localFollow.userId, !serverUserIds.contains(userId) {
                    localFollow.isActive = false
                    localFollow.unfollowedAt = Date()
                }
            }
            
            try context.save()
            loadFollowingFromLocal()
        } catch {
            print("❌ Failed to update local following: \(error)")
        }
    }
}

// MARK: - Error Types

enum UserProfileServiceError: Error {
    case contextNotInitialized
    case saveError(Error)
    case networkError(Error)
    
    var localizedDescription: String {
        switch self {
        case .contextNotInitialized:
            return "Core Data context not initialized"
        case .saveError(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
