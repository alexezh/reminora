package com.reminora.android.di

import android.content.Context
import com.reminora.android.data.local.ReminoraDatabase
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
}