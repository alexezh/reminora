# Google OAuth Setup Guide

The current implementation includes a placeholder for Google OAuth. To enable full Google authentication:

## 1. Add Google Sign-In SDK

Add the Google Sign-In package to your Xcode project:

```
https://github.com/google/GoogleSignIn-iOS
```

## 2. Configure Google OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing project
3. Enable Google Sign-In API
4. Create OAuth 2.0 credentials for iOS app
5. Download `GoogleService-Info.plist`

## 3. Add Configuration Files

1. Add `GoogleService-Info.plist` to your Xcode project
2. Add URL scheme to `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

## 4. Update GoogleSignInHelper.swift

Replace the placeholder implementation with:

```swift
import GoogleSignIn

class GoogleSignInHelper {
    static let shared = GoogleSignInHelper()
    
    private init() {}
    
    func configure() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("GoogleService-Info.plist not found or CLIENT_ID missing")
            return
        }
        
        guard let config = GIDConfiguration(clientID: clientId) else { return }
        GIDSignIn.sharedInstance.configuration = config
    }
    
    func signIn() async throws -> GoogleOAuthResult {
        guard let presentingViewController = await UIApplication.shared.windows.first?.rootViewController else {
            throw GoogleSignInError.noPresentingViewController
        }
        
        return try await withCheckedThrowingContinuation { continuation in
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
```

## 5. Initialize Google Sign-In

In your `reminoraApp.swift`, add:

```swift
import GoogleSignIn

@main
struct reminoraApp: App {
    init() {
        GoogleSignInHelper.shared.configure()
    }
    
    // ... rest of your app
}
```

## 6. Handle URL Callbacks

Add to your scene delegate or app delegate:

```swift
import GoogleSignIn

func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    return GIDSignIn.sharedInstance.handle(url)
}
```

## Current Behavior

- **Before Setup**: Google OAuth shows error message about not being implemented
- **After Setup**: Full Google OAuth flow with automatic account creation
- **Backend Ready**: The Cloudflare Workers backend already handles Google OAuth data

The system is designed to:
1. **Login**: If Google account exists in Reminora, sign in immediately  
2. **Signup**: If new Google account, create Reminora account automatically
3. **Handle Setup**: New users will be prompted to choose a unique @handle

This provides a seamless "Continue with Google" experience for both new and returning users!