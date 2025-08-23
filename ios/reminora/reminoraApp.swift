//
//  reminoraApp.swift
//  reminora
//
//  Created by alexezh on 5/26/25.
//

import SwiftUI
import GoogleSignIn
import CoreData
import CoreLocation
import FacebookCore
import UIKit

// MARK: - Facebook Configuration Helper
class FacebookConfigHelper {
    static func loadAndConfigureFacebook() {
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
        
        // Set Facebook settings before any SDK initialization
        Settings.shared.appID = appID
        Settings.shared.clientToken = clientToken
        Settings.shared.displayName = facebookPlist["FacebookDisplayName"] as? String ?? "Reminora"
        
        print("✅ Facebook SDK pre-configured with App ID: \(appID)")
    }
}

@main
struct reminoraApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authService = AuthenticationService.shared
    @State private var pendingURL: URL?

    init() {
        // Configure Google Sign-In (always needed for OAuth)
        configureGoogleSignIn()
        
        // Facebook SDK will be initialized lazily only when needed
        // This prevents automatic AppEvents from being sent when users are logged in with other providers
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch authService.authState {
                case .loading:
                    SplashView()
                case .unauthenticated, .error:
                    LoginView()
                case .needsHandle:
                    LoginView() // HandleSetupView will be presented as sheet
                case .authenticated:
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                }
            }
            .environmentObject(authService)
            .onChange(of: authService.authState) { newState in
                // Process pending URL when user becomes authenticated
                if case .authenticated = newState, let url = pendingURL {
                    print("🔗 User authenticated, processing pending URL: \(url)")
                    PinSharingService.shared.handleReminoraLink(url)
                    pendingURL = nil
                }
            }
            .onOpenURL { url in
                print("🔗 onOpenURL called with: \(url)")
                print("🔗 URL scheme: \(url.scheme ?? "nil")")
                print("🔗 URL host: \(url.host ?? "nil")")
                print("🔗 URL path: \(url.path)")
                print("🔗 URL query: \(url.query ?? "nil")")
                
                // Handle Google Sign-In URLs
                if url.scheme == "com.googleusercontent.apps" {
                    print("🔗 Handling Google Sign-In URL")
                    GIDSignIn.sharedInstance.handle(url)
                }
                // Handle Reminora deep links
                else if url.scheme == "reminora" {
                    print("🔗 Handling Reminora deep link")
                    if case .authenticated = authService.authState {
                        print("🔗 User authenticated, processing link immediately")
                        PinSharingService.shared.handleReminoraLink(url)
                    } else {
                        print("🔗 User not authenticated, storing pending URL")
                        pendingURL = url
                    }
                } else {
                    print("🔗 Unhandled URL scheme: \(url.scheme ?? "nil")")
                }
            }
        }
    }
    
    private func configureGoogleSignIn() {
        // Configure Google Sign-In when GoogleService-Info.plist is available
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("GoogleService-Info.plist not found or CLIENT_ID missing")
            return
        }
        
        // Configure Google Sign-In
        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config
        print("Google Sign-In configured successfully")
    }
    
    private func configureFacebookSDK() {
        // Initialize Facebook SDK ApplicationDelegate
        // Settings should already be configured by FacebookConfigHelper
        ApplicationDelegate.shared.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )
        
        print("✅ Facebook SDK ApplicationDelegate initialized")
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.blue.opacity(0.8)
                .ignoresSafeArea()
            
            VStack {
                Image(systemName: "camera.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                Text("Reminora")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .padding(.top, 20)
            }
        }
    }
}
