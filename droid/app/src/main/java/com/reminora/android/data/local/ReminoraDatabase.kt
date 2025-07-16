package com.reminora.android.data.local

import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import android.content.Context

@Database(
    entities = [
        Place::class,
        Comment::class,
        UserList::class,
        ListItem::class,
        PhotoLocationCache::class
    ],
    version = 1,
    exportSchema = false
)
@TypeConverters(Converters::class)
abstract class ReminoraDatabase : RoomDatabase() {
    abstract fun placeDao(): PlaceDao
    abstract fun commentDao(): CommentDao
    abstract fun userListDao(): UserListDao
    abstract fun listItemDao(): ListItemDao
    
    companion object {
        @Volatile
        private var INSTANCE: ReminoraDatabase? = null
        
        fun getDatabase(context: Context): ReminoraDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    ReminoraDatabase::class.java,
                    "reminora_database"
                ).build()
                INSTANCE = instance
                instance
            }
        }
    }
}