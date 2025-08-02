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
    case addPinFromPhoto(asset: PHAsset)
    case addPinFromLocation(location: LocationInfo)
    case pinDetail(place: PinData, allPlaces: [PinData])
    case userProfile(userId: String, userName: String, userHandle: String)
    case similarPhotos(targetAsset: PHAsset)
    case duplicatePhotos(targetAsset: PHAsset)
    case photoSimilarity(targetAsset: PHAsset)
    case quickList
    case allLists
    case shareSheet(text: String, url: String)
    case searchDialog
    case nearbyPhotos(centerLocation: CLLocationCoordinate2D)
    case nearbyLocations(searchLocation: CLLocationCoordinate2D, locationName: String)
    case selectLocations(initialAddresses: [PlaceAddress], onSave: ([PlaceAddress]) -> Void)
    case comments(targetPhotoId: String)
    case editAddresses(initialAddresses: [PlaceAddress], onSave: ([PlaceAddress]) -> Void)
    case eCardEditor(assets: [PHAsset])
    
    var id: String {
        switch self {
        case .addPinFromPhoto(let asset):
            return "addPinFromPhoto_\(asset.localIdentifier)"
        case .addPinFromLocation(let location):
            return "addPinFromLocation_\(location.name)"
        case .pinDetail(let place, _):
            return "pinDetail_\(place.objectID.uriRepresentation().absoluteString)"
        case .userProfile(let userId, _, _):
            return "userProfile_\(userId)"
        case .similarPhotos(let targetAsset):
            return "similarPhotos_\(targetAsset.localIdentifier)"
        case .duplicatePhotos(let targetAsset):
            return "duplicatePhotos_\(targetAsset.localIdentifier)"
        case .photoSimilarity(let targetAsset):
            return "photoSimilarity_\(targetAsset.localIdentifier)"
        case .quickList:
            return "quickList"
        case .allLists:
            return "allLists"
        case .shareSheet(let text, let url):
            return "shareSheet_\(text.hashValue)_\(url.hashValue)"
        case .searchDialog:
            return "searchDialog"
        case .nearbyPhotos(let centerLocation):
            return "nearbyPhotos_\(centerLocation.latitude)_\(centerLocation.longitude)"
        case .nearbyLocations(let searchLocation, _):
            return "nearbyLocations_\(searchLocation.latitude)_\(searchLocation.longitude)"
        case .selectLocations(_, _):
            return "selectLocations"
        case .comments(let targetPhotoId):
            return "comments_\(targetPhotoId.hashValue)"
        case .editAddresses(_, _):
            return "editAddresses"
        case .eCardEditor(let assets):
            return "eCardEditor_\(assets.map { $0.localIdentifier }.joined(separator: "_"))"
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
        case .addPinFromPhoto, .addPinFromLocation:
            return .fullScreen
        case .pinDetail:
            return .fullScreen
        case .userProfile:
            return .fullScreen
        case .similarPhotos, .duplicatePhotos, .photoSimilarity:
            return .fullScreen
        case .quickList, .allLists:
            return .large
        case .shareSheet:
            return .default
        case .searchDialog:
            return .large
        case .nearbyPhotos, .nearbyLocations:
            return .fullScreen
        case .selectLocations, .editAddresses:
            return .large
        case .comments:
            return .large
        case .eCardEditor:
            return .fullScreen
        }
    }
    
    var allowsBackgroundDismissal: Bool {
        switch self {
        case .addPinFromPhoto, .addPinFromLocation, .editAddresses, .selectLocations:
            return false // Don't allow accidental dismissal for forms
        default:
            return true
        }
    }
}