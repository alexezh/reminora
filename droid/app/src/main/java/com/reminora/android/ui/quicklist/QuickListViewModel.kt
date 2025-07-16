package com.reminora.android.ui.quicklist

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.reminora.android.data.local.ListItem
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class QuickListViewModel @Inject constructor(
    private val quickListService: QuickListService
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(QuickListUiState())
    val uiState: StateFlow<QuickListUiState> = _uiState.asStateFlow()
    
    // Mock user ID for demo
    private val userId = "demo_user"
    
    init {
        loadQuickListItems()
    }
    
    private fun loadQuickListItems() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            
            try {
                val items = quickListService.getQuickListItemsSync(userId)
                _uiState.value = _uiState.value.copy(
                    items = items,
                    isLoading = false
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message
                )
            }
        }
    }
    
    fun createListFromQuickList(newListName: String) {
        viewModelScope.launch {
            val success = quickListService.createListFromQuickList(newListName, userId)
            if (success) {
                loadQuickListItems()
            }
        }
    }
    
    fun moveQuickListToExistingList(targetListId: String) {
        viewModelScope.launch {
            val success = quickListService.moveQuickListToExistingList(targetListId, userId)
            if (success) {
                loadQuickListItems()
            }
        }
    }
    
    fun clearQuickList() {
        viewModelScope.launch {
            val success = quickListService.clearQuickList(userId)
            if (success) {
                loadQuickListItems()
            }
        }
    }
}

data class QuickListUiState(
    val items: List<ListItem> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)