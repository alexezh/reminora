//
//  reminoraApp.swift
//  reminora
//
//  Created by alexezh on 5/26/25.
//

import SwiftUI

@main
struct reminoraApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authService = AuthenticationService.shared

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
        }
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
