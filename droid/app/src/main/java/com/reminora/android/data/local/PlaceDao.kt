package com.reminora.android.data.local

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface PlaceDao {
    @Query("SELECT * FROM places ORDER BY date_added DESC")
    fun getAllPlaces(): Flow<List<Place>>
    
    @Query("SELECT * FROM places WHERE id = :id")
    suspend fun getPlaceById(id: Long): Place?
    
    @Query("SELECT * FROM places WHERE cloud_id = :cloudId")
    suspend fun getPlaceByCloudId(cloudId: String): Place?
    
    @Query("SELECT * FROM places WHERE post LIKE '%' || :searchText || '%'")
    fun searchPlaces(searchText: String): Flow<List<Place>>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPlace(place: Place): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPlaces(places: List<Place>)
    
    @Update
    suspend fun updatePlace(place: Place)
    
    @Delete
    suspend fun deletePlace(place: Place)
    
    @Query("DELETE FROM places WHERE id = :id")
    suspend fun deletePlaceById(id: Long)
    
    @Query("SELECT COUNT(*) FROM places")
    suspend fun getPlaceCount(): Int
}