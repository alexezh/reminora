package com.reminora.android.ui.add

import android.location.Address
import android.location.Geocoder
import android.location.Location
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.reminora.android.data.model.PlaceCoordinates
import com.reminora.android.data.repository.PhotoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import javax.inject.Inject

@HiltViewModel
class AddPlaceViewModel @Inject constructor(
    private val photoRepository: PhotoRepository
) : ViewModel() {
    
    private val _addState = MutableStateFlow(AddState())
    val addState: StateFlow<AddState> = _addState.asStateFlow()
    
    init {
        // TODO: Check location permission
        checkLocationPermission()
    }
    
    private fun checkLocationPermission() {
        // TODO: Implement actual location permission check
        _addState.value = _addState.value.copy(hasLocationPermission = false)
    }
    
    fun selectImage(uri: Uri) {
        _addState.value = _addState.value.copy(
            selectedImageUri = uri,
            error = null
        )
        
        // Extract location from image and perform reverse geocoding
        extractLocationFromImage(uri)
    }
    
    private fun extractLocationFromImage(uri: Uri) {
        viewModelScope.launch {
            try {
                _addState.value = _addState.value.copy(isLoadingLocation = true)
                
                // TODO: Extract GPS coordinates from image EXIF data
                // This would need to be implemented in the photo repository
                val location = photoRepository.extractLocationFromImage(uri)
                
                if (location != null) {
                    val coordinates = PlaceCoordinates(location.latitude, location.longitude)
                    _addState.value = _addState.value.copy(coordinates = coordinates)
                    
                    // Perform reverse geocoding
                    reverseGeocodeLocation(location)
                } else {
                    _addState.value = _addState.value.copy(
                        isLoadingLocation = false,
                        coordinates = null
                    )
                }
            } catch (e: Exception) {
                _addState.value = _addState.value.copy(
                    isLoadingLocation = false,
                    error = "Failed to extract location from image"
                )
            }
        }
    }
    
    private suspend fun reverseGeocodeLocation(location: Location) {
        withContext(Dispatchers.IO) {
            try {
                // TODO: Implement with actual Geocoder instance from context
                // For now, this is a placeholder structure
                val addresses: List<Address> = emptyList() // geocoder.getFromLocation(location.latitude, location.longitude, 1)
                
                val address = addresses.firstOrNull()
                
                withContext(Dispatchers.Main) {
                    _addState.value = _addState.value.copy(
                        isLoadingLocation = false,
                        placeName = address?.featureName ?: address?.premises,
                        city = address?.locality ?: address?.subAdminArea,
                        country = address?.countryName
                    )
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    _addState.value = _addState.value.copy(
                        isLoadingLocation = false
                    )
                }
            }
        }
    }
    
    fun savePlace(caption: String?) {
        val selectedUri = _addState.value.selectedImageUri
        if (selectedUri == null) {
            _addState.value = _addState.value.copy(error = "Please select an image")
            return
        }
        
        viewModelScope.launch {
            _addState.value = _addState.value.copy(isLoading = true, error = null)
            
            try {
                val placeId = photoRepository.saveImageFromUri(
                    uri = selectedUri,
                    contentText = caption,
                    currentLocation = null // TODO: Get current location if permission granted
                )
                
                if (placeId != null) {
                    _addState.value = _addState.value.copy(
                        isLoading = false,
                        isPlaceAdded = true
                    )
                } else {
                    _addState.value = _addState.value.copy(
                        isLoading = false,
                        error = "Failed to save place"
                    )
                }
            } catch (e: Exception) {
                _addState.value = _addState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Failed to save place"
                )
            }
        }
    }
    
    fun requestLocationPermission() {
        // TODO: Implement location permission request
        _addState.value = _addState.value.copy(hasLocationPermission = true)
    }
}

data class AddState(
    val selectedImageUri: Uri? = null,
    val hasLocationPermission: Boolean = false,
    val isLoading: Boolean = false,
    val isPlaceAdded: Boolean = false,
    val error: String? = null,
    val isLoadingLocation: Boolean = false,
    val coordinates: PlaceCoordinates? = null,
    val placeName: String? = null,
    val city: String? = null,
    val country: String? = null
)