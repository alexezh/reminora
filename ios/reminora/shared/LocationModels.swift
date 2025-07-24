//
//  LocationModels.swift
//  reminora
//
//  Created by Claude on 7/24/25.
//

import Foundation
import CoreLocation

struct NearbyLocation: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let distance: Double
    let category: String
    let phoneNumber: String?
    let url: URL?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(address)
    }
    
    static func == (lhs: NearbyLocation, rhs: NearbyLocation) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.address == rhs.address
    }
}

struct LocationInfo: Codable, Identifiable {
    let id: String
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    let category: String?
    
    init(from nearbyLocation: NearbyLocation) {
        self.id = nearbyLocation.id
        self.name = nearbyLocation.name
        self.address = nearbyLocation.address
        self.latitude = nearbyLocation.coordinate.latitude
        self.longitude = nearbyLocation.coordinate.longitude
        self.category = nearbyLocation.category
    }
}

// Make CLLocationCoordinate2D hashable for our use case
extension CLLocationCoordinate2D: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
    
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}