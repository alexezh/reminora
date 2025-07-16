package com.reminora.android.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import androidx.room.Delete
import kotlinx.coroutines.flow.Flow

@Dao
interface ListItemDao {
    @Query("SELECT * FROM list_items WHERE list_id = :listId ORDER BY added_at DESC")
    fun getListItems(listId: String): Flow<List<ListItem>>
    
    @Query("SELECT * FROM list_items WHERE id = :itemId")
    suspend fun getListItemById(itemId: String): ListItem?
    
    @Query("SELECT * FROM list_items WHERE list_id = :listId AND place_id = :placeId")
    suspend fun getListItemByPlaceId(listId: String, placeId: String): ListItem?
    
    @Query("SELECT COUNT(*) FROM list_items WHERE list_id = :listId AND place_id = :placeId")
    suspend fun isPlaceInList(listId: String, placeId: String): Int
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertListItem(listItem: ListItem)
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertListItems(listItems: List<ListItem>)
    
    @Update
    suspend fun updateListItem(listItem: ListItem)
    
    @Delete
    suspend fun deleteListItem(listItem: ListItem)
    
    @Query("DELETE FROM list_items WHERE id = :itemId")
    suspend fun deleteListItemById(itemId: String)
    
    @Query("DELETE FROM list_items WHERE list_id = :listId")
    suspend fun deleteAllListItems(listId: String)
    
    @Query("DELETE FROM list_items WHERE list_id = :listId AND place_id = :placeId")
    suspend fun deleteListItemByPlaceId(listId: String, placeId: String)
    
    @Query("UPDATE list_items SET list_id = :newListId WHERE list_id = :oldListId")
    suspend fun moveItemsToNewList(oldListId: String, newListId: String)
}