package com.reminora.android.di

import android.content.Context
import com.reminora.android.data.local.ReminoraDatabase
import com.reminora.android.data.local.UserListDao
import com.reminora.android.data.local.ListItemDao
import com.reminora.android.data.local.PlaceDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    
    @Provides
    @Singleton
    fun provideReminoraDatabase(@ApplicationContext context: Context): ReminoraDatabase {
        return ReminoraDatabase.getDatabase(context)
    }
    
    @Provides
    fun provideUserListDao(database: ReminoraDatabase): UserListDao {
        return database.userListDao()
    }
    
    @Provides
    fun provideListItemDao(database: ReminoraDatabase): ListItemDao {
        return database.listItemDao()
    }
    
    @Provides
    fun providePlaceDao(database: ReminoraDatabase): PlaceDao {
        return database.placeDao()
    }
}