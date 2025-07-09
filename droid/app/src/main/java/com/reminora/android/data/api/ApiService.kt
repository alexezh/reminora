package com.reminora.android.data.api

import retrofit2.Response
import retrofit2.http.*

interface ApiService {
    
    @POST("api/auth/oauth/callback")
    suspend fun authenticate(@Body request: AuthRequest): Response<AuthResponse>
    
    @GET("api/photos/timeline")
    suspend fun getTimeline(
        @Query("since") since: Long = 0,
        @Query("limit") limit: Int = 50
    ): Response<TimelineResponse>
    
    @POST("api/photos")
    suspend fun uploadPhoto(@Body request: PhotoUploadRequest): Response<PhotoResponse>
    
    @POST("api/follows")
    suspend fun followUser(@Body request: FollowRequest): Response<FollowResponse>
    
    @DELETE("api/follows/{userId}")
    suspend fun unfollowUser(@Path("userId") userId: String): Response<Unit>
    
    @GET("api/follows/following")
    suspend fun getFollowing(): Response<List<UserProfile>>
    
    @GET("api/follows/followers")
    suspend fun getFollowers(): Response<List<UserProfile>>
}

// API Models
data class AuthRequest(
    val provider: String,
    val oauth_id: String,
    val email: String,
    val name: String?,
    val avatar_url: String?,
    val access_token: String?,
    val refresh_token: String?
)

data class AuthResponse(
    val account: Account,
    val session: Session
)

data class Account(
    val id: String,
    val username: String,
    val email: String,
    val display_name: String,
    val handle: String?,
    val avatar_url: String?,
    val needs_handle: Boolean?
)

data class Session(
    val token: String,
    val expires_at: Long
)

data class TimelineResponse(
    val photos: List<PhotoResponse>,
    val waterline: String
)

data class PhotoResponse(
    val id: String,
    val account_id: String,
    val photo_data: PhotoData,
    val latitude: Double?,
    val longitude: Double?,
    val location_name: String?,
    val caption: String?,
    val created_at: Long,
    val username: String,
    val display_name: String
)

data class PhotoData(
    val image_data: String, // Base64 encoded
    val image_format: String,
    val created_at: Long
)

data class PhotoUploadRequest(
    val photo_data: PhotoData,
    val latitude: Double?,
    val longitude: Double?,
    val location_name: String?,
    val caption: String?
)

data class FollowRequest(
    val following_id: String
)

data class FollowResponse(
    val id: String,
    val follower_id: String,
    val following_id: String,
    val created_at: Long,
    val username: String,
    val display_name: String
)

data class UserProfile(
    val id: String,
    val username: String,
    val display_name: String,
    val created_at: Long
)