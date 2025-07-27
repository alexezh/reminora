//
//  LocationModels.swift
//  reminora
//
//  Created by Claude on 7/24/25.
//

import Foundation
import CoreLocation

struct NearbyLocation: Identifiable, Hashable, Codable {
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
    
    // Custom coding to handle CLLocationCoordinate2D and URL
    enum CodingKeys: String, CodingKey {
        case id, name, address, distance, category, phoneNumber, url
        case latitude, longitude
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        distance = try container.decode(Double.self, forKey: .distance)
        category = try container.decode(String.self, forKey: .category)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(address, forKey: .address)
        try container.encode(distance, forKey: .distance)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }
}

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
    
    init(from nearbyLocation: NearbyLocation) {
        self.id = nearbyLocation.id
        self.name = nearbyLocation.name
        self.address = nearbyLocation.address
        self.latitude = nearbyLocation.coordinate.latitude
        self.longitude = nearbyLocation.coordinate.longitude
        self.category = nearbyLocation.category
        self.phoneNumber = nearbyLocation.phoneNumber
        self.distance = nearbyLocation.distance
        self.url = nearbyLocation.url
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