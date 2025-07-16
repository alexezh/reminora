package com.reminora.android.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import androidx.room.Delete
import kotlinx.coroutines.flow.Flow

@Dao
interface UserListDao {
    @Query("SELECT * FROM user_lists WHERE user_id = :userId ORDER BY created_at DESC")
    fun getUserLists(userId: String): Flow<List<UserList>>
    
    @Query("SELECT * FROM user_lists WHERE id = :listId")
    suspend fun getUserListById(listId: String): UserList?
    
    @Query("SELECT * FROM user_lists WHERE name = :name AND user_id = :userId")
    suspend fun getUserListByName(name: String, userId: String): UserList?
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertUserList(userList: UserList)
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertUserLists(userLists: List<UserList>)
    
    @Update
    suspend fun updateUserList(userList: UserList)
    
    @Delete
    suspend fun deleteUserList(userList: UserList)
    
    @Query("DELETE FROM user_lists WHERE id = :listId")
    suspend fun deleteUserListById(listId: String)
    
    @Query("DELETE FROM user_lists WHERE user_id = :userId")
    suspend fun deleteAllUserLists(userId: String)
}