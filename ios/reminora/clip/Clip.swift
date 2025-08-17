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
    
    init(name: String, assets: [RPhotoStack], duration: TimeInterval = 2.0, transition: ClipTransition = .fade, orientation: ClipOrientation = .square, effect: ClipEffect = .none, audioTrack: AudioTrack? = nil) {
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

