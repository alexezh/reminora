package com.reminora.android.data.repository

import com.reminora.android.data.api.ApiService
import com.reminora.android.ui.home.Photo
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PhotoRepository @Inject constructor(
    private val apiService: ApiService
) {
    
    suspend fun getTimeline(): List<Photo> {
        // TODO: Implement timeline API call
        // return apiService.getTimeline()
        
        // Mock data for now
        return listOf(
            Photo(
                id = "1",
                username = "alice",
                displayName = "Alice Johnson",
                caption = "Beautiful sunset at the beach! 🌅",
                locationName = "Santa Monica Beach",
                imageUrl = null
            ),
            Photo(
                id = "2",
                username = "bob",
                displayName = "Bob Smith",
                caption = "Great coffee at this new place ☕",
                locationName = "Downtown Coffee Shop",
                imageUrl = null
            ),
            Photo(
                id = "3",
                username = "charlie",
                displayName = "Charlie Brown",
                caption = null,
                locationName = "Central Park",
                imageUrl = null
            )
        )
    }
    
    suspend fun uploadPhoto(
        imageData: ByteArray,
        caption: String?,
        latitude: Double?,
        longitude: Double?
    ): Photo {
        // TODO: Implement photo upload
        throw NotImplementedError("Photo upload not implemented yet")
    }
}