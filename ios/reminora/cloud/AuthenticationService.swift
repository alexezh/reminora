import Foundation
import Security
import AuthenticationServices

/**
 * Authentication service handling OAuth flows and session management
 */
class AuthenticationService: NSObject, ObservableObject {
    static let shared = AuthenticationService()
    
    private let baseURL = "https://reminora-backend.reminora.workers.dev"
    private let urlSession = URLSession.shared
    
    @Published var authState: AuthState = .loading
    @Published var isLoading = false
    
    var currentSession: AuthSession?
    var currentAccount: AuthAccount?
    
    override init() {
        super.init()
        loadStoredAuth()
    }
    
    // MARK: - Public Methods
    
    func signInWithApple() {
        isLoading = true
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    func signInWithGoogle() {
        isLoading = true
        
        Task {
            do {
                print("Starting Google Sign-In...")
                let result = try await GoogleSignInHelper.shared.signIn()
                print("Google Sign-In successful: \(result.email)")
                
                await handleOAuthCallback(
                    provider: .google,
                    oauthId: result.oauthId,
                    email: result.email,
                    name: result.name,
                    avatarUrl: result.avatarUrl,
                    accessToken: result.accessToken,
                    refreshToken: result.refreshToken
                )
            } catch {
                print("Google Sign-In failed: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.authState = .error(error)
                }
            }
        }
    }
    
    func completeSetup(handle: String) async throws {
        guard let session = currentSession else {
            throw AuthError.noSession
        }
        
        let url = URL(string: "\(baseURL)/api/auth/complete-setup")!
        let body = CompleteSetupRequest(handle: handle)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode >= 400 {
            if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw AuthError.serverError(errorData.message)
            } else {
                throw AuthError.serverError("Setup failed")
            }
        }
        
        let updatedAccount = try JSONDecoder().decode(AuthAccount.self, from: data)
        
        await MainActor.run {
            self.currentAccount = updatedAccount
            self.authState = .authenticated(updatedAccount, session)
        }
        
        // Update stored account data
        try storeAccount(updatedAccount)
    }
    
    func checkHandleAvailability(handle: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/api/auth/check-handle/\(handle)")!
        let request = URLRequest(url: url)
        
        let (data, _) = try await urlSession.data(for: request)
        let response = try JSONDecoder().decode(HandleCheckResponse.self, from: data)
        
        return response.available
    }
    
    func signOut() async {
        if let session = currentSession {
            // Notify server about logout
            do {
                let url = URL(string: "\(baseURL)/api/auth/logout")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
                
                _ = try await self.urlSession.data(for: request)
            } catch {
                print("Logout request failed: \(error)")
            }
        }
        
        // Clear local storage
        clearStoredAuth()
        
        await MainActor.run {
            self.currentSession = nil
            self.currentAccount = nil
            self.authState = .unauthenticated
        }
    }
    
