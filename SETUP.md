# Reminora Setup Instructions

## Prerequisites
- Xcode 14.0 or later
- iOS 16.0 or later
- Google Firebase account
- Android Studio (for Android version)

## iOS Setup

### 1. Firebase Configuration
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing project
3. Add iOS app with bundle ID: `com.yourcompany.reminora`
4. Download `GoogleService-Info.plist`
5. Copy it to `ios/reminora/GoogleService-Info.plist`

### 2. Google Sign-In Setup
1. In Firebase Console, go to Authentication > Sign-in method
2. Enable Google sign-in
3. Add your bundle ID to authorized domains
4. Copy the `REVERSED_CLIENT_ID` from GoogleService-Info.plist
5. Add URL scheme to `ios/reminora/Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLName</key>
           <string>GoogleSignIn</string>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>YOUR_REVERSED_CLIENT_ID_HERE</string>
           </array>
       </dict>
   </array>
   ```

### 3. Build and Run
1. Open `ios/reminora.xcodeproj` in Xcode
2. Select your development team
3. Build and run

## Android Setup

### 1. Firebase Configuration
1. In Firebase Console, add Android app
2. Use package name: `com.yourcompany.reminora`
3. Download `google-services.json`
4. Copy it to `droid/app/google-services.json`

### 2. Build and Run
1. Open `droid` folder in Android Studio
2. Sync project
3. Build and run

## Backend Setup

### 1. Cloudflare Workers
1. Install Wrangler CLI: `npm install -g wrangler`
2. Login: `wrangler login`
3. Create D1 database: `wrangler d1 create reminora-db`
4. Update `backend/wrangler.toml` with database ID
5. Deploy: `wrangler publish`

### 2. Environment Variables
Create `backend/.env`:
```
DATABASE_ID=your-d1-database-id
JWT_SECRET=your-jwt-secret-key
```

## Security Notes
- Never commit `GoogleService-Info.plist` or `google-services.json`
- Use environment variables for sensitive data
- Rotate API keys regularly
- Enable Firebase security rules