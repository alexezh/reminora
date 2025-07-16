import Foundation

// MARK: - Authentication Models

struct AuthSession: Codable {
    let token: String
    let expires_at: TimeInterval
    
    var isExpired: Bool {
        return Date().timeIntervalSince1970 >= expires_at
    }
}

struct AuthAccount: Codable, Identifiable {
    let id: String
    let username: String
    let email: String
    let display_name: String
    let handle: String?
    let avatar_url: String?
    let needs_handle: Bool?
    
    var needsHandle: Bool {
        return needs_handle == true || handle == nil || handle?.isEmpty == true
    }
}

struct AuthResponse: Codable {
    let account: AuthAccount
    let session: AuthSession
}

struct OAuthCallbackRequest: Codable {
    let provider: String
    let code: String?
    let oauth_id: String
    let email: String
    let name: String?
    let avatar_url: String?
    let access_token: String?
    let refresh_token: String?
    let expires_in: Int?
}

struct CompleteSetupRequest: Codable {
    let handle: String
}

struct HandleCheckResponse: Codable {
    let available: Bool
    let message: String
}

struct RefreshRequest: Codable {
    let refresh_token: String
}

// MARK: - OAuth Provider Configuration

enum OAuthProvider: String, CaseIterable {
    case google = "google"
    case apple = "apple"
    case github = "github"
    case facebook = "facebook"
    
    var displayName: String {
        switch self {
        case .google: return "Google"
        case .apple: return "Apple"
        case .github: return "GitHub"
        case .facebook: return "Facebook"
        }
    }
    
    var iconName: String {
        switch self {
        case .google: return "globe"
        case .apple: return "applelogo"
        case .github: return "laptopcomputer"
        case .facebook: return "person.crop.circle"
        }
    }
}

// MARK: - Authentication State

enum AuthState: Equatable {
    case loading
    case unauthenticated
    case needsHandle(AuthAccount, AuthSession)
    case authenticated(AuthAccount, AuthSession)
    case error(Error)
    
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.unauthenticated, .unauthenticated):
            return true
        case (.needsHandle(let lhsAccount, let lhsSession), .needsHandle(let rhsAccount, let rhsSession)):
            return lhsAccount.id == rhsAccount.id && lhsSession.token == rhsSession.token
        case (.authenticated(let lhsAccount, let lhsSession), .authenticated(let rhsAccount, let rhsSession)):
            return lhsAccount.id == rhsAccount.id && lhsSession.token == rhsSession.token
        case (.error, .error):
            return true // We'll consider all errors as equal for simplicity
        default:
            return false
        }
    }
}

// MARK: - Secure Storage Keys

enum KeychainKey: String {
    case sessionToken = "reminora_session_token"
    case refreshToken = "reminora_refresh_token"
    case accountData = "reminora_account_data"
}