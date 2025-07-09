package com.reminora.android.data.repository

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.reminora.android.data.api.ApiService
import com.reminora.android.data.api.AuthRequest
import com.reminora.android.ui.auth.User
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
            val authRequest = AuthRequest(
                provider = "google",
                token = credential.idToken,
                email = credential.id,
                name = credential.displayName
            )
            
            val authResponse = apiService.authenticate(authRequest)
            
            // 3. Store session token (TODO: Use secure storage)
            // For now, we'll return the result
            
            AuthResult(
                user = User(
                    id = authResponse.user.id,
                    email = authResponse.user.email,
                    displayName = authResponse.user.name ?: credential.displayName ?: "",
                    handle = authResponse.user.handle,
                    avatarUrl = authResponse.user.avatarUrl
                ),
                sessionToken = authResponse.sessionToken
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
        // For now, return false
        return false
    }
    
    suspend fun getCurrentUser(): User? {
        // TODO: Get current user from stored session
        return null
    }
}

data class AuthResult(
    val user: User,
    val sessionToken: String
)