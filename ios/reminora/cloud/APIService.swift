import Foundation
import CoreLocation

/**
 * API Service for communicating with Reminora backend
 */
class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL = "https://reminora-backend.reminora.workers.dev"
    private let urlSession = URLSession.shared
    
    private var authService: AuthenticationService {
        return AuthenticationService.shared
    }
    
    private init() {}
    
    // MARK: - Helper Methods
    
    private func createRequest(
        url: URL,
        method: String = "GET",
        body: Data? = nil
    ) -> URLRequest? {
        // Get current session token for authentication
        guard case .authenticated(_, let session) = authService.authState else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    private func performRequest<T: Codable>(
        request: URLRequest?,
        responseType: T.Type
    ) async throws -> T {
        guard let request = request else {
            throw APIError.invalidResponse
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode >= 400 {
            // Enhanced debugging for various error codes
            let errorMessage = "HTTP \(httpResponse.statusCode)"
            let url = request.url?.absoluteString ?? "unknown URL"
            
            switch httpResponse.statusCode {
            case 404:
                print("🚨 API 404 Error: \(url)")
                print("📋 Request headers: \(request.allHTTPHeaderFields ?? [:])")
                print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            case 405:
                print("🚨 API 405 Method Not Allowed: \(url)")
                print("🔧 Method used: \(request.httpMethod ?? "unknown")")
                print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            case 401, 403:
                print("🚨 API Authentication Error (\(httpResponse.statusCode)): \(url)")
            case 500...599:
                print("🚨 API Server Error (\(httpResponse.statusCode)): \(url)")
                print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            default:
                print("🚨 API Error (\(httpResponse.statusCode)): \(url)")
            }
            
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(errorData.message)
            } else {
                throw APIError.serverError(errorMessage)
            }
        }
        
        do {
            return try JSONDecoder().decode(responseType.self, from: data)
        } catch {
            print("❌ Decode error for \(responseType): \(error)")
            print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw APIError.decodingError
        }
    }
    
    // MARK: - Account Management
    
    func createAccount(
        username: String,
        email: String,
        displayName: String? = nil,
        bio: String? = nil
    ) async throws -> Account {
        let url = URL(string: "\(baseURL)/api/accounts")!
        let body = CreateAccountRequest(
            username: username,
            email: email,
            display_name: displayName,
            bio: bio
        )
        
        let data = try JSONEncoder().encode(body)
        let request = createRequest(url: url, method: "POST", body: data)
        
        return try await performRequest(request: request, responseType: Account.self)
    }
    
    func getAccount(id: String) async throws -> AccountProfile {
        let url = URL(string: "\(baseURL)/api/accounts/\(id)")!
        let request = createRequest(url: url)
        
        return try await performRequest(request: request, responseType: AccountProfile.self)
    }
    
    func updateAccount(
        id: String,
        displayName: String,
        bio: String
    ) async throws -> Account {
        let url = URL(string: "\(baseURL)/api/accounts/\(id)")!
        let body = UpdateAccountRequest(display_name: displayName, bio: bio)
        
        let data = try JSONEncoder().encode(body)
        let request = createRequest(url: url, method: "PUT", body: data)
        
        return try await performRequest(request: request, responseType: Account.self)
    }
    
    // MARK: - Photo Management
    
    func uploadPin(
        imageData: Data,
        location: CLLocation?,
        caption: String?
    ) async throws -> PinAPI {
        let url = URL(string: "\(baseURL)/api/pins")!
        
        // Convert image data to base64 for JSON storage
        let base64Image = imageData.base64EncodedString()
        
        let photoData = PhotoData(
            image_data: base64Image,
            image_format: "jpeg",
            created_at: Date().timeIntervalSince1970
        )
        
        let body = CreatePinRequest(
            photo_data: photoData,
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            location_name: nil, // Could be filled with reverse geocoding
            caption: caption
        )
        
        let data = try JSONEncoder().encode(body)
        let request = createRequest(url: url, method: "POST", body: data)
        
        return try await performRequest(request: request, responseType: PinAPI.self)
    }
    
    func getTimeline(since: TimeInterval = 0, limit: Int = 50) async throws -> TimelineResponse {
        var components = URLComponents(string: "\(baseURL)/api/pins/timeline")!
        components.queryItems = [
            URLQueryItem(name: "since", value: String(Int(since))),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        let request = createRequest(url: components.url!)
        return try await performRequest(request: request, responseType: TimelineResponse.self)
    }
    
    func getPinsByAccount(
        accountId: String,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [PinAPI] {
        var components = URLComponents(string: "\(baseURL)/api/pins/account/\(accountId)")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        let request = createRequest(url: components.url!)
        return try await performRequest(request: request, responseType: [PinAPI].self)
    }
    
    func deletePin(id: String) async throws {
        let url = URL(string: "\(baseURL)/api/pins/\(id)")!
        let request = createRequest(url: url, method: "DELETE")
        
        _ = try await performRequest(request: request, responseType: SuccessResponse.self)
    }
    
    // MARK: - Follow System
    
    func followUser(userId: String) async throws {
        let url = URL(string: "\(baseURL)/api/follows")!
        let body = FollowRequest(following_id: userId)
        
        let data = try JSONEncoder().encode(body)
        let request = createRequest(url: url, method: "POST", body: data)
        
        let _: FollowResponse = try await performRequest(request: request, responseType: FollowResponse.self)
    }
    
    func unfollowUser(userId: String) async throws {
        let url = URL(string: "\(baseURL)/api/follows/\(userId)")!
        let request = createRequest(url: url, method: "DELETE")
        
        let _: EmptyResponse = try await performRequest(request: request, responseType: EmptyResponse.self)
    }
    
    
    func getFollowing(
        accountId: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [UserProfile] {
        var components = URLComponents(string: "\(baseURL)/api/follows/following")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        if let accountId = accountId {
            queryItems.append(URLQueryItem(name: "account_id", value: accountId))
        }
        
        components.queryItems = queryItems
        let request = createRequest(url: components.url!)
        
        return try await performRequest(request: request, responseType: [UserProfile].self)
    }
    
    func searchUsers(query: String, limit: Int = 20) async throws -> [UserSearchResult] {
        var components = URLComponents(string: "\(baseURL)/api/follows/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        let request = createRequest(url: components.url!)
        return try await performRequest(request: request, responseType: [UserSearchResult].self)
    }
    
    // MARK: - User Pins
    
    func getUserPins(userId: String, limit: Int = 50, offset: Int = 0) async throws -> [PinAPI] {
        var components = URLComponents(string: "\(baseURL)/api/pins/account/\(userId)")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        let request = createRequest(url: components.url!)
        return try await performRequest(request: request, responseType: [PinAPI].self)
    }
    
    // MARK: - User Profile Methods
    
    func getUserProfile(userId: String) async throws -> UserProfile {
        let url = URL(string: "\(baseURL)/api/accounts/\(userId)")!
        let request = createRequest(url: url)
        
        // Get AccountProfile and convert to UserProfile
        let accountProfile = try await performRequest(request: request, responseType: AccountProfile.self)
        
        // Convert AccountProfile to UserProfile format
        return UserProfile(
            id: accountProfile.id,
            username: accountProfile.username,
            display_name: accountProfile.display_name,
            created_at: accountProfile.created_at,
            avatar_url: nil, // AccountProfile doesn't have avatar_url
            handle: accountProfile.username
        )
    }
    
    func isFollowing(userId: String) async throws -> Bool {
        // Check the following list to determine if we're following this user
        let following = try await getFollowing(limit: 100) // Get current user's following list
        return following.contains { $0.id == userId }
    }
    
}
