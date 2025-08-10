//
//  Clip.swift
//  reminora
//
//  Created by Claude on 8/10/25.
//

import Foundation
import Photos
import SwiftUI

// MARK: - Clip Models

struct Clip: Identifiable, Codable {
    let id: UUID
    var name: String
    var assetIdentifiers: [String]
    var duration: TimeInterval // Duration per image in seconds
    var transition: ClipTransition
    var createdAt: Date
    var modifiedAt: Date
    
    init(name: String, assets: [PHAsset], duration: TimeInterval = 2.0, transition: ClipTransition = .fade) {
        self.id = UUID()
        self.name = name
        self.assetIdentifiers = assets.map { $0.localIdentifier }
        self.duration = duration
        self.transition = transition
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    // Get PHAssets from stored identifiers
    func getAssets() -> [PHAsset] {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIdentifiers, options: nil)
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
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

// MARK: - Clip Manager

class ClipManager: ObservableObject {
    static let shared = ClipManager()
    
    @Published private var clips: [Clip] = []
    private let userDefaults = UserDefaults.standard
    private let clipsKey = "ClipManager.clips"
    
    private init() {
        loadClips()
    }
    
    // MARK: - Public Interface
    
    func getAllClips() -> [Clip] {
        return clips.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    func getClip(id: UUID) -> Clip? {
        return clips.first { $0.id == id }
    }
    
    func addClip(_ clip: Clip) {
        clips.append(clip)
        saveClips()
        print("📹 ClipManager: Added clip '\(clip.name)' with \(clip.assetIdentifiers.count) images")
    }
    
    func updateClip(_ clip: Clip) {
        if let index = clips.firstIndex(where: { $0.id == clip.id }) {
            var updatedClip = clip
            updatedClip.markAsModified()
            clips[index] = updatedClip
            saveClips()
            print("📹 ClipManager: Updated clip '\(clip.name)'")
        }
    }
    
    func deleteClip(id: UUID) {
        clips.removeAll { $0.id == id }
        saveClips()
        print("📹 ClipManager: Deleted clip with id \(id)")
    }
    
    func deleteClip(_ clip: Clip) {
        deleteClip(id: clip.id)
    }
    
    // MARK: - Persistence
    
    private func saveClips() {
        do {
            let data = try JSONEncoder().encode(clips)
            userDefaults.set(data, forKey: clipsKey)
            print("📹 ClipManager: Saved \(clips.count) clips to preferences")
        } catch {
            print("❌ ClipManager: Failed to save clips: \(error)")
        }
    }
    
    private func loadClips() {
        guard let data = userDefaults.data(forKey: clipsKey) else {
            print("📹 ClipManager: No saved clips found")
            return
        }
        
        do {
            clips = try JSONDecoder().decode([Clip].self, from: data)
            print("📹 ClipManager: Loaded \(clips.count) clips from preferences")
        } catch {
            print("❌ ClipManager: Failed to load clips: \(error)")
            clips = []
        }
    }
    
    // MARK: - Utility
    
    func createClipName(from assets: [PHAsset]) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        if let firstAsset = assets.first,
           let creationDate = firstAsset.creationDate {
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