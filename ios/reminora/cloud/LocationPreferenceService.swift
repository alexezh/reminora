//
//  LocationPreferenceService.swift
//  reminora
//
//  Created by Claude on 7/26/25.
//

import Foundation
import CoreData
import UIKit

/**
 * Service to manage location preferences (favorites, dismissed locations, etc.)
 */
class LocationPreferenceService: ObservableObject {
    static let shared = LocationPreferenceService()
    
    private init() {}
    
    // MARK: - Favorite Operations
    
    /**
     * Check if a location is favorited
     */
    func isLocationFavorited(_ location: NearbyLocation, context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<LocationPreference> = LocationPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "locationId == %@ AND isFavorited == true", location.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            return !results.isEmpty
        } catch {
            print("❌ LocationPreferenceService: Error fetching favorite status: \(error)")
            return false
        }
    }
    
    /**
     * Toggle favorite status for a location
     */
    func toggleFavorite(_ location: NearbyLocation, context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<LocationPreference> = LocationPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "locationId == %@", location.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            let preference: LocationPreference
            
            if let existing = results.first {
                preference = existing
            } else {
                preference = createLocationPreference(for: location, context: context)
            }
            
            preference.isFavorited.toggle()
            preference.isRejected = false // Clear reject when favoriting
            preference.updatedAt = Date()
            
            try context.save()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            print("💙 LocationPreferenceService: Toggled favorite for \(location.name): \(preference.isFavorited)")
            return preference.isFavorited
            
        } catch {
            print("❌ LocationPreferenceService: Error toggling favorite: \(error)")
            return false
        }
    }
    
    // MARK: - Dismiss/Reject Operations
    
    /**
     * Check if a location is dismissed/rejected
     */
    func isLocationRejected(_ location: NearbyLocation, context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<LocationPreference> = LocationPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "locationId == %@ AND isRejected == true", location.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            return !results.isEmpty
        } catch {
            print("❌ LocationPreferenceService: Error fetching reject status: \(error)")
            return false
        }
    }
    
    /**
     * Toggle reject/dismiss status for a location
     */
    func toggleReject(_ location: NearbyLocation, context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<LocationPreference> = LocationPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "locationId == %@", location.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            let preference: LocationPreference
            
            if let existing = results.first {
                preference = existing
            } else {
                preference = createLocationPreference(for: location, context: context)
            }
            
            preference.isRejected.toggle()
            preference.isFavorited = false // Clear favorite when rejecting
            preference.updatedAt = Date()
            
            try context.save()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            print("🚫 LocationPreferenceService: Toggled reject for \(location.name): \(preference.isRejected)")
            return preference.isRejected
            
        } catch {
            print("❌ LocationPreferenceService: Error toggling reject: \(error)")
            return false
        }
    }
    
    /**
     * Dismiss a location (same as reject but with different naming for UX)
     */
    func dismissLocation(_ location: NearbyLocation, context: NSManagedObjectContext) -> Bool {
        let result = markLocationAsRejected(location, context: context)
        print("👋 LocationPreferenceService: Dismissed location \(location.name)")
        return result
    }
    
    /**
     * Mark a location as rejected without toggling
     */
    func markLocationAsRejected(_ location: NearbyLocation, context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<LocationPreference> = LocationPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "locationId == %@", location.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            let preference: LocationPreference
            
            if let existing = results.first {
                preference = existing
            } else {
                preference = createLocationPreference(for: location, context: context)
            }
            
            preference.isRejected = true
            preference.isFavorited = false // Clear favorite when rejecting
            preference.updatedAt = Date()
            
            try context.save()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            return true
            
        } catch {
            print("❌ LocationPreferenceService: Error marking location as rejected: \(error)")
            return false
        }
    }
    
    // MARK: - Utility Operations
    
    /**
     * Get all favorited locations
     */
    func getFavoritedLocations(context: NSManagedObjectContext) -> [LocationPreference] {
        let fetchRequest: NSFetchRequest<LocationPreference> = LocationPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isFavorited == true")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("❌ LocationPreferenceService: Error fetching favorited locations: \(error)")
            return []
        }
    }
    
    /**
     * Get all rejected/dismissed locations
     */
    func getRejectedLocations(context: NSManagedObjectContext) -> [LocationPreference] {
        let fetchRequest: NSFetchRequest<LocationPreference> = LocationPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isRejected == true")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("❌ LocationPreferenceService: Error fetching rejected locations: \(error)")
            return []
        }
    }
    
    /**
     * Clear all preferences for a location
     */
    func clearPreferences(for location: NearbyLocation, context: NSManagedObjectContext) -> Bool {
        let fetchRequest: NSFetchRequest<LocationPreference> = LocationPreference.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "locationId == %@", location.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            for preference in results {
                context.delete(preference)
            }
            try context.save()
            
            print("🧹 LocationPreferenceService: Cleared preferences for \(location.name)")
            return true
            
        } catch {
            print("❌ LocationPreferenceService: Error clearing preferences: \(error)")
            return false
        }
    }
    
    // MARK: - Private Helper Methods
    
    /**
     * Create a new LocationPreference entity for a location
     */
    private func createLocationPreference(for location: NearbyLocation, context: NSManagedObjectContext) -> LocationPreference {
        let preference = LocationPreference(context: context)
        preference.locationId = location.id
        preference.locationName = location.name
        preference.locationAddress = location.address
        preference.latitude = location.coordinate.latitude
        preference.longitude = location.coordinate.longitude
        preference.createdAt = Date()
        preference.updatedAt = Date()
        return preference
    }
}