//
//  LocationModels.swift
//  reminora
//
//  Created by Claude on 7/24/25.
//

import Foundation
import CoreLocation


struct LocationInfo: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
    let category: String?
    let phoneNumber: String?
    let distance: Double
    let url: URL?
    
    init(id: String, name: String, address: String? = nil, latitude: Double, longitude: Double, category: String? = nil, phoneNumber: String? = nil, distance: Double = 0, url: URL? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.phoneNumber = phoneNumber
        self.distance = distance
        self.url = url
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(address)
    }
    
    static func == (lhs: LocationInfo, rhs: LocationInfo) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.address == rhs.address
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