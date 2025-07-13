import Foundation
import CoreData
import Photos

// Core Data will auto-generate PhotoPreference class

// Helper class for managing photo preferences
class PhotoPreferenceManager {
    private let viewContext: NSManagedObjectContext
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    func setPreference(for asset: PHAsset, preference: PhotoPreferenceType) {
        let fetchRequest: NSFetchRequest<PhotoPreference> = PhotoPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "photoId == %@", asset.localIdentifier)
        
        do {
            let existing = try viewContext.fetch(fetchRequest)
            let photoPreference: PhotoPreference
            
            if let existingPreference = existing.first {
                photoPreference = existingPreference
            } else {
                photoPreference = PhotoPreference(context: viewContext)
                photoPreference.photoId = asset.localIdentifier
            }
            
            photoPreference.preference = preference.rawValue
            photoPreference.dateModified = Date()
            
            try viewContext.save()
        } catch {
            print("Failed to save photo preference: \(error)")
        }
    }
    
    func getPreference(for asset: PHAsset) -> PhotoPreferenceType {
        let fetchRequest: NSFetchRequest<PhotoPreference> = PhotoPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "photoId == %@", asset.localIdentifier)
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            if let preference = results.first, let preferenceValue = preference.preference {
                return PhotoPreferenceType(rawValue: preferenceValue) ?? .neutral
            }
        } catch {
            print("Failed to fetch photo preference: \(error)")
        }
        
        return .neutral
    }
    
    func getFilteredAssets(from assets: [PHAsset], filter: PhotoFilterType) -> [PHAsset] {
        switch filter {
        case .all:
            return assets
        case .favorites:
            return assets.filter { getPreference(for: $0) == .like }
        case .dislikes:
            return assets.filter { getPreference(for: $0) == .dislike }
        case .neutral:
            return assets.filter { getPreference(for: $0) == .neutral }
        case .notDisliked:
            return assets.filter { getPreference(for: $0) != .dislike }
        }
    }
}

enum PhotoPreferenceType: String, CaseIterable {
    case like = "like"
    case dislike = "dislike"
    case neutral = "neutral"
}

enum PhotoFilterType: String, CaseIterable {
    case all = "all"
    case favorites = "favorites"
    case dislikes = "dislikes"
    case neutral = "neutral"
    case notDisliked = "notDisliked"
    
    var displayName: String {
        switch self {
        case .all:
            return "All Photos"
        case .favorites:
            return "Favorites"
        case .dislikes:
            return "Disliked"
        case .neutral:
            return "Neutral"
        case .notDisliked:
            return "Photos"
        }
    }
    
    var iconName: String {
        switch self {
        case .all:
            return "photo.stack"
        case .favorites:
            return "heart.fill"
        case .dislikes:
            return "hand.thumbsdown.fill"
        case .neutral:
            return "minus.circle"
        case .notDisliked:
            return "photo"
        }
    }
}