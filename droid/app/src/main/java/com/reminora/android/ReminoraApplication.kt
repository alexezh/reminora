package com.reminora.android

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class ReminoraApplication : Application() {
    override fun onCreate() {
        super.onCreate()
    }
}