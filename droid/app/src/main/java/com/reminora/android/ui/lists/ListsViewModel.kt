package com.reminora.android.ui.lists

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.reminora.android.ui.quicklist.QuickListService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ListsViewModel @Inject constructor(
    private val quickListService: QuickListService
) : ViewModel() {
    
    private val _listsState = MutableStateFlow(ListsState())
    val listsState: StateFlow<ListsState> = _listsState.asStateFlow()
    
    // Mock user ID for demo
    private val userId = "demo_user"
    
    init {
        loadLists()
    }
    
    private fun loadLists() {
        viewModelScope.launch {
            _listsState.value = _listsState.value.copy(isLoading = true)
            
            // TODO: Load actual lists from database
            // For now, create mock data including system lists like iOS
            val mockLists = listOf(
                SavedList(
                    id = "shared",
                    name = "Shared",
                    itemCount = 0,
                    createdAt = System.currentTimeMillis()
                ),
                SavedList(
                    id = "quick",
                    name = "Quick",
                    itemCount = 0,
                    createdAt = System.currentTimeMillis()
                )
            )
            
            _listsState.value = _listsState.value.copy(
                lists = mockLists,
                isLoading = false
            )
        }
    }
    
    fun createList(name: String) {
        viewModelScope.launch {
            // TODO: Create list in database
            val newList = SavedList(
                id = System.currentTimeMillis().toString(),
                name = name,
                itemCount = 0,
                createdAt = System.currentTimeMillis()
            )
            
            val updatedLists = _listsState.value.lists + newList
            _listsState.value = _listsState.value.copy(lists = updatedLists)
        }
    }
    
    fun selectList(list: SavedList) {
        _listsState.value = _listsState.value.copy(selectedList = list)
        // TODO: Navigate to list detail view
    }
    
    fun deleteList(list: SavedList) {
        viewModelScope.launch {
            // TODO: Delete list from database
            val updatedLists = _listsState.value.lists.filter { it.id != list.id }
            _listsState.value = _listsState.value.copy(lists = updatedLists)
        }
    }
    
    // MARK: - Quick List Actions
    
    fun createListFromQuickList(newListName: String) {
        viewModelScope.launch {
            val success = quickListService.createListFromQuickList(newListName, userId)
            if (success) {
                loadLists() // Refresh the lists to show the new list
            }
        }
    }
    
    fun moveQuickListToExistingList(targetListId: String) {
        viewModelScope.launch {
            val success = quickListService.moveQuickListToExistingList(targetListId, userId)
            if (success) {
                loadLists() // Refresh the lists
            }
        }
    }
    
    fun clearQuickList() {
        viewModelScope.launch {
            val success = quickListService.clearQuickList(userId)
            if (success) {
                loadLists() // Refresh the lists
            }
        }
    }
    
    fun isQuickList(list: SavedList): Boolean {
        return list.name == "Quick"
    }
}

data class ListsState(
    val lists: List<SavedList> = emptyList(),
    val selectedList: SavedList? = null,
    val isLoading: Boolean = false,
    val error: String? = null
)