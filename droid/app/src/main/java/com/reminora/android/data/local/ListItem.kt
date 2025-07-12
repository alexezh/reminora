package com.reminora.android.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.ColumnInfo
import java.util.Date

@Entity(tableName = "list_items")
data class ListItem(
    @PrimaryKey
    val id: String,
    
    @ColumnInfo(name = "list_id")
    val listId: String,
    
    @ColumnInfo(name = "place_id")
    val placeId: String,
    
    @ColumnInfo(name = "added_at")
    val addedAt: Date,
    
    @ColumnInfo(name = "shared_by_user_id")
    val sharedByUserId: String? = null,
    
    @ColumnInfo(name = "shared_by_user_name")
    val sharedByUserName: String? = null,
    
    @ColumnInfo(name = "shared_link")
    val sharedLink: String? = null
)