package com.reminora.android.ui.add

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.reminora.android.data.repository.PhotoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
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
    val error: String? = null
)