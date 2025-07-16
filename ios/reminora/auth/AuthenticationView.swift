import SwiftUI

struct AuthenticationView: View {
    @StateObject private var authService = AuthenticationService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Sign In to Share Pins")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Connect with friends and share your favorite places")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Authentication options
                VStack(spacing: 16) {
                    // Facebook Sign In
                    Button(action: {
                        authService.signInWithFacebook()
                    }) {
                        HStack {
                            Image(systemName: "f.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text("Continue with Facebook")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(25)
                    }
                    .disabled(authService.isLoading)
                    
                    // Google Sign In
                    Button(action: {
                        authService.signInWithGoogle()
                    }) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text("Continue with Google")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .cornerRadius(25)
                    }
                    .disabled(authService.isLoading)
                    
                    // Apple Sign In
                    Button(action: {
                        authService.signInWithApple()
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text("Continue with Apple")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black)
                        .cornerRadius(25)
                    }
                    .disabled(authService.isLoading)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Privacy notice
                VStack(spacing: 8) {
                    Text("By signing in, you agree to our Terms of Service and Privacy Policy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .overlay {
            if authService.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Signing in...")
                                .padding(.top)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
            }
        }
        .onChange(of: authService.authState) { _, newState in
            switch newState {
            case .authenticated, .needsHandle:
                dismiss()
            case .error(let error):
                errorMessage = error.localizedDescription
                showingError = true
            default:
                break
            }
        }
        .alert("Sign In Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}