# Reminora Backend

Cloudflare Workers backend for the Reminora photo sharing app using D1 database.

## Features

- **Photo Storage**: Store photos as JSON blocks with metadata per account
- **Social Following**: Follow/unfollow users and manage follow lists
- **Timeline API**: Get photos since previous waterline for efficient syncing
- **User Management**: Account creation, profiles, and search
- **Privacy**: Photos only visible to followers

## API Endpoints

### Authentication
All endpoints require `X-Account-ID` header for authentication.

### Account Management
- `POST /api/accounts` - Create account
- `GET /api/accounts/:id` - Get account profile
- `PUT /api/accounts/:id` - Update account

### Photo Management
- `POST /api/photos` - Upload photo
- `GET /api/photos/timeline?since=<timestamp>&limit=<number>` - Get timeline
- `GET /api/photos/account/:accountId` - Get photos by account
- `GET /api/photos/:id` - Get single photo
- `DELETE /api/photos/:id` - Delete photo

### Follow System
- `POST /api/follows` - Follow user
- `DELETE /api/follows/:following_id` - Unfollow user
- `GET /api/follows/followers` - Get followers list
- `GET /api/follows/following` - Get following list
- `GET /api/follows/search?q=<query>` - Search users

## Setup

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Create D1 Database
```bash
# Create database
npx wrangler d1 create reminora-db

# Update wrangler.toml with the database ID returned above
```

### 3. Run Migrations
```bash
# Apply database schema
npx wrangler d1 execute reminora-db --file=./migrations/0001_initial.sql
```

### 4. Development
```bash
# Start local development server
npm run dev

# Deploy to Cloudflare Workers
npm run deploy
```

### 5. Update iOS App
Update the `baseURL` in `APIService.swift` to point to your deployed worker:
```swift
private let baseURL = "https://reminora-backend.your-worker.workers.dev"
```

## Database Schema

### Tables
- **accounts** - User accounts with profile info
- **photos** - Photo metadata and JSON data storage
- **follows** - Social follow relationships
- **photo_timeline** - Optimized timeline for feed generation

### Indexes
Optimized for:
- Timeline queries by account and timestamp
- Location-based photo searches
- Follow relationship lookups

## Data Models

### Photo JSON Structure
```json
{
  "image_data": "base64_encoded_image",
  "image_format": "jpeg",
  "created_at": 1703980800
}
```

### Account Structure
```json
{
  "id": "uuid",
  "username": "unique_username",
  "email": "user@example.com",
  "display_name": "Display Name",
  "bio": "User bio",
  "created_at": 1703980800
}
```

## iOS Integration

The iOS app includes:
- `APIService.swift` - Main API client
- `APIModels.swift` - Data models
- `CloudSyncService.swift` - Sync local Core Data with cloud

### Usage Example
```swift
// Upload photo
let photo = try await APIService.shared.uploadPhoto(
    imageData: imageData,
    location: location,
    caption: "My photo"
)

// Get timeline
let timeline = try await APIService.shared.getTimeline(since: lastSync)

// Follow user
try await APIService.shared.followUser(userId: "user-id")
```

## Security Notes

- Currently uses simple account ID authentication
- In production, implement JWT tokens or OAuth
- Add rate limiting and input validation
- Consider image size limits and CDN storage

## Limitations

- Images stored as base64 in database (consider R2 for production)
- Simple authentication (upgrade for production)
- No real-time notifications (consider WebSockets/SSE)
- No image resizing/optimization

## Future Enhancements

1. **Image Storage**: Move to Cloudflare R2 for better performance
2. **Authentication**: Implement JWT or OAuth
3. **Real-time**: Add WebSocket support for live updates
4. **Search**: Add geographic and content-based search
5. **Analytics**: Track usage and engagement metrics