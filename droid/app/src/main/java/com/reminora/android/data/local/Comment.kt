package com.reminora.android.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.ColumnInfo
import java.util.Date

@Entity(tableName = "comments")
data class Comment(
    @PrimaryKey
    val id: String,
    
    @ColumnInfo(name = "comment_text")
    val commentText: String,
    
    @ColumnInfo(name = "created_at")
    val createdAt: Date,
    
    @ColumnInfo(name = "from_user_id")
    val fromUserId: String,
    
    @ColumnInfo(name = "from_user_name")
    val fromUserName: String,
    
    @ColumnInfo(name = "from_user_handle")
    val fromUserHandle: String,
    
    @ColumnInfo(name = "to_user_id")
    val toUserId: String? = null,
    
    @ColumnInfo(name = "to_user_name")
    val toUserName: String? = null,
    
    @ColumnInfo(name = "to_user_handle")
    val toUserHandle: String? = null,
    
    @ColumnInfo(name = "target_photo_id")
    val targetPhotoId: String? = null,
    
    @ColumnInfo(name = "target_user_id")
    val targetUserId: String? = null,
    
    @ColumnInfo(name = "type")
    val type: String = "comment",
    
    @ColumnInfo(name = "is_reaction")
    val isReaction: Boolean = false,
    
    @ColumnInfo(name = "cloud_id")
    val cloudId: String? = null
)