//
//  UserFollowing+CoreDataProperties.swift
//  reminora
//
//  Created by Claude on 8/16/25.
//

import Foundation
import CoreData

extension UserFollowing {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserFollowing> {
        return NSFetchRequest<UserFollowing>(entityName: "UserFollowing")
    }

    @NSManaged public var id: String?
    @NSManaged public var userId: String?
    @NSManaged public var userName: String?
    @NSManaged public var displayName: String?
    @NSManaged public var followedAt: Date?
    @NSManaged public var unfollowedAt: Date?
    @NSManaged public var isActive: Bool
    @NSManaged public var syncedAt: Date?

}