    func refreshSession() async throws {
        guard let refreshToken = loadRefreshToken() else {
            throw AuthError.noRefreshToken
        }
        
        let url = URL(string: "\(baseURL)/api/auth/refresh")!
        let body = RefreshRequest(refresh_token: refreshToken)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        
        if httpResponse.statusCode >= 400 {
            // Refresh failed, need to re-authenticate
            await signOut()
            throw AuthError.refreshFailed
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        // Store new session
        try storeSession(authResponse.session)
        try storeAccount(authResponse.account)
        
        await MainActor.run {
            self.currentSession = authResponse.session
            self.currentAccount = authResponse.account
            self.authState = .authenticated(authResponse.account, authResponse.session)
        }
    }
    
    // MARK: - Internal Methods
    
    private func loadStoredAuth() {
        DispatchQueue.global(qos: .background).async {
            if let session = self.loadSession(),
               let account = self.loadAccount() {
                
                DispatchQueue.main.async {
                    self.currentSession = session
                    self.currentAccount = account
                    
                    if session.isExpired {
                        Task {
                            do {
                                try await self.refreshSession()
                            } catch {
                                await self.signOut()
                            }
                        }
                    } else if account.needsHandle {
                        self.authState = .needsHandle(account, session)
                    } else {
                        self.authState = .authenticated(account, session)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.authState = .unauthenticated
                }
            }
        }
    }
    
    private func handleOAuthCallback(
        provider: OAuthProvider,
        oauthId: String,
        email: String,
        name: String?,
        avatarUrl: String?,
        accessToken: String?,
        refreshToken: String?
    ) async {
        do {
            let url = URL(string: "\(baseURL)/api/auth/oauth/callback")!
            let body = OAuthCallbackRequest(
                provider: provider.rawValue,
                code: nil,
                oauth_id: oauthId,
                email: email,
                name: name,
                avatar_url: avatarUrl,
                access_token: accessToken,
                refresh_token: refreshToken,
                expires_in: nil
            )
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Auth Error: Invalid response type")
                throw AuthError.invalidResponse
            }
            
            print("Auth Response: Status \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Auth Response Body: \(responseString)")
            }
            
            if httpResponse.statusCode >= 400 {
                if let errorData = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    print("Auth Error: \(errorData.message)")
                    throw AuthError.serverError(errorData.message)
                } else {
                    print("Auth Error: Authentication failed with status \(httpResponse.statusCode)")
                    throw AuthError.serverError("Authentication failed")
                }
            }
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            // Store auth data
            try storeSession(authResponse.session)
            try storeAccount(authResponse.account)
            if let refreshToken = refreshToken {
                try storeRefreshToken(refreshToken)
            }
            
            await MainActor.run {
                self.currentSession = authResponse.session
                self.currentAccount = authResponse.account
                self.isLoading = false
                
                if authResponse.account.needsHandle {
                    self.authState = .needsHandle(authResponse.account, authResponse.session)
                } else {
                    self.authState = .authenticated(authResponse.account, authResponse.session)
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.authState = .error(error)
            }
        }
    }
}

// MARK: - Apple Sign In Delegate

extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.authState = .error(AuthError.invalidCredential)
            }
            return
        }
        
        let oauthId = credential.user
        let email = credential.email ?? ""
        let name = credential.fullName?.formatted() ?? ""
        
        Task {
            await handleOAuthCallback(
                provider: .apple,
                oauthId: oauthId,
                email: email,
                name: name,
                avatarUrl: nil,
                accessToken: nil,
                refreshToken: nil
            )
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.authState = .error(error)
        }
    }
}

extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}

// MARK: - Keychain Storage

extension AuthenticationService {
    private func storeSession(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        try storeInKeychain(key: .sessionToken, data: data)
    }
    
    private func loadSession() -> AuthSession? {
        guard let data = loadFromKeychain(key: .sessionToken) else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }
    
    private func storeAccount(_ account: AuthAccount) throws {
        let data = try JSONEncoder().encode(account)
        try storeInKeychain(key: .accountData, data: data)
    }
    
    private func loadAccount() -> AuthAccount? {
        guard let data = loadFromKeychain(key: .accountData) else { return nil }
        return try? JSONDecoder().decode(AuthAccount.self, from: data)
    }
    
    private func storeRefreshToken(_ token: String) throws {
        let data = token.data(using: .utf8)!
        try storeInKeychain(key: .refreshToken, data: data)
    }
    
    private func loadRefreshToken() -> String? {
        guard let data = loadFromKeychain(key: .refreshToken) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func clearStoredAuth() {
        deleteFromKeychain(key: .sessionToken)
        deleteFromKeychain(key: .refreshToken)
        deleteFromKeychain(key: .accountData)
    }
    
    private func storeInKeychain(key: KeychainKey, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainError
        }
    }
    
    private func loadFromKeychain(key: KeychainKey) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    private func deleteFromKeychain(key: KeychainKey) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Auth Errors

enum AuthError: Error, LocalizedError {
    case noSession
    case noRefreshToken
    case invalidResponse
    case invalidCredential
    case refreshFailed
    case keychainError
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .noSession:
            return "No active session"
        case .noRefreshToken:
            return "No refresh token available"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidCredential:
            return "Invalid credentials"
        case .refreshFailed:
            return "Failed to refresh session"
        case .keychainError:
            return "Keychain storage error"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
