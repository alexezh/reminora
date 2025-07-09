package com.reminora.android.ui.home

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
class HomeViewModel @Inject constructor(
    private val photoRepository: PhotoRepository
) : ViewModel() {
    
    private val _homeState = MutableStateFlow(HomeState())
    val homeState: StateFlow<HomeState> = _homeState.asStateFlow()
    
    init {
        loadPhotos()
    }
    
    private fun loadPhotos() {
        viewModelScope.launch {
            _homeState.value = _homeState.value.copy(isLoading = true)
            
            try {
                val photos = photoRepository.getTimeline()
                _homeState.value = _homeState.value.copy(
                    photos = photos,
                    isLoading = false
                )
            } catch (e: Exception) {
                _homeState.value = _homeState.value.copy(
                    isLoading = false,
                    error = e.message
                )
            }
        }
    }
    
    fun refreshPhotos() {
        loadPhotos()
    }
}

data class HomeState(
    val photos: List<Photo> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null
)