package com.reminora.android.data.repository

import com.reminora.android.data.local.UserList
import com.reminora.android.data.local.ListItem
import com.reminora.android.data.local.Place
import com.reminora.android.data.local.UserListDao
import com.reminora.android.data.local.ListItemDao
import com.reminora.android.data.local.PlaceDao
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import java.util.Date
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class QuickListRepository @Inject constructor(
    private val userListDao: UserListDao,
    private val listItemDao: ListItemDao,
    private val placeDao: PlaceDao
) {
    companion object {
        const val QUICK_LIST_NAME = "Quick"
    }
    
    // MARK: - Quick List Management
    
    suspend fun getOrCreateQuickList(userId: String): UserList {
        return userListDao.getUserListByName(QUICK_LIST_NAME, userId)
            ?: createQuickList(userId)
    }
    
    private suspend fun createQuickList(userId: String): UserList {
        val quickList = UserList(
            id = UUID.randomUUID().toString(),
            name = QUICK_LIST_NAME,
            userId = userId,
            createdAt = Date()
        )
        userListDao.insertUserList(quickList)
        return quickList
    }
    
    fun getUserLists(userId: String): Flow<List<UserList>> {
        return userListDao.getUserLists(userId)
    }
    
    suspend fun getUserListById(listId: String): UserList? {
        return userListDao.getUserListById(listId)
    }
    
    suspend fun createUserList(name: String, userId: String): UserList {
        val userList = UserList(
            id = UUID.randomUUID().toString(),
            name = name,
            userId = userId,
            createdAt = Date()
        )
        userListDao.insertUserList(userList)
        return userList
    }
    
    // MARK: - Quick List Items
    
    fun getQuickListItems(userId: String): Flow<List<ListItem>> {
        return combine(
            userListDao.getUserLists(userId),
            listItemDao.getListItems("")
        ) { userLists, _ ->
            val quickList = userLists.find { it.name == QUICK_LIST_NAME }
            if (quickList != null) {
                // Get list items for the quick list
                // Note: This is a simplified approach - in a real app you'd want to use a proper Flow
                emptyList()
            } else {
                emptyList()
            }
        }
    }
    
    suspend fun getQuickListItemsSync(userId: String): List<ListItem> {
        val quickList = getOrCreateQuickList(userId)
        return listItemDao.getListItems(quickList.id).let { flow ->
            // For now, return empty list - this would need proper Flow handling
            emptyList()
        }
    }
    
    // MARK: - Photo Management
    
    suspend fun isPhotoInQuickList(photoId: String, userId: String): Boolean {
        val quickList = getOrCreateQuickList(userId)
        return listItemDao.isPlaceInList(quickList.id, photoId) > 0
    }
    
    suspend fun addPhotoToQuickList(photoId: String, userId: String): Boolean {
        return try {
            val quickList = getOrCreateQuickList(userId)
            
            // Check if already exists
            if (listItemDao.isPlaceInList(quickList.id, photoId) > 0) {
                return true
            }
            
            val listItem = ListItem(
                id = UUID.randomUUID().toString(),
                listId = quickList.id,
                placeId = photoId,
                addedAt = Date()
            )
            listItemDao.insertListItem(listItem)
            true
        } catch (e: Exception) {
            false
        }
    }
    
    suspend fun removePhotoFromQuickList(photoId: String, userId: String): Boolean {
        return try {
            val quickList = getOrCreateQuickList(userId)
            listItemDao.deleteListItemByPlaceId(quickList.id, photoId)
            true
        } catch (e: Exception) {
            false
        }
    }
    
    suspend fun togglePhotoInQuickList(photoId: String, userId: String): Boolean {
        return if (isPhotoInQuickList(photoId, userId)) {
            removePhotoFromQuickList(photoId, userId)
        } else {
            addPhotoToQuickList(photoId, userId)
        }
    }
    
    // MARK: - Pin Management
    
    suspend fun isPinInQuickList(place: Place, userId: String): Boolean {
        val quickList = getOrCreateQuickList(userId)
        return listItemDao.isPlaceInList(quickList.id, place.id) > 0
    }
    
    suspend fun addPinToQuickList(place: Place, userId: String): Boolean {
        return try {
            val quickList = getOrCreateQuickList(userId)
            
            // Check if already exists
            if (listItemDao.isPlaceInList(quickList.id, place.id) > 0) {
                return true
            }
            
            val listItem = ListItem(
                id = UUID.randomUUID().toString(),
                listId = quickList.id,
                placeId = place.id,
                addedAt = Date()
            )
            listItemDao.insertListItem(listItem)
            true
        } catch (e: Exception) {
            false
        }
    }
    
    suspend fun removePinFromQuickList(place: Place, userId: String): Boolean {
        return try {
            val quickList = getOrCreateQuickList(userId)
            listItemDao.deleteListItemByPlaceId(quickList.id, place.id)
            true
        } catch (e: Exception) {
            false
        }
    }
    
    suspend fun togglePinInQuickList(place: Place, userId: String): Boolean {
        return if (isPinInQuickList(place, userId)) {
            removePinFromQuickList(place, userId)
        } else {
            addPinToQuickList(place, userId)
        }
    }
    
    // MARK: - Quick List Actions
    
    suspend fun createListFromQuickList(newListName: String, userId: String): Boolean {
        return try {
            val quickList = getOrCreateQuickList(userId)
            val newList = createUserList(newListName, userId)
            
            // Move all items from Quick List to new list
            listItemDao.moveItemsToNewList(quickList.id, newList.id)
            
            true
        } catch (e: Exception) {
            false
        }
    }
    
    suspend fun moveQuickListToExistingList(targetListId: String, userId: String): Boolean {
        return try {
            val quickList = getOrCreateQuickList(userId)
            listItemDao.moveItemsToNewList(quickList.id, targetListId)
            true
        } catch (e: Exception) {
            false
        }
    }
    
    suspend fun clearQuickList(userId: String): Boolean {
        return try {
            val quickList = getOrCreateQuickList(userId)
            listItemDao.deleteAllListItems(quickList.id)
            true
        } catch (e: Exception) {
            false
        }
    }
    
    // MARK: - Place Operations
    
    suspend fun getPlaceById(placeId: String): Place? {
        return placeDao.getPlaceById(placeId)
    }
    
    suspend fun createPlaceFromPhoto(photoId: String, photoUri: String, userId: String): Place {
        val place = Place(
            id = UUID.randomUUID().toString(),
            url = "photo://$photoId", // Special marker for photos from library
            post = "Photo from library",
            dateAdded = Date(),
            latitude = null,
            longitude = null,
            imageData = null // Will be loaded asynchronously
        )
        placeDao.insertPlace(place)
        return place
    }
}