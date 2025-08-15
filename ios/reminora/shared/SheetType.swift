//
//  SheetType.swift
//  reminora
//
//  Created by Claude on 8/2/25.
//

import Foundation
import Photos
import SwiftUI

// MARK: - Sheet Type Definitions
enum SheetType: Identifiable, Equatable {
    case pinDetail(place: PinData, allPlaces: [PinData])
    case userProfile(userId: String, userName: String, userHandle: String)
    case shareSheet(text: String, url: String)
    case searchDialog
    case selectLocations(initialAddresses: [PlaceAddress], onSave: ([PlaceAddress]) -> Void)
    case comments(targetPhotoId: String)
    case editAddresses(initialAddresses: [PlaceAddress], onSave: ([PlaceAddress]) -> Void)

    var id: String {
        switch self {
        case .pinDetail(let place, _):
            return "pinDetail_\(place.objectID.uriRepresentation().absoluteString)"
        case .userProfile(let userId, _, _):
            return "userProfile_\(userId)"
        case .shareSheet(let text, let url):
            return "shareSheet_\(text.hashValue)_\(url.hashValue)"
        case .searchDialog:
            return "searchDialog"
        case .selectLocations(_, _):
            return "selectLocations"
        case .comments(let targetPhotoId):
            return "comments_\(targetPhotoId.hashValue)"
        case .editAddresses(_, _):
            return "editAddresses"
        }
    }

    static func == (lhs: SheetType, rhs: SheetType) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Sheet Configuration
struct SheetConfiguration {
    let presentationDetents: [PresentationDetent]
    let dismissible: Bool
    let backgroundInteraction: Bool

    static let `default` = SheetConfiguration(
        presentationDetents: [.medium, .large],
        dismissible: true,
        backgroundInteraction: false
    )

    static let fullScreen = SheetConfiguration(
        presentationDetents: [.large],
        dismissible: true,
        backgroundInteraction: false
    )

    static let compact = SheetConfiguration(
        presentationDetents: [.height(400), .medium],
        dismissible: true,
        backgroundInteraction: false
    )

    static let large = SheetConfiguration(
        presentationDetents: [.medium, .large],
        dismissible: true,
        backgroundInteraction: false
    )
}

// MARK: - Sheet Type Extensions
extension SheetType {
    var configuration: SheetConfiguration {
        switch self {
        case .pinDetail:
            return .fullScreen
        case .userProfile:
            return .fullScreen
        case .shareSheet:
            return .default
        case .searchDialog:
            return .large
        case .selectLocations, .editAddresses:
            return .large
        case .comments:
            return .large
        }
    }

    var allowsBackgroundDismissal: Bool {
        switch self {
        case .editAddresses, .selectLocations:
            return false  // Don't allow accidental dismissal for forms
        default:
            return true
        }
    }
}
