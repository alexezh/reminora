package com.reminora.android

object DebugConfig {
    // Set to true to allow skipping authentication in debug builds
    // Change to false for production builds or when you want to test real auth
    const val ALLOW_SKIP_AUTH = true
    
    // Default mock user for skip auth mode
    const val MOCK_USER_ID = "debug_user_001"
    const val MOCK_USER_EMAIL = "debug@reminora.dev"
    const val MOCK_USER_NAME = "Debug User"
    const val MOCK_USER_HANDLE = "debuguser"
    
    // You can also create build variants in build.gradle.kts:
    // debugImplementation vs releaseImplementation
    // or use BuildConfig.DEBUG once it's available at runtime
}