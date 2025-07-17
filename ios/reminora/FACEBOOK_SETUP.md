# Facebook Configuration Setup

## Overview
Facebook configuration has been moved to a separate `Facebook-Info.plist` file for security reasons. This file is ignored by git to prevent sensitive information from being committed to the repository.

## Setup Instructions

### 1. Create Facebook-Info.plist
Copy the template file to create your configuration:
```bash
cp Facebook-Info.plist.template Facebook-Info.plist
```

### 2. Get Facebook App Credentials
1. Go to [Facebook Developers Console](https://developers.facebook.com)
2. Select your app or create a new one
3. Go to **Settings** → **Basic**
4. Copy the following values:
   - **App ID** 
   - **App Secret** (use as Client Token)

### 3. Update Facebook-Info.plist
Edit `Facebook-Info.plist` and replace the placeholder values:
```xml
<key>FacebookAppID</key>
<string>YOUR_ACTUAL_APP_ID</string>
<key>FacebookClientToken</key>
<string>YOUR_ACTUAL_CLIENT_TOKEN</string>
```

### 4. Update URL Scheme (if needed)
If you're using a different Facebook App ID, update the URL scheme in `Info.plist`:
```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>fb{YOUR_APP_ID}</string>
</array>
```

## Security Notes
- ✅ `Facebook-Info.plist` is in `.gitignore` 
- ✅ Template file is committed for reference
- ✅ Real credentials are never committed to git
- ⚠️ Never commit actual Facebook credentials

## Files Structure
```
ios/reminora/
├── Facebook-Info.plist          # Your actual config (gitignored)
├── Facebook-Info.plist.template # Template for other developers
├── FACEBOOK_SETUP.md           # This setup guide
└── Info.plist                  # Main app config (no sensitive data)
```

## Troubleshooting
- Ensure `Facebook-Info.plist` is in the same directory as `Info.plist`
- Check Xcode console for "Facebook SDK configured successfully" message
- Verify the URL scheme matches your App ID: `fb{APP_ID}`