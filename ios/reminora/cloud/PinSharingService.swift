import Foundation
import CoreData
import CoreLocation

struct PinShareResponse: Codable {
    let id: String
    let shareUrl: String
    let cloudId: String
}

struct PinShareRequest: Codable {
    let post: String?
    let latitude: Double
    let longitude: Double
    let imageData: String? // Base64 encoded image
    let url: String?
}

struct UserSubscriptionStatus: Codable {
    let isSubscribed: Bool
    let pinsShared: Int
    let maxFreePins: Int
    let subscriptionType: String?
}

enum PinSharingError: Error, LocalizedError {
    case notAuthenticated
    case subscriptionRequired
    case networkError
    case invalidData
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to share pins"
        case .subscriptionRequired:
            return "Subscription required to share more pins"
        case .networkError:
            return "Network connection error"
        case .invalidData:
            return "Invalid pin data"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

class PinSharingService: ObservableObject {
    static let shared = PinSharingService()
    
    private let baseURL = "https://reminora-backend.reminora.workers.dev"
    private let urlSession = URLSession.shared
    private let authService = AuthenticationService.shared
    
    @Published var isSharing = false
    @Published var subscriptionStatus: UserSubscriptionStatus?
    
    private init() {}
    
    // MARK: - Pin Sharing
    // share pin with external over sms
    func sharePin(_ place: PinData) async throws -> PinShareResponse {
        print("🔗 PinSharingService: Starting to share pin")
        
        // Check authentication first
        guard let session = authService.currentSession else {
            print("❌ PinSharingService: No current session, authentication required")
            throw PinSharingError.notAuthenticated
        }
        
        print("📱 PinSharingService: Session valid, token: \(session.token.prefix(10))...")
        
        // Check subscription status
        try await checkSubscriptionStatus()
        
        guard let status = subscriptionStatus else {
            throw PinSharingError.networkError
        }
        
        // Check if user has exceeded free limit
        if !status.isSubscribed && status.pinsShared >= status.maxFreePins {
            throw PinSharingError.subscriptionRequired
        }
        
        await MainActor.run {
            isSharing = true
        }
        
        defer {
            Task { @MainActor in
                isSharing = false
            }
        }
        
        // Prepare pin data
        guard let pinRequestDict = createPinShareRequest(from: place) else {
            print("❌ PinSharingService: Failed to create pin share request")
            throw PinSharingError.invalidData
        }
        
        let lat = pinRequestDict["latitude"] as? Double ?? 0.0
        let lng = pinRequestDict["longitude"] as? Double ?? 0.0
        print("📍 PinSharingService: Created pin request - lat: \(lat), lng: \(lng)")
        
        // Send to backend
        let url = URL(string: "\(baseURL)/api/pins")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: pinRequestDict)
        
        print("🌐 PinSharingService: Sending POST request to \(url)")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ PinSharingService: Invalid HTTP response")
            throw PinSharingError.networkError
        }
        
