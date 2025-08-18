//
//  PhotoViewData.swift
//  reminora
//
//  Created by alexezh on 8/17/25.
//


import CoreData
import MapKit
import Photos
import PhotosUI
import SwiftUI

struct PhotoViewData: Hashable {
    let collection: RPhotoStackCollection
    let photo: RPhotoStack
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(photo.localIdentifier)
    }
    
    static func == (lhs: PhotoViewData, rhs: PhotoViewData) -> Bool {
        lhs.photo.localIdentifier == rhs.photo.localIdentifier
    }
}

struct AddPinFromPhotoData: Hashable {
    let stack: RPhotoStack
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(stack.localIdentifier)
    }
    
    static func == (lhs: AddPinFromPhotoData, rhs: AddPinFromPhotoData) -> Bool {
        lhs.stack.localIdentifier == rhs.stack.localIdentifier
    }
}

struct AddPinFromLocationData: Hashable {
    let location: LocationInfo
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(location.name)
        hasher.combine(location.coordinate.latitude)
        hasher.combine(location.coordinate.longitude)
    }
    
    static func == (lhs: AddPinFromLocationData, rhs: AddPinFromLocationData) -> Bool {
        lhs.location.name == rhs.location.name &&
        lhs.location.coordinate.latitude == rhs.location.coordinate.latitude &&
        lhs.location.coordinate.longitude == rhs.location.coordinate.longitude
    }
}

struct SimilarPhotosData: Hashable {
    let targetAssetIdentifier: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(targetAssetIdentifier)
    }
    
    static func == (lhs: SimilarPhotosData, rhs: SimilarPhotosData) -> Bool {
        lhs.targetAssetIdentifier == rhs.targetAssetIdentifier
    }
}

struct AllListsData: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(0)
    }
    
    static func == (lhs: AllListsData, rhs: AllListsData) -> Bool {
        return true;
    }
}

struct DuplicatePhotosData: Hashable {
    let targetAssetIdentifier: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(targetAssetIdentifier)
    }
    
    static func == (lhs: DuplicatePhotosData, rhs: DuplicatePhotosData) -> Bool {
        lhs.targetAssetIdentifier == rhs.targetAssetIdentifier
    }
}

struct NearbyPhotosData: Hashable {
    let centerLatitude: Double
    let centerLongitude: Double
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(centerLatitude)
        hasher.combine(centerLongitude)
    }
    
    static func == (lhs: NearbyPhotosData, rhs: NearbyPhotosData) -> Bool {
        lhs.centerLatitude == rhs.centerLatitude &&
        lhs.centerLongitude == rhs.centerLongitude
    }
}

struct NearbyLocationsData: Hashable {
    let searchLatitude: Double
    let searchLongitude: Double
    let locationName: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(searchLatitude)
        hasher.combine(searchLongitude)
        hasher.combine(locationName)
    }
    
    static func == (lhs: NearbyLocationsData, rhs: NearbyLocationsData) -> Bool {
        lhs.searchLatitude == rhs.searchLatitude &&
        lhs.searchLongitude == rhs.searchLongitude &&
        lhs.locationName == rhs.locationName
    }
}

struct ECardEditorData: Hashable {
    let stacks: [RPhotoStack]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(0)
    }
    
    static func == (lhs: ECardEditorData, rhs: ECardEditorData) -> Bool {
        return true
    }
}

struct ClipEditorData: Hashable {
    let stacks: [RPhotoStack]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(0)
    }
    
    static func == (lhs: ClipEditorData, rhs: ClipEditorData) -> Bool {
        return true
    }
}

struct QuickListData: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(0)
    }
    
    static func == (lhs: QuickListData, rhs: QuickListData) -> Bool {
        return true;
    }
}
