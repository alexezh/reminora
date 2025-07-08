import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var authService = AuthenticationService.shared
    @State private var showingHandleSetup = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    // App logo and title
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                        
                        Text("Reminora")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Share moments, follow friends")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    // Loading state
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        // Sign in options
                        VStack(spacing: 16) {
                            // Apple Sign In
                            SignInWithAppleButton(
                                onRequest: { request in
                                    request.requestedScopes = [.fullName, .email]
                                },
                                onCompletion: { _ in
                                    // Handled by AuthenticationService
                                }
                            )
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 50)
                            .cornerRadius(25)
                            
                            // Google Sign In
                            Button(action: {
                                authService.signInWithGoogle()
                            }) {
                                HStack {
                                    Image(systemName: "globe")
                                        .font(.title2)
                                    Text("Continue with Google")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(25)
                            }
                            
                            // GitHub Sign In (placeholder)
                            Button(action: {
                                // GitHub OAuth would be implemented here
                            }) {
                                HStack {
                                    Image(systemName: "laptopcomputer")
                                        .font(.title2)
                                    Text("Continue with GitHub")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .cornerRadius(25)
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    // Login vs Sign Up explanation
                    VStack(spacing: 8) {
                        Text("New to Reminora? We'll create your account automatically.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                        
                        Text("By continuing, you agree to our")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        HStack {
                            Button("Terms of Service") {
                                // Open terms
                            }
                            .foregroundColor(.white)
                            .underline()
                            
                            Text("and")
                                .foregroundColor(.white.opacity(0.8))
                            
                            Button("Privacy Policy") {
                                // Open privacy policy
                            }
                            .foregroundColor(.white)
                            .underline()
                        }
                        .font(.caption)
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .onReceive(authService.$authState) { state in
            if case .needsHandle = state {
                showingHandleSetup = true
            }
        }
        .sheet(isPresented: $showingHandleSetup) {
            HandleSetupView()
        }
        .alert("Authentication Error", isPresented: .constant(authService.authState.isError)) {
            Button("OK") {
                // Reset error state
            }
        } message: {
            if case .error(let error) = authService.authState {
                Text(error.localizedDescription)
            }
        }
    }
}

extension AuthState {
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

struct HandleSetupView: View {
    @StateObject private var authService = AuthenticationService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var handle = ""
    @State private var isCheckingHandle = false
    @State private var handleAvailable: Bool? = nil
    @State private var isSettingUp = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "at.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Choose Your Handle")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("This is how other users will find and mention you")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Handle input
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("@")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        TextField("your_handle", text: $handle)
                            .font(.title2)
                            .textFieldStyle(PlainTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: handle) { newValue in
                                // Clean input
                                let cleaned = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                if cleaned != newValue {
                                    handle = cleaned
                                }
                                
                                // Reset availability check
                                handleAvailable = nil
                                
                                // Check availability after delay
                                if cleaned.count >= 3 {
                                    checkHandleAvailability()
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Handle validation
                    if handle.count > 0 && handle.count < 3 {
                        Label("Handle must be at least 3 characters", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if handle.count > 20 {
                        Label("Handle must be 20 characters or less", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if isCheckingHandle {
                        Label("Checking availability...", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let available = handleAvailable {
                        if available {
                            Label("Handle is available!", systemImage: "checkmark.circle")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Label("Handle is already taken", systemImage: "xmark.circle")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if !errorMessage.isEmpty {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                
                // Continue button
                Button(action: completeSetup) {
                    Group {
                        if isSettingUp {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Complete Setup")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canContinue ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(25)
                }
                .disabled(!canContinue || isSettingUp)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
        }
    }
    
    private var canContinue: Bool {
        return handle.count >= 3 && handle.count <= 20 && handleAvailable == true
    }
    
    private func checkHandleAvailability() {
        guard handle.count >= 3 else { return }
        
        isCheckingHandle = true
        
        Task {
            do {
                let available = try await authService.checkHandleAvailability(handle: handle)
                
                await MainActor.run {
                    self.handleAvailable = available
                    self.isCheckingHandle = false
                }
            } catch {
                await MainActor.run {
                    self.isCheckingHandle = false
                    self.handleAvailable = false
                }
            }
        }
    }
    
    private func completeSetup() {
        guard canContinue else { return }
        
        isSettingUp = true
        errorMessage = ""
        
        Task {
            do {
                try await authService.completeSetup(handle: handle)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isSettingUp = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}