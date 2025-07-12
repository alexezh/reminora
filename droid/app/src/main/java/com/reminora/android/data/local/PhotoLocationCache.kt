package com.reminora.android.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.ColumnInfo
import java.util.Date

@Entity(tableName = "photo_location_cache")
data class PhotoLocationCache(
    @PrimaryKey
    @ColumnInfo(name = "photo_id")
    val photoId: String,
    
    @ColumnInfo(name = "location")
    val location: ByteArray? = null,
    
    @ColumnInfo(name = "last_updated")
    val lastUpdated: Date
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as PhotoLocationCache

        if (photoId != other.photoId) return false
        if (location != null) {
            if (other.location == null) return false
            if (!location.contentEquals(other.location)) return false
        } else if (other.location != null) return false
        if (lastUpdated != other.lastUpdated) return false

        return true
    }

    override fun hashCode(): Int {
        var result = photoId.hashCode()
        result = 31 * result + (location?.contentHashCode() ?: 0)
        result = 31 * result + lastUpdated.hashCode()
        return result
    }
}