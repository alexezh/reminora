package com.reminora.android.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.ColumnInfo
import java.util.Date

@Entity(tableName = "places")
data class Place(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    
    @ColumnInfo(name = "image_data")
    val imageData: ByteArray,
    
    @ColumnInfo(name = "location")
    val location: ByteArray? = null,
    
    @ColumnInfo(name = "date_added")
    val dateAdded: Date,
    
    @ColumnInfo(name = "post")
    val post: String? = null,
    
    @ColumnInfo(name = "url")
    val url: String? = null,
    
    @ColumnInfo(name = "cloud_id")
    val cloudId: String? = null,
    
    @ColumnInfo(name = "cloud_synced_at")
    val cloudSyncedAt: Date? = null
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as Place

        if (id != other.id) return false
        if (!imageData.contentEquals(other.imageData)) return false
        if (location != null) {
            if (other.location == null) return false
            if (!location.contentEquals(other.location)) return false
        } else if (other.location != null) return false
        if (dateAdded != other.dateAdded) return false
        if (post != other.post) return false
        if (url != other.url) return false
        if (cloudId != other.cloudId) return false
        if (cloudSyncedAt != other.cloudSyncedAt) return false

        return true
    }

    override fun hashCode(): Int {
        var result = id.hashCode()
        result = 31 * result + imageData.contentHashCode()
        result = 31 * result + (location?.contentHashCode() ?: 0)
        result = 31 * result + dateAdded.hashCode()
        result = 31 * result + (post?.hashCode() ?: 0)
        result = 31 * result + (url?.hashCode() ?: 0)
        result = 31 * result + (cloudId?.hashCode() ?: 0)
        result = 31 * result + (cloudSyncedAt?.hashCode() ?: 0)
        return result
    }
}