//
//  Clip.swift
//  reminora
//
//  Created by Claude on 8/10/25.
//

import Foundation
import Photos
import SwiftUI
import MediaPlayer
import CoreData

// MARK: - Clip Models

struct Clip: Identifiable, Codable {
    let id: UUID
    var name: String
    var assetIdentifiers: [String]
    var duration: TimeInterval // Duration per image in seconds
    var transition: ClipTransition
    var orientation: ClipOrientation
    var effect: ClipEffect
    var audioTrack: AudioTrack?
    var createdAt: Date
    var modifiedAt: Date
    
    init(name: String, assets: [PHAsset], duration: TimeInterval = 2.0, transition: ClipTransition = .fade, orientation: ClipOrientation = .square, effect: ClipEffect = .none, audioTrack: AudioTrack? = nil) {
        self.id = UUID()
        self.name = name
        self.assetIdentifiers = assets.map { $0.localIdentifier }
        self.duration = duration
        self.transition = transition
        self.orientation = orientation
        self.effect = effect
        self.audioTrack = audioTrack
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    // Get PHAssets from stored identifiers
    func getAssets() -> [RPhotoStack] {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIdentifiers, options: nil)
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets.map{ RPhotoStack(asset: $0) }
    }
    
    // Total video duration
    var totalDuration: TimeInterval {
        return Double(assetIdentifiers.count) * duration
    }
    
    // Update modification date
    mutating func markAsModified() {
        modifiedAt = Date()
    }
}

enum ClipTransition: String, Codable, CaseIterable {
    case none = "none"
    case fade = "fade"
    case slide = "slide"
    case zoom = "zoom"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .fade: return "Fade"
        case .slide: return "Slide"
        case .zoom: return "Zoom"
        }
    }
}

enum ClipOrientation: String, Codable, CaseIterable {
    case portrait = "portrait"
    case landscape = "landscape"
    case square = "square"
    
    var displayName: String {
        switch self {
        case .portrait: return "Portrait"
        case .landscape: return "Landscape"
        case .square: return "Square"
        }
    }
    
    var videoSize: CGSize {
        switch self {
        case .portrait: return CGSize(width: 1080, height: 1920)  // 9:16
        case .landscape: return CGSize(width: 1920, height: 1080) // 16:9
        case .square: return CGSize(width: 1080, height: 1080)    // 1:1
        }
    }
}

enum ClipEffect: String, Codable, CaseIterable {
    case none = "none"
    case blackAndWhite = "blackAndWhite"
    case sepia = "sepia"
    case vintage = "vintage"
    case dramatic = "dramatic"
    case vivid = "vivid"
    case noir = "noir"
    case warm = "warm"
    case cool = "cool"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .blackAndWhite: return "Black & White"
        case .sepia: return "Sepia"
        case .vintage: return "Vintage"
        case .dramatic: return "Dramatic"
        case .vivid: return "Vivid"
        case .noir: return "Noir"
        case .warm: return "Warm"
        case .cool: return "Cool"
        }
    }
    
    var systemImage: String {
        switch self {
        case .none: return "photo"
        case .blackAndWhite: return "camera.filters"
        case .sepia: return "photo.fill"
        case .vintage: return "photo.artframe"
        case .dramatic: return "bolt.circle"
        case .vivid: return "sun.max"
        case .noir: return "moon"
        case .warm: return "flame"
        case .cool: return "snowflake"
        }
    }
}

struct AudioTrack: Identifiable, Codable {
    let id: UUID
    let title: String
    let artist: String
    let assetURL: String? // Persistent ID for MPMediaItem
    let duration: TimeInterval
    let volume: Float // 0.0 to 1.0
    let fadeInDuration: TimeInterval
    let fadeOutDuration: TimeInterval
    
    init(title: String, artist: String, assetURL: String? = nil, duration: TimeInterval, volume: Float = 0.5, fadeInDuration: TimeInterval = 1.0, fadeOutDuration: TimeInterval = 1.0) {
        self.id = UUID()
        self.title = title
        self.artist = artist
        self.assetURL = assetURL
        self.duration = duration
        self.volume = volume
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
    }
    
    var displayName: String {
        return "\(title) - \(artist)"
    }
}

// MARK: - Clip Manager

class ClipManager: ObservableObject {
    static let shared = ClipManager()
        
    // MARK: - Public Interface
    
    func getClip(id: UUID) -> Clip? {
        return clips.first { $0.id == id }
    }
    
