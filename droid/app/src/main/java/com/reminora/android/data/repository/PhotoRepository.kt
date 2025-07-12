package com.reminora.android.data.repository

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.location.Location
import android.media.ExifInterface
import android.net.Uri
import com.reminora.android.data.api.ApiService
import com.reminora.android.data.local.Place
import com.reminora.android.data.local.ReminoraDatabase
import com.reminora.android.ui.home.Photo
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import java.io.ByteArrayOutputStream
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PhotoRepository @Inject constructor(
    @ApplicationContext private val context: Context,
    private val apiService: ApiService,
    private val database: ReminoraDatabase
) {
    private val placeDao = database.placeDao()
    
    // Local database operations
    fun getAllPlaces(): Flow<List<Place>> = placeDao.getAllPlaces()
    
    fun searchPlaces(searchText: String): Flow<List<Place>> = placeDao.searchPlaces(searchText)
    
    suspend fun getPlaceById(id: Long): Place? = placeDao.getPlaceById(id)
    
    suspend fun saveImageFromUri(
        uri: Uri, 
        contentText: String? = null,
        currentLocation: Location? = null
    ): Long? {
        return try {
            val inputStream = context.contentResolver.openInputStream(uri)
            val imageData = inputStream?.readBytes() ?: return null
            inputStream.close()
            
            val scaledImageData = downsampleImage(imageData, 1024)
            val location = extractLocationFromUri(uri) ?: currentLocation
            val locationData = location?.let { serializeLocation(it) }
            
            val place = Place(
                imageData = scaledImageData,
                location = locationData,
                dateAdded = Date(),
                post = contentText,
                url = uri.toString()
            )
            
            placeDao.insertPlace(place)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
    
    suspend fun saveImageData(
        imageData: ByteArray,
        location: Location? = null,
        contentText: String? = null
    ): Long? {
        return try {
            val scaledImageData = downsampleImage(imageData, 1024)
            val locationData = location?.let { serializeLocation(it) }
            
            val place = Place(
                imageData = scaledImageData,
                location = locationData,
                dateAdded = Date(),
                post = contentText,
                url = null
            )
            
            placeDao.insertPlace(place)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
    
    suspend fun deletePlace(place: Place) = placeDao.deletePlace(place)
    
    suspend fun updatePlace(place: Place) = placeDao.updatePlace(place)
    
    // API operations
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
        @Suppress("UNUSED_PARAMETER") imageData: ByteArray,
        @Suppress("UNUSED_PARAMETER") caption: String?,
        @Suppress("UNUSED_PARAMETER") latitude: Double?,
        @Suppress("UNUSED_PARAMETER") longitude: Double?
    ): Photo {
        // TODO: Implement photo upload
        throw NotImplementedError("Photo upload not implemented yet")
    }
    
    // Helper methods
    private fun downsampleImage(imageData: ByteArray, maxSize: Int): ByteArray {
        val options = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeByteArray(imageData, 0, imageData.size, options)
        
        val imageWidth = options.outWidth
        val imageHeight = options.outHeight
        val scale = maxOf(imageWidth, imageHeight) / maxSize
        
        if (scale <= 1) return imageData
        
        val scaledOptions = BitmapFactory.Options().apply {
            inSampleSize = scale
        }
        
        val scaledBitmap = BitmapFactory.decodeByteArray(imageData, 0, imageData.size, scaledOptions)
        val outputStream = ByteArrayOutputStream()
        scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 90, outputStream)
        scaledBitmap.recycle()
        
        return outputStream.toByteArray()
    }
    
    private fun extractLocationFromUri(uri: Uri): Location? {
        return try {
            val inputStream = context.contentResolver.openInputStream(uri)
            val exif = ExifInterface(inputStream!!)
            inputStream.close()
            
            val latLong = FloatArray(2)
            if (exif.getLatLong(latLong)) {
                Location("").apply {
                    latitude = latLong[0].toDouble()
                    longitude = latLong[1].toDouble()
                }
            } else null
        } catch (e: Exception) {
            null
        }
    }
    
    private fun serializeLocation(location: Location): ByteArray {
        val locationString = "${location.latitude},${location.longitude}"
        return locationString.toByteArray()
    }
    
    fun deserializeLocation(locationData: ByteArray): Location? {
        return try {
            val locationString = String(locationData)
            val parts = locationString.split(",")
            if (parts.size == 2) {
                Location("").apply {
                    latitude = parts[0].toDouble()
                    longitude = parts[1].toDouble()
                }
            } else null
        } catch (e: Exception) {
            null
        }
    }
}