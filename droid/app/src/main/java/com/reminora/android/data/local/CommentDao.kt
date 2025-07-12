package com.reminora.android.data.local

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface CommentDao {
    @Query("SELECT * FROM comments ORDER BY created_at DESC")
    fun getAllComments(): Flow<List<Comment>>
    
    @Query("SELECT * FROM comments WHERE target_photo_id = :photoId ORDER BY created_at ASC")
    fun getCommentsForPhoto(photoId: String): Flow<List<Comment>>
    
    @Query("SELECT * FROM comments WHERE target_user_id = :userId ORDER BY created_at DESC")
    fun getCommentsForUser(userId: String): Flow<List<Comment>>
    
    @Query("SELECT * FROM comments WHERE id = :id")
    suspend fun getCommentById(id: String): Comment?
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertComment(comment: Comment)
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertComments(comments: List<Comment>)
    
    @Update
    suspend fun updateComment(comment: Comment)
    
    @Delete
    suspend fun deleteComment(comment: Comment)
    
    @Query("DELETE FROM comments WHERE id = :id")
    suspend fun deleteCommentById(id: String)
}