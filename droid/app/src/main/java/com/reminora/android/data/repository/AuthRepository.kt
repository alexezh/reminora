package com.reminora.android.data.repository

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.reminora.android.DebugConfig
import com.reminora.android.data.api.ApiService
import com.reminora.android.data.model.User
import com.reminora.android.data.model.OAuthCallbackRequest
import com.reminora.android.data.model.AuthResponse
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthRepository @Inject constructor(
    private val apiService: ApiService,
    @ApplicationContext private val context: Context
) {
    
    private val credentialManager = CredentialManager.create(context)
    private val googleClientId = "YOUR_GOOGLE_CLIENT_ID" // TODO: Replace with actual client ID
    
    suspend fun signInWithGoogle(): AuthResult = withContext(Dispatchers.IO) {
        try {
            // 1. Get Google OAuth token using Credential Manager
            val googleIdOption = GetGoogleIdOption.Builder()
                .setServerClientId(googleClientId)
                .build()
            
            val request = GetCredentialRequest.Builder()
                .addCredentialOption(googleIdOption)
                .build()
            
            val result = credentialManager.getCredential(
                request = request,
                context = context
            )
            
            val credential = GoogleIdTokenCredential.createFrom(result.credential.data)
            
            // 2. Send to backend for authentication
            val authRequest = com.reminora.android.data.api.AuthRequest(
                provider = "google",
                oauth_id = credential.id,
                email = credential.id,
                name = credential.displayName,
                avatar_url = credential.profilePictureUri?.toString(),
                access_token = credential.idToken,
                refresh_token = null
            )
            
            val authResponse = apiService.authenticate(authRequest).body()!!
            
            // 3. Store session token (TODO: Use secure storage)
            // For now, we'll return the result
            
            AuthResult(
                user = User(
                    id = authResponse.account.id,
                    username = authResponse.account.username,
                    email = authResponse.account.email,
                    displayName = authResponse.account.display_name,
                    handle = authResponse.account.handle,
                    avatarUrl = authResponse.account.avatar_url
                ),
                sessionToken = authResponse.session.token
            )
        } catch (e: GetCredentialException) {
            throw Exception("Google Sign-In failed: ${e.message}")
        } catch (e: Exception) {
            throw Exception("Authentication failed: ${e.message}")
        }
    }
    
    suspend fun signOut() = withContext(Dispatchers.IO) {
        try {
            // 1. Call logout API
            apiService.logout()
            
            // 2. Clear stored session (TODO: Implement secure storage)
            // 3. Clear local data
        } catch (e: Exception) {
            // Log error but don't throw - we want to clear local state anyway
        }
    }
    
    suspend fun isAuthenticated(): Boolean {
        // TODO: Check if valid session exists in secure storage
        // For now, return false (unless in debug mode and skip auth was used)
        return false
    }
    
    suspend fun isSkipAuthEnabled(): Boolean = DebugConfig.ALLOW_SKIP_AUTH
    
    suspend fun getCurrentUser(): User? {
        // TODO: Get current user from stored session
        return null
    }
}

data class AuthResult(
    val user: User,
    val sessionToken: String
)