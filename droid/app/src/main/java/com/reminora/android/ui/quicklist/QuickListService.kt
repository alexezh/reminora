package com.reminora.android.ui.quicklist

import com.reminora.android.data.local.Place
import com.reminora.android.data.local.ListItem
import com.reminora.android.data.repository.QuickListRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class QuickListService @Inject constructor(
    private val quickListRepository: QuickListRepository
) {
    
    // StateFlow for reactive updates across the app
    private val _quickListUpdated = MutableStateFlow(0)
    val quickListUpdated: StateFlow<Int> = _quickListUpdated.asStateFlow()
    
    // MARK: - Photo Management
    
    suspend fun isPhotoInQuickList(photoId: String, userId: String): Boolean {
        return quickListRepository.isPhotoInQuickList(photoId, userId)
    }
    
    suspend fun addPhotoToQuickList(photoId: String, userId: String): Boolean {
        val success = quickListRepository.addPhotoToQuickList(photoId, userId)
        if (success) {
            notifyQuickListChanged()
        }
        return success
    }
    
    suspend fun removePhotoFromQuickList(photoId: String, userId: String): Boolean {
        val success = quickListRepository.removePhotoFromQuickList(photoId, userId)
        if (success) {
            notifyQuickListChanged()
        }
        return success
    }
    
    suspend fun togglePhotoInQuickList(photoId: String, userId: String): Boolean {
        val success = quickListRepository.togglePhotoInQuickList(photoId, userId)
        if (success) {
            notifyQuickListChanged()
        }
        return success
    }
    
    // MARK: - Pin Management
    
    suspend fun isPinInQuickList(place: Place, userId: String): Boolean {
        return quickListRepository.isPinInQuickList(place, userId)
    }
    
    suspend fun addPinToQuickList(place: Place, userId: String): Boolean {
        val success = quickListRepository.addPinToQuickList(place, userId)
        if (success) {
            notifyQuickListChanged()
        }
        return success
    }
    
    suspend fun removePinFromQuickList(place: Place, userId: String): Boolean {
        val success = quickListRepository.removePinFromQuickList(place, userId)
        if (success) {
            notifyQuickListChanged()
        }
        return success
    }
    
    suspend fun togglePinInQuickList(place: Place, userId: String): Boolean {
        val success = quickListRepository.togglePinInQuickList(place, userId)
        if (success) {
            notifyQuickListChanged()
        }
        return success
    }
    
    // MARK: - Quick List Content
    
    fun getQuickListItems(userId: String): Flow<List<ListItem>> {
        return quickListRepository.getQuickListItems(userId)
    }
    
    suspend fun getQuickListItemsSync(userId: String): List<ListItem> {
        return quickListRepository.getQuickListItemsSync(userId)
    }
    
    // MARK: - Quick List Actions
    
    suspend fun createListFromQuickList(newListName: String, userId: String): Boolean {
        val success = quickListRepository.createListFromQuickList(newListName, userId)
        if (success) {
            notifyQuickListChanged()
        }
        return success
    }
    
    suspend fun moveQuickListToExistingList(targetListId: String, userId: String): Boolean {
        val success = quickListRepository.moveQuickListToExistingList(targetListId, userId)
        if (success) {
            notifyQuickListChanged()
        }
        return success
    }
    
    suspend fun clearQuickList(userId: String): Boolean {
        val success = quickListRepository.clearQuickList(userId)
        if (success) {
            notifyQuickListChanged()
        }
        return success
    }
    
    // MARK: - Utility Methods
    
    suspend fun getPlaceById(placeId: String): Place? {
        return quickListRepository.getPlaceById(placeId)
    }
    
    suspend fun createPlaceFromPhoto(photoId: String, photoUri: String, userId: String): Place {
        return quickListRepository.createPlaceFromPhoto(photoId, photoUri, userId)
    }
    
    fun getUserLists(userId: String) = quickListRepository.getUserLists(userId)
    
    suspend fun getUserListById(listId: String) = quickListRepository.getUserListById(listId)
    
    // MARK: - Private Methods
    
    private fun notifyQuickListChanged() {
        _quickListUpdated.value = _quickListUpdated.value + 1
    }
}