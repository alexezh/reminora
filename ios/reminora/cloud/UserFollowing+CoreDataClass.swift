//
//  UserFollowing+CoreDataClass.swift
//  reminora
//
//  Created by Claude on 8/16/25.
//

import Foundation
import CoreData

@objc(UserFollowing)
public class UserFollowing: NSManagedObject {
    
    /// Get the display name or fall back to username
    var displayNameOrUsername: String {
        return displayName ?? userName ?? "Unknown User"
    }
    
    /// Check if this following relationship is currently active
    var isCurrentlyActive: Bool {
        return isActive && unfollowedAt == nil
    }
}