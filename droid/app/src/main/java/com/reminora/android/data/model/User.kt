package com.reminora.android.data.model

import kotlinx.serialization.Serializable

@Serializable
data class User(
    val id: String,
    val username: String,
    val email: String,
    val displayName: String,
    val handle: String? = null,
    val avatarUrl: String? = null,
    val needsHandle: Boolean = false
)

@Serializable
data class AuthSession(
    val token: String,
    val expiresAt: Long
) {
    val isExpired: Boolean
        get() = System.currentTimeMillis() / 1000 >= expiresAt
}

@Serializable
data class AuthAccount(
    val id: String,
    val username: String,
    val email: String,
    val displayName: String,
    val handle: String? = null,
    val avatarUrl: String? = null,
    val needsHandle: Boolean? = null
) {
    val requiresHandle: Boolean
        get() = needsHandle == true || handle.isNullOrEmpty()
}

@Serializable
data class AuthResponse(
    val account: AuthAccount,
    val session: AuthSession
)

@Serializable
data class OAuthCallbackRequest(
    val provider: String,
    val code: String? = null,
    val oauth_id: String,
    val email: String,
    val name: String? = null,
    val avatar_url: String? = null,
    val access_token: String? = null,
    val refresh_token: String? = null,
    val expires_in: Int? = null
)

@Serializable
data class CompleteSetupRequest(
    val handle: String
)

@Serializable
data class HandleCheckResponse(
    val available: Boolean,
    val message: String
)

@Serializable
data class RefreshRequest(
    val refreshToken: String
)

enum class OAuthProvider(val value: String, val displayName: String, val iconName: String) {
    GOOGLE("google", "Google", "google"),
    APPLE("apple", "Apple", "apple"),
    GITHUB("github", "GitHub", "github")
}

sealed class AuthState {
    object Loading : AuthState()
    object Unauthenticated : AuthState()
    data class NeedsHandle(val account: AuthAccount, val session: AuthSession) : AuthState()
    data class Authenticated(val account: AuthAccount, val session: AuthSession) : AuthState()
    data class Error(val error: Throwable) : AuthState()
}