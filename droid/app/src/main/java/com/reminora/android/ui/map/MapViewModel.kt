package com.reminora.android.ui.map

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.reminora.android.data.local.Place
import com.reminora.android.data.repository.PhotoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class MapViewModel @Inject constructor(
    private val photoRepository: PhotoRepository
) : ViewModel() {
    
    private val _mapState = MutableStateFlow(MapState())
    val mapState: StateFlow<MapState> = _mapState.asStateFlow()
    
    private var allPlaces: List<Place> = emptyList()
    
    init {
        loadPlaces()
    }
    
    private fun loadPlaces() {
        viewModelScope.launch {
            _mapState.value = _mapState.value.copy(isLoading = true)
            
            photoRepository.getAllPlaces().collect { places ->
                allPlaces = places
                _mapState.value = _mapState.value.copy(
                    places = places,
                    isLoading = false
                )
            }
        }
    }
    
    fun searchPlaces(query: String) {
        val filteredPlaces = if (query.isEmpty()) {
            allPlaces
        } else {
            allPlaces.filter { place ->
                place.post?.contains(query, ignoreCase = true) == true ||
                place.url?.contains(query, ignoreCase = true) == true
            }
        }
        
        _mapState.value = _mapState.value.copy(
            places = filteredPlaces,
            searchQuery = query
        )
    }
    
    fun selectPlace(place: Place) {
        _mapState.value = _mapState.value.copy(selectedPlace = place)
        // TODO: Center map on selected place
        // TODO: Navigate to place detail view
    }
    
    fun clearSelection() {
        _mapState.value = _mapState.value.copy(selectedPlace = null)
    }
}

data class MapState(
    val places: List<Place> = emptyList(),
    val selectedPlace: Place? = null,
    val searchQuery: String = "",
    val isLoading: Boolean = false,
    val error: String? = null
)