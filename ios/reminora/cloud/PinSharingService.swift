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
    
    func sharePin(_ place: Place) async throws -> PinShareResponse {
        // Check authentication first
        guard let session = authService.currentSession else {
            throw PinSharingError.notAuthenticated
        }
        
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
        guard let pinRequest = createPinShareRequest(from: place) else {
            throw PinSharingError.invalidData
        }
        
        // Send to backend
        let url = URL(string: "\(baseURL)/api/pins/share")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(pinRequest)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PinSharingError.networkError
        }
        
        if httpResponse.statusCode >= 400 {
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw PinSharingError.serverError(errorData.error)
            } else {
                throw PinSharingError.serverError("Failed to share pin")
            }
        }
        
        let shareResponse = try JSONDecoder().decode(PinShareResponse.self, from: data)
        
        // Update local place with cloud ID
        await MainActor.run {
            place.cloudId = shareResponse.cloudId
            try? place.managedObjectContext?.save()
        }
        
        // Refresh subscription status
        try await checkSubscriptionStatus()
        
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
    
    // MARK: - Private Methods
    
    private func createPinShareRequest(from place: Place) -> PinShareRequest? {
        // Extract location
        guard let locationData = place.value(forKey: "location") as? Data,
              let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(locationData) as? CLLocation else {
            return nil
        }
        
        // Convert image to base64 if available
        var imageDataString: String?
        if let imageData = place.imageData {
            imageDataString = imageData.base64EncodedString()
        }
        
        return PinShareRequest(
            post: place.post,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            imageData: imageDataString,
            url: place.url
        )
    }
}

