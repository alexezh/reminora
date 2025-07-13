package com.reminora.android.ui.photos

import android.content.ContentResolver
import android.content.Context
import android.provider.MediaStore
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

enum class PhotoPreferenceType {
    LIKE, DISLIKE, NEUTRAL
}

enum class PhotoFilterType(val displayName: String, val iconName: String) {
    ALL("All Photos", "photo_library"),
    FAVORITES("Favorites", "favorite"),
    DISLIKES("Disliked", "cancel"),
    NEUTRAL("Neutral", "remove_circle"),
    NOT_DISLIKED("Photos", "photo")
}

@HiltViewModel
class PhotoStackViewModel @Inject constructor(
    @ApplicationContext private val context: Context
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(PhotoStackUiState())
    val uiState: StateFlow<PhotoStackUiState> = _uiState.asStateFlow()
    
    // Photo preferences storage (in-memory for demo)
    private val photoPreferences = mutableMapOf<String, PhotoPreferenceType>()
    
    private var allPhotoStacks: List<PhotoStack> = emptyList()
    private var currentFilter = PhotoFilterType.NOT_DISLIKED
    
    init {
        loadPhotos()
    }
    
    fun requestPermission() {
        // For now, assume permission is granted and load photos
        _uiState.value = _uiState.value.copy(hasPermission = true)
        loadPhotos()
    }
    
    private fun loadPhotos() {
        viewModelScope.launch {
            try {
                _uiState.value = _uiState.value.copy(isLoading = true)
                
                val photos = withContext(Dispatchers.IO) {
                    loadPhotosFromMediaStore()
                }
                
                allPhotoStacks = createPhotoStacks(photos)
                
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    hasPermission = true
                )
                
                applyCurrentFilter()
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message
                )
            }
        }
    }
    
    fun selectStack(stack: PhotoStack) {
        _uiState.value = _uiState.value.copy(
            selectedStack = stack,
            selectedIndex = 0
        )
    }
    
    fun clearSelection() {
        _uiState.value = _uiState.value.copy(
            selectedStack = null,
            selectedIndex = 0
        )
    }
    
    fun pinPhoto(photo: Photo) {
        // TODO: Implement pin functionality
        viewModelScope.launch {
            // Create place from photo
        }
    }
    
    fun sharePhoto(photo: Photo) {
        // TODO: Implement share functionality
        viewModelScope.launch {
            // Create reminora link and share
        }
    }
    
    fun setPhotoPreference(photo: Photo, preference: PhotoPreferenceType) {
        photoPreferences[photo.id] = preference
        applyCurrentFilter()
    }
    
    fun getPhotoPreference(photo: Photo): PhotoPreferenceType {
        return photoPreferences[photo.id] ?: PhotoPreferenceType.NEUTRAL
    }
    
    fun setFilter(filter: PhotoFilterType) {
        currentFilter = filter
        applyCurrentFilter()
    }
    
    private fun applyCurrentFilter() {
        val filteredStacks = when (currentFilter) {
            PhotoFilterType.ALL -> allPhotoStacks
            PhotoFilterType.FAVORITES -> allPhotoStacks.filter { stack ->
                stack.photos.any { getPhotoPreference(it) == PhotoPreferenceType.LIKE }
            }
            PhotoFilterType.DISLIKES -> allPhotoStacks.filter { stack ->
                stack.photos.any { getPhotoPreference(it) == PhotoPreferenceType.DISLIKE }
            }
            PhotoFilterType.NEUTRAL -> allPhotoStacks.filter { stack ->
                stack.photos.any { getPhotoPreference(it) == PhotoPreferenceType.NEUTRAL }
            }
            PhotoFilterType.NOT_DISLIKED -> allPhotoStacks.filter { stack ->
                stack.photos.none { getPhotoPreference(it) == PhotoPreferenceType.DISLIKE }
            }
        }
        
        _uiState.value = _uiState.value.copy(
            photoStacks = filteredStacks,
            currentFilter = currentFilter
        )
    }
    
    private fun loadPhotosFromMediaStore(): List<Photo> {
        val photos = mutableListOf<Photo>()
        
        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DATA,
            MediaStore.Images.Media.DATE_TAKEN,
            MediaStore.Images.Media.DATE_ADDED
        )
        
        val sortOrder = "${MediaStore.Images.Media.DATE_TAKEN} DESC"
        
        try {
            context.contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection,
                null,
                null,
                sortOrder
            )?.use { cursor ->
                val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
                val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATA)
                val dateTakenColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_TAKEN)
                val dateAddedColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
                
                while (cursor.moveToNext() && photos.size < 100) { // Limit to 100 photos for performance
                    val id = cursor.getLong(idColumn)
                    val data = cursor.getString(dataColumn)
                    val dateTaken = cursor.getLong(dateTakenColumn)
                    val dateAdded = cursor.getLong(dateAddedColumn)
                    
                    // Use dateTaken if available, otherwise use dateAdded
                    val creationDate = if (dateTaken > 0) dateTaken else dateAdded * 1000
                    
                    val uri = "${MediaStore.Images.Media.EXTERNAL_CONTENT_URI}/$id"
                    
                    photos.add(
                        Photo(
                            id = id.toString(),
                            uri = uri,
                            creationDate = creationDate,
                            location = null // TODO: Extract location from EXIF if needed
                        )
                    )
                }
            }
        } catch (e: Exception) {
            // Handle permission denied or other errors
            return emptyList()
        }
        
        return photos
    }
    
    private fun createPhotoStacks(photos: List<Photo>): List<PhotoStack> {
        if (photos.isEmpty()) return emptyList()
        
        val stacks = mutableListOf<PhotoStack>()
        var currentStack = mutableListOf<Photo>()
        
        photos.forEach { photo ->
            if (currentStack.isEmpty()) {
                currentStack.add(photo)
            } else {
                val timeDiff = currentStack.last().creationDate - photo.creationDate
                if (timeDiff <= 10 * 60 * 1000) { // 10 minutes
                    currentStack.add(photo)
                } else {
                    // Create stack from current photos
                    stacks.add(
                        PhotoStack(
                            id = "stack_${stacks.size}",
                            photos = currentStack.toList(),
                            primaryPhoto = currentStack.first()
                        )
                    )
                    currentStack = mutableListOf(photo)
                }
            }
        }
        
        // Add final stack
        if (currentStack.isNotEmpty()) {
            stacks.add(
                PhotoStack(
                    id = "stack_${stacks.size}",
                    photos = currentStack.toList(),
                    primaryPhoto = currentStack.first()
                )
            )
        }
        
        return stacks
    }
}

data class PhotoStackUiState(
    val photoStacks: List<PhotoStack> = emptyList(),
    val selectedStack: PhotoStack? = null,
    val selectedIndex: Int = 0,
    val hasPermission: Boolean = true, // Set to true for now to skip permission screen
    val isLoading: Boolean = false,
    val error: String? = null,
    val currentFilter: PhotoFilterType = PhotoFilterType.NOT_DISLIKED
)