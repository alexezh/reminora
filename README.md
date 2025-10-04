# Reminora

Reminora began as a geotagged photo sharing app with list management and social features.
It has since evolved into a focused, privacy-friendly tool for everyday photo and video management, built around the idea of lists — lightweight, flexible collections inspired by Lightroom Quick Lists. 

Reminora helps you capture, organize, and rediscover moments without the overhead of traditional gallery apps or the complexity of pro editors.

- List-based organization: create quick, ad-hoc collections for trips, themes, or projects.
- Integrated editing tools: more capable than stock photo apps, yet simpler than GIMP.
- Geotag support: explore photos by place and memory context.
- Lightweight and private: built for personal use, not social media.

Reminora is a second iteration of [kouki2](https://github.com/alexezh/kouki2) focusing on phone as a primary device

## Features

- Photo sharing with location data
- Interactive map interface
- List management (Quick lists, Shared lists)
- Comments and social features
- Deep linking for sharing
- AI similar photo detection
- OAuth authentication (Apple, Google)
- iOS and Android apps
- Cloudflare Workers backend

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd reminora
   ```

2. **Setup Firebase** (Required for OAuth)
   - Follow instructions in [SETUP.md](SETUP.md)
   - Download `GoogleService-Info.plist` and place in `ios/reminora/`
   - Download `google-services.json` and place in `droid/app/`

3. **iOS Development**
   ```bash
   cd ios
   ./setup.sh  # Validates Firebase setup
   open reminora.xcodeproj
   ```

4. **Android Development**
   ```bash
   cd droid
   # Open in Android Studio
   ```

5. **Backend Development**
   ```bash
   cd backend
   npm install
   wrangler dev
   ```

## Architecture

- **iOS**: SwiftUI + Core Data
- **Android**: Jetpack Compose + Room
- **Backend**: Cloudflare Workers + D1
- **Auth**: Firebase Authentication
- **Maps**: Native MapKit/Google Maps

## Security

- 🔐 OAuth tokens stored securely in Keychain
- 🚫 No sensitive files committed to git
- 🔑 Environment variables for API keys
- 🛡️ Firebase security rules enabled

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Note**: This project requires Firebase setup for OAuth functionality. See [SETUP.md](SETUP.md) for detailed configuration instructions.
