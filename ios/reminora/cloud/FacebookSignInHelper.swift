import Foundation
import FacebookLogin
import FacebookCore

struct FacebookSignInResult {
    let oauthId: String
    let email: String
    let name: String?
    let avatarUrl: String?
    let accessToken: String
}

class FacebookSignInHelper: NSObject, ObservableObject {
    static let shared = FacebookSignInHelper()
    
    private static var isFacebookSDKInitialized = false
    
    private override init() {
        super.init()
    }
    
    private func initializeFacebookSDKIfNeeded() {
        guard !Self.isFacebookSDKInitialized else { return }
        
        // Load Facebook configuration
        guard let path = Bundle.main.path(forResource: "Facebook-Info", ofType: "plist"),
              let facebookPlist = NSDictionary(contentsOfFile: path),
              let appID = facebookPlist["FacebookAppID"] as? String,
              let clientToken = facebookPlist["FacebookClientToken"] as? String else {
            print("❌ Facebook-Info.plist not found or missing required keys")
            return
        }
        
        // Check if Facebook is disabled
        if appID == "DISABLED" || clientToken == "DISABLED" {
            print("ℹ️ Facebook SDK is disabled in configuration")
            return
        }
        
        // Set Facebook settings
        Settings.shared.appID = appID
        Settings.shared.clientToken = clientToken
        Settings.shared.displayName = facebookPlist["FacebookDisplayName"] as? String ?? "Reminora"
        
        // Initialize Facebook SDK ApplicationDelegate
        ApplicationDelegate.shared.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )
        
        Self.isFacebookSDKInitialized = true
        print("✅ Facebook SDK initialized lazily with App ID: \(appID)")
    }
    
    func signIn() async throws -> FacebookSignInResult {
        // Initialize Facebook SDK lazily when actually needed
        initializeFacebookSDKIfNeeded()
        
        // Check if Facebook is configured
        guard let appID = Settings.shared.appID, 
              !appID.isEmpty, 
              appID != "DISABLED" else {
            throw NSError(domain: "FacebookSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Facebook SDK is not configured or disabled"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first else {
                    continuation.resume(throwing: NSError(domain: "FacebookSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find window"]))
                    return
                }
                
                let loginManager = LoginManager()
                loginManager.logIn(permissions: ["public_profile", "email"], from: window.rootViewController) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let result = result, !result.isCancelled else {
                        continuation.resume(throwing: NSError(domain: "FacebookSignIn", code: -2, userInfo: [NSLocalizedDescriptionKey: "Login was cancelled"]))
                        return
                    }
                    
                    guard let accessToken = result.token else {
                        continuation.resume(throwing: NSError(domain: "FacebookSignIn", code: -2, userInfo: [NSLocalizedDescriptionKey: "No access token received"]))
                        return
                    }
                    
                    // Get user information
                    self.fetchUserInfo(accessToken: accessToken) { userResult in
                        switch userResult {
                        case .success(let signInResult):
                            continuation.resume(returning: signInResult)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }
    
    private func fetchUserInfo(accessToken: AccessToken, completion: @escaping (Result<FacebookSignInResult, Error>) -> Void) {
        let request = GraphRequest(graphPath: "me", parameters: ["fields": "id,name,email,picture.type(large)"])
        
        request.start { _, result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let result = result as? [String: Any],
                  let id = result["id"] as? String else {
                completion(.failure(NSError(domain: "FacebookSignIn", code: -4, userInfo: [NSLocalizedDescriptionKey: "Could not parse user data"])))
                return
            }
            
            let name = result["name"] as? String
            let email = result["email"] as? String ?? ""
            
            // Get profile picture URL
            var avatarUrl: String?
            if let picture = result["picture"] as? [String: Any],
               let data = picture["data"] as? [String: Any],
               let url = data["url"] as? String {
                avatarUrl = url
            }
            
            let signInResult = FacebookSignInResult(
                oauthId: id,
                email: email,
                name: name,
                avatarUrl: avatarUrl,
                accessToken: accessToken.tokenString
            )
            
            completion(.success(signInResult))
        }
    }
    
    func signOut() {
        LoginManager().logOut()
    }
    
    var isLoggedIn: Bool {
        return AccessToken.current != nil
    }
}