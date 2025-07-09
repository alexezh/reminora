# Reminora Android App

Android version of the Reminora photo sharing app, built with modern Android development practices.

## 🏗️ Architecture

- **MVVM** - Model-View-ViewModel pattern
- **Repository Pattern** - Data layer abstraction
- **Hilt** - Dependency injection
- **Jetpack Compose** - Modern UI toolkit
- **Room** - Local database (planned)
- **Retrofit** - API client
- **Coroutines** - Asynchronous programming

## 🛠️ Tech Stack

- **Language**: Kotlin
- **UI**: Jetpack Compose
- **Navigation**: Navigation Compose
- **State Management**: StateFlow + ViewModel
- **Dependency Injection**: Hilt
- **Networking**: Retrofit + OkHttp
- **Image Loading**: Coil
- **Camera**: CameraX
- **Maps**: Google Maps SDK
- **Authentication**: Google Play Services

## 📱 Features

### ✅ Implemented
- OAuth authentication UI
- Home timeline with mock data
- Material 3 design system
- Navigation structure
- Repository pattern setup

### 🔄 In Development
- Google OAuth integration
- Camera functionality
- Photo upload
- Map view
- Real API integration

### 📋 Planned
- Follow/unfollow system
- User profiles
- Offline support
- Push notifications
- Photo editing

## 🚀 Getting Started

### Prerequisites
- Android Studio Hedgehog (2023.1.1) or later
- JDK 8 or later
- Android SDK 24+

### Setup
1. Clone the repository
2. Open `droid/` directory in Android Studio
3. Add Google Maps API key to `strings.xml`
4. Configure OAuth credentials
5. Build and run

### API Configuration
Update the API base URL in `ApiService.kt`:
```kotlin
private const val BASE_URL = "https://reminora-backend.reminora.workers.dev/"
```

## 🔧 Build Configuration

The app uses Gradle with Kotlin DSL:
- **Minimum SDK**: 24 (Android 7.0)
- **Target SDK**: 34 (Android 14)
- **Compile SDK**: 34

## 📁 Project Structure

```
app/src/main/java/com/reminora/android/
├── ui/
│   ├── auth/          # Authentication screens
│   ├── home/          # Home timeline
│   ├── camera/        # Camera functionality
│   ├── profile/       # User profiles
│   └── theme/         # Material 3 theme
├── data/
│   ├── api/           # API definitions
│   ├── repository/    # Data repositories
│   └── database/      # Room database
└── di/                # Dependency injection
```

## 🌐 API Integration

The app connects to the same Cloudflare Workers backend as the iOS app:
- **Authentication**: OAuth with session tokens
- **Photos**: Base64 encoded JSON storage
- **Social**: Follow/unfollow system
- **Timeline**: Pagination with waterlines

## 🔐 Security

- **OAuth**: Google Play Services authentication
- **Storage**: EncryptedSharedPreferences for tokens
- **Network**: HTTPS with certificate pinning
- **Permissions**: Runtime permission handling

## 🧪 Testing

- **Unit Tests**: ViewModels and repositories
- **UI Tests**: Compose testing
- **Integration Tests**: API calls
- **Manual Tests**: Device compatibility

## 🔄 iOS Sync

This Android app is kept in sync with the iOS version. See `SYNC_REFERENCE.md` for:
- Feature parity status
- Git commit references
- Implementation differences
- Sync procedures

## 📄 License

This project is part of the Reminora photo sharing app.

## 🤝 Contributing

1. Follow Android development best practices
2. Write tests for new features
3. Update sync reference when adding features
4. Follow Material 3 design guidelines