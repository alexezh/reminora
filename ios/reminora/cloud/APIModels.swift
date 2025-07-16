import Foundation
import CoreLocation
import UIKit

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    case serverError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .decodingError:
            return "Failed to decode response"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct APIErrorResponse: Codable {
    let error: String
    let message: String
}

struct SuccessResponse: Codable {
    let success: Bool
}

// MARK: - Account Models

struct Account: Codable, Identifiable {
    let id: String
    let username: String
    let email: String
    let display_name: String
    let bio: String
    let created_at: TimeInterval
    let updated_at: TimeInterval?
}

struct AccountProfile: Codable, Identifiable {
    let id: String
    let username: String
    let display_name: String
    let bio: String
    let created_at: TimeInterval
    let photo_count: Int
    let follower_count: Int
    let following_count: Int
}

struct CreateAccountRequest: Codable {
    let username: String
    let email: String
    let display_name: String?
    let bio: String?
}

struct UpdateAccountRequest: Codable {
    let display_name: String
    let bio: String
}

// MARK: - Photo Models

struct PhotoData: Codable {
    let image_data: String // Base64 encoded image
    let image_format: String
    let created_at: TimeInterval
}

struct Photo: Codable, Identifiable {
    let id: String
    let account_id: String
    let photo_data: PhotoData
    let latitude: Double?
    let longitude: Double?
    let location_name: String?
    let caption: String?
    let created_at: TimeInterval
    let updated_at: TimeInterval
    let username: String
    let display_name: String
    let timeline_created_at: TimeInterval?
    
    // Computed property for CLLocation
    var location: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    // Computed property for UIImage
    var image: UIImage? {
        guard let imageData = Data(base64Encoded: photo_data.image_data) else { return nil }
        return UIImage(data: imageData)
    }
}

struct CreatePhotoRequest: Codable {
    let photo_data: PhotoData
    let latitude: Double?
    let longitude: Double?
    let location_name: String?
    let caption: String?
}

struct TimelineResponse: Codable {
    let photos: [Photo]
    let waterline: String
}

// MARK: - Follow Models

struct Follow: Codable, Identifiable {
    let id: String
    let follower_id: String
    let following_id: String
    let created_at: TimeInterval
    let username: String
    let display_name: String
}

struct FollowRequest: Codable {
    let following_id: String
}

struct UserProfile: Codable, Identifiable {
    let id: String
    let username: String
    let display_name: String
    let created_at: TimeInterval
    let avatar_url: String?
    let handle: String?
}

struct UserSearchResult: Codable, Identifiable {
    let id: String
    let username: String
    let display_name: String
    let bio: String
    let is_following: Int // 0 or 1
    
    var isFollowing: Bool {
        return is_following == 1
    }
}

// MARK: - User Pin Models

struct UserPinAPI: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let latitude: Double
    let longitude: Double
    let image_url: String?
    let created_at: TimeInterval
    let is_public: Bool
}

struct UserPinsResponse: Codable {
    let pins: [UserPinAPI]
    let total: Int
    let has_more: Bool
}

struct FollowResponse: Codable {
    let success: Bool
    let follow_id: String
}

struct EmptyResponse: Codable {
    let success: Bool
}

struct FollowStatusResponse: Codable {
    let isFollowing: Bool
}
