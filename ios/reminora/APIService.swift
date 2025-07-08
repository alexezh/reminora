import Foundation
import CoreLocation

/**
 * API Service for communicating with Reminora backend
 */
class APIService: ObservableObject {
    static let shared = APIService()
    
    private let baseURL = "https://reminora-backend.your-worker.workers.dev"
    private let session = URLSession.shared
    
    // For demo purposes, using a simple account ID
    // In production, this would be managed by authentication system
    @Published var currentAccountId: String = "demo-account-123"
    
    private init() {}
    
    // MARK: - Helper Methods
    
    private func createRequest(
        url: URL,
        method: String = "GET",
        body: Data? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(currentAccountId, forHTTPHeaderField: "X-Account-ID")
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    private func performRequest<T: Codable>(
        request: URLRequest,
        responseType: T.Type
    ) async throws -> T {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode >= 400 {
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.serverError(errorData.message)
            } else {
                throw APIError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        do {
            return try JSONDecoder().decode(responseType.self, from: data)
        } catch {
            print("Decode error: \(error)")
            print("Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
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
    
    func uploadPhoto(
        imageData: Data,
        location: CLLocation?,
        caption: String?
    ) async throws -> Photo {
        let url = URL(string: "\(baseURL)/api/photos")!
        
        // Convert image data to base64 for JSON storage
        let base64Image = imageData.base64EncodedString()
        
        let photoData = PhotoData(
            image_data: base64Image,
            image_format: "jpeg",
            created_at: Date().timeIntervalSince1970
        )
        
        let body = CreatePhotoRequest(
            photo_data: photoData,
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            location_name: nil, // Could be filled with reverse geocoding
            caption: caption
        )
        
        let data = try JSONEncoder().encode(body)
        let request = createRequest(url: url, method: "POST", body: data)
        
        return try await performRequest(request: request, responseType: Photo.self)
    }
    
    func getTimeline(since: TimeInterval = 0, limit: Int = 50) async throws -> TimelineResponse {
        var components = URLComponents(string: "\(baseURL)/api/photos/timeline")!
        components.queryItems = [
            URLQueryItem(name: "since", value: String(Int(since))),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        let request = createRequest(url: components.url!)
        return try await performRequest(request: request, responseType: TimelineResponse.self)
    }
    
    func getPhotosByAccount(
        accountId: String,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [Photo] {
        var components = URLComponents(string: "\(baseURL)/api/photos/account/\(accountId)")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        let request = createRequest(url: components.url!)
        return try await performRequest(request: request, responseType: [Photo].self)
    }
    
    func deletePhoto(id: String) async throws {
        let url = URL(string: "\(baseURL)/api/photos/\(id)")!
        let request = createRequest(url: url, method: "DELETE")
        
        _ = try await performRequest(request: request, responseType: SuccessResponse.self)
    }
    
    // MARK: - Follow System
    
    func followUser(userId: String) async throws -> Follow {
        let url = URL(string: "\(baseURL)/api/follows")!
        let body = FollowRequest(following_id: userId)
        
        let data = try JSONEncoder().encode(body)
        let request = createRequest(url: url, method: "POST", body: data)
        
        return try await performRequest(request: request, responseType: Follow.self)
    }
    
    func unfollowUser(userId: String) async throws {
        let url = URL(string: "\(baseURL)/api/follows/\(userId)")!
        let request = createRequest(url: url, method: "DELETE")
        
        _ = try await performRequest(request: request, responseType: SuccessResponse.self)
    }
    
    func getFollowers(
        accountId: String? = nil,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [UserProfile] {
        var components = URLComponents(string: "\(baseURL)/api/follows/followers")!
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
}