        print("📊 PinSharingService: Received response - Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode >= 400 {
            let responseText = String(data: data, encoding: .utf8) ?? "nil"
            print("❌ PinSharingService: Error response (\(httpResponse.statusCode)): \(responseText)")
            
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw PinSharingError.serverError(errorData.error)
            } else {
                throw PinSharingError.serverError("Failed to share pin")
            }
        }
        
        let responseText = String(data: data, encoding: .utf8) ?? "nil"
        print("✅ PinSharingService: Success response: \(responseText)")
        
        // Parse the photo response
        guard let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let photoId = responseDict["id"] as? String else {
            throw PinSharingError.invalidData
        }
        
        // Create share response with photo ID
        let shareResponse = PinShareResponse(
            id: photoId,
            shareUrl: "",
            cloudId: photoId
        )
        
        // Update local place with cloud ID
        await MainActor.run {
            place.cloudId = shareResponse.cloudId
            try? place.managedObjectContext?.save()
        }
        
        print("💾 PinSharingService: Updated place with cloudId: \(shareResponse.cloudId)")
        
        // Note: Pin sharing (via sharePin) adds to shared list, but regular pin upload doesn't
        // This ensures we only add explicitly shared pins to the shared list
        
        // Refresh subscription status
        try await checkSubscriptionStatus()
        
        print("✅ PinSharingService: Pin sharing completed successfully")
        
        return shareResponse
    }
    
    // MARK: - Subscription Status
    
    func checkSubscriptionStatus() async throws {
        guard let session = authService.currentSession else {
            throw PinSharingError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/user/subscription-status")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PinSharingError.networkError
        }
        
        if httpResponse.statusCode >= 400 {
            throw PinSharingError.serverError("Failed to check subscription status")
        }
        
        let status = try JSONDecoder().decode(UserSubscriptionStatus.self, from: data)
        
        await MainActor.run {
            self.subscriptionStatus = status
        }
    }
    
    // MARK: - Authentication Check
    
    func requiresAuthentication() -> Bool {
        return authService.currentSession == nil
    }
    
    func promptForAuthentication() {
        // This will be called when user tries to share for the first time
        // The UI should present authentication options
    }
    
    // MARK: - Shared Pin Analysis
    
    /// Check if a place is shared from another user
    func isSharedFromOtherUser(_ place: PinData, context: NSManagedObjectContext) -> Bool {
        // Check if this place came from a shared link
        guard isSharedItem(place) else { return false }
        
        // Get the shared user info and compare with current user
        if let sharedInfo = getSharedUserInfo(from: place, context: context) {
            let currentUserId = authService.currentAccount?.id ?? ""
            return sharedInfo.userId != currentUserId
        }
        
        // If it's shared but no clear owner info, assume it's from another user
        return true
    }
    
    /// Check if a place is a shared item
    func isSharedItem(_ place: PinData) -> Bool {
        if let url = place.url {
            return url.contains("Shared via Reminora link") || url.contains("Shared by @")
        }
        return false
    }
    
    /// Extract shared user information from a place
    func getSharedUserInfo(from place: PinData, context: NSManagedObjectContext) -> (userId: String, userName: String)? {
        // If not found in RListItemData, try to parse from place URL
        return parseUserInfoFromURL(place.url)
    }
    
    /// Parse user info from URL format "Shared by @username (ID: user-id)"
    private func parseUserInfoFromURL(_ url: String?) -> (userId: String, userName: String)? {
        guard let url = url, url.contains("Shared by @") else { return nil }
        
        let pattern = #"Shared by @([^(]+) \(ID: ([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) else {
            return nil
        }
        
        let usernameRange = Range(match.range(at: 1), in: url)
        let userIdRange = Range(match.range(at: 2), in: url)
        
        guard let usernameRange = usernameRange,
              let userIdRange = userIdRange else { return nil }
        
        let username = String(url[usernameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let userId = String(url[userIdRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 PinSharingService parsed from URL - username: \(username), userId: \(userId)")
        
        // Debug current authentication state
        // if let currentSession = authService.currentSession {
        //     print("📱 Current session exists - token: \(currentSession.token.prefix(10))..., expires: \(currentSession.expires_at)")
        // } else {
        //     print("❌ No current session found")
        // }
        
        return (userId: userId, userName: username)
    }
    
    // MARK: - Private Methods
    
    private func createPinShareRequest(from place: PinData) -> [String: Any]? {
        // Extract location
        guard let locationData = place.value(forKey: "coordinates") as? Data,
              let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation else {
            return nil
        }
        
        // Convert image to base64 if available
        var photoData: [String: Any]?
        if let imageData = place.imageData {
            photoData = [
                "image_data": imageData.base64EncodedString(),
                "image_format": "jpeg",
                "created_at": Date().timeIntervalSince1970
            ]
        }
        
        return [
            "photo_data": photoData as Any,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "location_name": NSNull(),
            "caption": place.post as Any
        ]
    }
}

