# UserFollowing Entity Setup Instructions

## Background
The UserProfileService has been created and follow management has been moved from UserProfileView and PinMainView to the centralized service. However, the new UserFollowing Core Data entity needs to be manually added to the Core Data model in Xcode.

## Current Status
- ✅ UserProfileService.swift created with centralized follow management
- ✅ UserFollowing+CoreDataClass.swift and UserFollowing+CoreDataProperties.swift created
- ✅ UserProfileView updated to use UserProfileService
- ✅ PinMainView updated to use UserProfileService
- ❗ UserFollowing entity needs to be added to Core Data model in Xcode

## Required Steps

### 1. Add UserFollowing Entity to Core Data Model
1. Open `places.xcdatamodeld` in Xcode
2. Select the latest version (`places 7.xcdatamodel`)
3. Add a new Entity named "UserFollowing"
4. Set the entity properties:
   - **Class**: UserFollowing
   - **Codegen**: Category/Extension (since we already have the class files)

### 2. Add Entity Attributes
Add these attributes to the UserFollowing entity:

| Attribute | Type | Optional | Default | Notes |
|-----------|------|----------|---------|-------|
| id | String | No | - | Primary key |
| userId | String | No | - | ID of followed user |
| userName | String | Yes | - | Username of followed user |
| displayName | String | Yes | - | Display name of followed user |
| followedAt | Date | No | - | When follow relationship was created |
| unfollowedAt | Date | Yes | - | When user was unfollowed (for soft delete) |
| isActive | Boolean | No | YES | Whether follow is currently active |
| syncedAt | Date | Yes | - | Last sync with server |

### 3. Add Fetch Indexes
Add these fetch indexes for performance:

| Index Name | Property | Type | Order |
|------------|----------|------|-------|
| byIdIndex | id | Binary | ascending |
| byUserIdIndex | userId | Binary | ascending |
| byIsActiveIndex | isActive | Binary | ascending |
| byFollowedAtIndex | followedAt | Binary | descending |

### 4. Update Current Model Version
1. In Xcode, select the `places.xcdatamodeld` file
2. In the Data Model Inspector (right panel), set the "Current" model version to the version containing the UserFollowing entity

### 5. Clean and Rebuild
1. Clean the project (Product → Clean Build Folder)
2. Rebuild the project to generate Core Data classes

## Migration Considerations

The current code uses RListData for following relationships with these characteristics:
- `userId` field contains the followed user's ID
- `name` field contains the followed user's name
- `kind` field is set to "user" (default)

After adding UserFollowing entity, you may want to migrate existing follow relationships:

```swift
// Migration code (run once after adding UserFollowing entity)
func migrateFollowsFromRListDataToUserFollowing() {
    let context = PersistenceController.shared.container.viewContext
    
    // Fetch existing follows from RListData
    let fetchRequest: NSFetchRequest<RListData> = RListData.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "userId != nil AND userId != ''")
    
    do {
        let existingFollows = try context.fetch(fetchRequest)
        
        for follow in existingFollows {
            // Create UserFollowing entity
            let userFollow = UserFollowing(context: context)
            userFollow.id = UUID().uuidString
            userFollow.userId = follow.userId
            userFollow.userName = follow.name
            userFollow.followedAt = follow.createdAt
            userFollow.isActive = true
            
            // Delete old RListData entry
            context.delete(follow)
        }
        
        try context.save()
        print("Successfully migrated follows to UserFollowing entity")
    } catch {
        print("Failed to migrate follows: \(error)")
    }
}
```

## Files Updated

### New Files Created:
- `/Users/alexezh/prj/wahi/ios/reminora/cloud/UserProfileService.swift`
- `/Users/alexezh/prj/wahi/ios/reminora/cloud/UserFollowing+CoreDataClass.swift`
- `/Users/alexezh/prj/wahi/ios/reminora/cloud/UserFollowing+CoreDataProperties.swift`

### Files Updated:
- `/Users/alexezh/prj/wahi/ios/reminora/cloud/UserProfileView.swift` - Now uses UserProfileService
- `/Users/alexezh/prj/wahi/ios/reminora/pin/PinMainView.swift` - Now uses UserProfileService

## Benefits of New System

1. **Centralized Management**: All follow operations go through UserProfileService
2. **Dedicated Entity**: UserFollowing entity is specifically designed for follows
3. **Better Performance**: Proper indexes and no overloaded RListData usage
4. **Sync Support**: Built-in sync tracking with `syncedAt` field
5. **Soft Delete**: Support for unfollowing without losing history
6. **Type Safety**: Dedicated entity instead of generic RListData

## Testing

After completing the setup:
1. Test following/unfollowing users in UserProfileView
2. Verify PinMainView syncs pins from followed users
3. Check that follow status persists across app restarts
4. Confirm sync with server works correctly