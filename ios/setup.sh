#!/bin/bash

# Reminora iOS Setup Script

echo "🏗️  Setting up Reminora iOS project..."

# Check if GoogleService-Info.plist exists
if [ ! -f "reminora/GoogleService-Info.plist" ]; then
    echo "❌ GoogleService-Info.plist not found!"
    echo "📋 Please follow these steps:"
    echo "1. Download GoogleService-Info.plist from Firebase Console"
    echo "2. Copy it to ios/reminora/GoogleService-Info.plist"
    echo "3. Re-run this script"
    echo ""
    echo "📖 See SETUP.md for detailed instructions"
    exit 1
fi

# Extract CLIENT_ID from GoogleService-Info.plist
CLIENT_ID=$(plutil -extract CLIENT_ID raw reminora/GoogleService-Info.plist 2>/dev/null)
REVERSED_CLIENT_ID=$(plutil -extract REVERSED_CLIENT_ID raw reminora/GoogleService-Info.plist 2>/dev/null)

if [ -z "$CLIENT_ID" ] || [ -z "$REVERSED_CLIENT_ID" ]; then
    echo "❌ Could not extract CLIENT_ID from GoogleService-Info.plist"
    echo "📋 Please ensure the file is valid and contains required keys"
    exit 1
fi

echo "✅ Found Google OAuth configuration"
echo "📱 CLIENT_ID: ${CLIENT_ID:0:20}..."
echo "🔗 REVERSED_CLIENT_ID: ${REVERSED_CLIENT_ID:0:30}..."

# Check if Info.plist needs URL scheme
if ! grep -q "$REVERSED_CLIENT_ID" reminora/Info.plist; then
    echo "⚠️  URL scheme not found in Info.plist"
    echo "📋 Please add the following to reminora/Info.plist:"
    echo ""
    echo "<key>CFBundleURLTypes</key>"
    echo "<array>"
    echo "    <dict>"
    echo "        <key>CFBundleURLName</key>"
    echo "        <string>GoogleSignIn</string>"
    echo "        <key>CFBundleURLSchemes</key>"
    echo "        <array>"
    echo "            <string>$REVERSED_CLIENT_ID</string>"
    echo "        </array>"
    echo "    </dict>"
    echo "</array>"
    echo ""
else
    echo "✅ URL scheme configured in Info.plist"
fi

echo "🎉 Setup complete! Ready to build in Xcode."