import Foundation
import UIKit
import GoogleSignIn

class GoogleSignInHelper {
    static let shared = GoogleSignInHelper()
    
    private init() {}
    
    func signIn() async throws -> GoogleOAuthResult {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                guard let presentingViewController = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first?.windows
                    .first(where: { $0.isKeyWindow })?.rootViewController else {
                    continuation.resume(throwing: GoogleSignInError.noPresentingViewController)
                    return
                }
                
                GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result else {
                    continuation.resume(throwing: GoogleSignInError.cancelled)
                    return
                }
                
                let user = result.user
                let profile = user.profile
                
                let oauthResult = GoogleOAuthResult(
                    oauthId: user.userID ?? "",
                    email: profile?.email ?? "",
                    name: profile?.name,
                    avatarUrl: profile?.imageURL(withDimension: 200)?.absoluteString,
                    accessToken: user.accessToken.tokenString,
                    refreshToken: user.refreshToken.tokenString
                )
                
                continuation.resume(returning: oauthResult)
                }
            }
        }
    }
}

struct GoogleOAuthResult {
    let oauthId: String
    let email: String
    let name: String?
    let avatarUrl: String?
    let accessToken: String?
    let refreshToken: String?
}

enum GoogleSignInError: Error, LocalizedError {
    case notImplemented
    case noPresentingViewController
    case cancelled
    case configurationError
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Google Sign-In not implemented. Please add GoogleSignIn SDK and configure OAuth credentials."
        case .noPresentingViewController:
            return "No presenting view controller available"
        case .cancelled:
            return "Sign-in was cancelled"
        case .configurationError:
            return "Google Sign-In configuration error"
        }
    }
}