package com.reminora.android.ui.map

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.reminora.android.data.local.Place
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class PinBrowserViewModel @Inject constructor(
    // TODO: Inject repositories
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(PinBrowserUiState())
    val uiState: StateFlow<PinBrowserUiState> = _uiState.asStateFlow()
    
    init {
        loadPlaces()
        loadLists()
    }
    
    fun searchPlaces(query: String) {
        _uiState.value = _uiState.value.copy(searchQuery = query)
        filterPlaces()
    }
    
    fun selectList(listId: String) {
        _uiState.value = _uiState.value.copy(selectedListId = listId)
        filterPlaces()
    }
    
    fun selectPlace(place: Place) {
        _uiState.value = _uiState.value.copy(selectedPlace = place)
    }
    
    fun showAddPhoto() {
        // TODO: Implement photo library opening
    }
    
    private fun loadPlaces() {
        viewModelScope.launch {
            try {
                _uiState.value = _uiState.value.copy(isLoading = true)
                
                // TODO: Load actual places from repository
                val mockPlaces = createMockPlaces()
                
                _uiState.value = _uiState.value.copy(
                    allPlaces = mockPlaces,
                    isLoading = false
                )
                filterPlaces()
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message
                )
            }
        }
    }
    
    private fun loadLists() {
        viewModelScope.launch {
            // TODO: Load actual lists from repository
            val mockLists = listOf(
                UserList("all", "All Places"),
                UserList("quick", "Quick"),
                UserList("favorites", "Favorites"),
                UserList("recent", "Recent")
            )
            
            _uiState.value = _uiState.value.copy(availableLists = mockLists)
        }
    }
    
    private fun filterPlaces() {
        val currentState = _uiState.value
        var filtered = currentState.allPlaces
        
        // Filter by selected list
        if (currentState.selectedListId != "all") {
            // TODO: Implement actual list filtering
            filtered = filtered.take(3) // Mock filtering
        }
        
        // Filter by search query
        if (currentState.searchQuery.isNotBlank()) {
            filtered = filtered.filter { place ->
                place.post?.contains(currentState.searchQuery, ignoreCase = true) == true ||
                place.id.toString().contains(currentState.searchQuery, ignoreCase = true)
            }
        }
        
        val selectedListName = currentState.availableLists
            .find { it.id == currentState.selectedListId }?.name ?: "All Places"
        
        _uiState.value = currentState.copy(
            filteredPlaces = filtered,
            selectedListName = selectedListName
        )
    }
    
    private fun createMockPlaces(): List<Place> {
        return (1..10).map { i ->
            Place(
                id = i.toLong(),
                post = "Mock place $i with some description",
                imageData = ByteArray(1), // Mock image data
                location = null, // TODO: Add actual location data
                dateAdded = java.util.Date(System.currentTimeMillis() - (i * 1000000))
            )
        }
    }
}

data class PinBrowserUiState(
    val allPlaces: List<Place> = emptyList(),
    val filteredPlaces: List<Place> = emptyList(),
    val selectedPlace: Place? = null,
    val availableLists: List<UserList> = emptyList(),
    val selectedListId: String = "all",
    val selectedListName: String = "All Places",
    val searchQuery: String = "",
    val isLoading: Boolean = false,
    val error: String? = null
)

data class UserList(
    val id: String,
    val name: String
)