    func addClip(_ clip: Clip) {
        // Also create an RList entry for the clip
        createRListEntry(for: clip)
    }
    
    func updateClip(_ clip: Clip) {
        // Also update the RList entry with new JSON data
        updateRListEntry(for: updatedClip)
    }
    
    func deleteClip(id: UUID) {
        // Also delete the RList entry
        deleteRListEntry(for: id)
        
        print("📹 ClipManager: Deleted clip with id \(id)")
    }
    
    private func createRListEntry(for clip: Clip) {
        let context = PersistenceController.shared.container.viewContext
        
        // Create the RList entry
        let rlist = RListData(context: context)
        rlist.id = clip.id.uuidString
        rlist.name = clip.name
        rlist.kind = "clip"
        rlist.createdAt = clip.createdAt
        rlist.modifiedAt = clip.modifiedAt
        
        // Store clip data as JSON
        do {
            let encoder = JSONEncoder()
            let clipData = try encoder.encode(clip)
            rlist.data = String(data: clipData, encoding: .utf8)
        } catch {
            print("❌ ClipManager: Failed to encode clip data: \(error)")
        }
        
        // Create RListItemData entries for each photo
        for (index, assetId) in clip.assetIdentifiers.enumerated() {
            let item = RListItemData(context: context)
            item.id = UUID().uuidString
            item.listId = clip.id.uuidString
            item.placeId = assetId // Using asset ID as place ID for clips
            item.addedAt = Date()
        }
        
        // Save the context
        do {
            try context.save()
            print("📹 ClipManager: Created RList entry for clip '\(clip.name)'")
        } catch {
            print("❌ ClipManager: Failed to save RList entry: \(error)")
        }
    }
    
    private func updateRListEntry(for clip: Clip) {
        let context = PersistenceController.shared.container.viewContext
        
        // Find the existing RList entry
        let fetchRequest: NSFetchRequest<RListData> = RListData.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@ AND kind == %@", clip.id.uuidString, "clip")
        
        do {
            let results = try context.fetch(fetchRequest)
            if let rlist = results.first {
                // Update the JSON data
                let encoder = JSONEncoder()
                let clipData = try encoder.encode(clip)
                rlist.data = String(data: clipData, encoding: .utf8)
                rlist.name = clip.name
                rlist.modifiedAt = clip.modifiedAt
                
                // Save the changes
                try context.save()
                print("📹 ClipManager: Updated RList entry for clip '\(clip.name)'")
            }
        } catch {
            print("❌ ClipManager: Failed to update RList entry: \(error)")
        }
    }
    
    private func deleteRListEntry(for clipId: UUID) {
        let context = PersistenceController.shared.container.viewContext
        
        // Delete RList entry
        let rlistRequest: NSFetchRequest<RListData> = RListData.fetchRequest()
        rlistRequest.predicate = NSPredicate(format: "id == %@ AND kind == %@", clipId.uuidString, "clip")
        
        do {
            let results = try context.fetch(rlistRequest)
            for rlist in results {
                context.delete(rlist)
            }
        } catch {
            print("❌ ClipManager: Failed to fetch RList entry for deletion: \(error)")
        }
        
        // Delete RListItemData entries
        let itemsRequest: NSFetchRequest<RListItemData> = RListItemData.fetchRequest()
        itemsRequest.predicate = NSPredicate(format: "listId == %@", clipId.uuidString)
        
        do {
            let results = try context.fetch(itemsRequest)
            for item in results {
                context.delete(item)
            }
        } catch {
            print("❌ ClipManager: Failed to fetch RListItemData entries for deletion: \(error)")
        }
        
        // Save the context
        do {
            try context.save()
            print("📹 ClipManager: Deleted RList entry for clip \(clipId)")
        } catch {
            print("❌ ClipManager: Failed to save after RList deletion: \(error)")
        }
    }
    
    // MARK: - Utility
    
    func createClipName(from assets: [RPhotoStack]) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        if let firstAsset = assets.first,
           let creationDate = firstAsset.primaryAsset.creationDate {
            return "Clip - \(formatter.string(from: creationDate))"
        } else {
            return "Clip - \(formatter.string(from: Date()))"
        }
    }
}

// MARK: - Environment Integration

private struct ClipManagerKey: EnvironmentKey {
    static let defaultValue = ClipManager.shared
}

extension EnvironmentValues {
    var clipManager: ClipManager {
        get { self[ClipManagerKey.self] }
        set { self[ClipManagerKey.self] = newValue }
    }
}
