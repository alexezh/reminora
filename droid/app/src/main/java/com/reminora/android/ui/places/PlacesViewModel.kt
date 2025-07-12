package com.reminora.android.ui.places

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class PlacesViewModel @Inject constructor() : ViewModel() {
    
    private val _placesState = MutableStateFlow(PlacesState())
    val placesState: StateFlow<PlacesState> = _placesState.asStateFlow()
    
    private var allNearbyPlaces: List<NearbyPlace> = emptyList()
    
    fun findNearbyPlaces() {
        viewModelScope.launch {
            _placesState.value = _placesState.value.copy(isLoading = true, error = null)
            
            try {
                // TODO: Implement actual nearby places search using Google Places API
                // For now, create mock data
                val mockPlaces = createMockNearbyPlaces()
                allNearbyPlaces = mockPlaces
                
                _placesState.value = _placesState.value.copy(
                    nearbyPlaces = mockPlaces,
                    isLoading = false
                )
            } catch (e: Exception) {
                _placesState.value = _placesState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Failed to find nearby places"
                )
            }
        }
    }
    
    fun searchPlaces(query: String) {
        val filteredPlaces = if (query.isEmpty()) {
            allNearbyPlaces
        } else {
            allNearbyPlaces.filter { place ->
                place.name.contains(query, ignoreCase = true) ||
                place.category.contains(query, ignoreCase = true)
            }
        }
        
        _placesState.value = _placesState.value.copy(
            nearbyPlaces = filteredPlaces,
            searchQuery = query
        )
    }
    
    fun selectPlace(place: NearbyPlace) {
        _placesState.value = _placesState.value.copy(selectedPlace = place)
        // TODO: Navigate to place detail or add to saved places
    }
    
    private fun createMockNearbyPlaces(): List<NearbyPlace> {
        return listOf(
            NearbyPlace(
                id = "1",
                name = "Starbucks Coffee",
                category = "Cafe",
                distance = 150,
                latitude = 37.7749,
                longitude = -122.4194
            ),
            NearbyPlace(
                id = "2",
                name = "Golden Gate Park",
                category = "Park",
                distance = 300,
                latitude = 37.7694,
                longitude = -122.4862
            ),
            NearbyPlace(
                id = "3",
                name = "Whole Foods Market",
                category = "Grocery Store",
                distance = 250,
                latitude = 37.7849,
                longitude = -122.4094
            ),
            NearbyPlace(
                id = "4",
                name = "Museum of Modern Art",
                category = "Museum",
                distance = 500,
                latitude = 37.7857,
                longitude = -122.4011
            ),
            NearbyPlace(
                id = "5",
                name = "Ferry Building Marketplace",
                category = "Shopping",
                distance = 400,
                latitude = 37.7955,
                longitude = -122.3937
            )
        )
    }
}

data class PlacesState(
    val nearbyPlaces: List<NearbyPlace> = emptyList(),
    val selectedPlace: NearbyPlace? = null,
    val searchQuery: String = "",
    val isLoading: Boolean = false,
    val error: String? = null
)