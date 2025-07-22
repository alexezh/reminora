# Backend Directory

## Purpose
Cloudflare Workers backend for the Wahi (Reminora) photo sharing app using D1 SQLite database. Provides RESTful API for user authentication, pin management, social features, and real-time synchronization.

## Authentication Strategy

### Session-Based Authentication Only
- **All API endpoints** use session-based authentication via `Authorization: Bearer {session_token}` header
- **OAuth flow** creates session tokens that expire after 30 days
- **No simple authentication** - removed X-Account-ID method for security

### Endpoints by Authentication:
- `/health` - **No auth required** (public health check)
- `/api/auth/*` - **Public** (OAuth login/logout)
- `/api/accounts/*` - **Session auth required**
- `/api/pins/*` - **Session auth required** (public pin reading, follow permissions removed)
- `/api/follows/*` - **Session auth required** (follow/unfollow management)
- `/api/comments/*` - **Session auth required** (pin comments and interactions)

## Key Components
- **src/index.js** - Main router and middleware setup
- **src/routes/auth.js** - OAuth login and session management
- **src/routes/accounts.js** - User account and profile management
- **src/routes/pins.js** - Pin storage, retrieval, and sharing (renamed from /api/photos)
- **src/routes/follows.js** - Social following system and user relationships
- **src/routes/comments.js** - Pin comments and social interactions
- **src/middleware/** - CORS, authentication, and request validation
- **migrations/** - Database schema evolution and updates

## OAuth Flow
1. Client sends OAuth callback data to `/api/auth/oauth/callback`
2. Backend creates/updates user account
3. Backend generates session token
4. Client uses session token for all API calls
5. Session expires after 30 days

## Database Schema

### Core Tables
- **accounts** - User profiles with OAuth integration
- **photos** - Pin data with location, images, and metadata
- **follows** - User following relationships
- **sessions** - Authentication session tokens with expiration
- **comments** - User comments on pins and social interactions

### Key Features
- **Session management** with automatic cleanup of expired sessions
- **OAuth token storage** for refresh capabilities and profile sync
- **Pin ownership tracking** with user attribution
- **Privacy controls** for public/private pin sharing
- **Comment threading** and social interaction tracking

## Recent Changes

### API Updates
- **Removed follow permissions** from pins endpoints - pins are now publicly readable
- **Added authentication middleware** to all protected routes
- **Renamed /api/photos to /api/pins** for better semantic clarity
- **Enhanced error handling** and logging for debugging
- **Improved user ownership** tracking for shared pins

### Bug Fixes
- **Fixed HTTP 405 errors** by adding proper authentication middleware
- **Resolved undefined user ID errors** in follows API
- **Fixed pin display issues** when not following users
- **Improved pin ownership attribution** for shared content

## Deployment
- **Platform**: Cloudflare Workers with global edge deployment
- **Database**: D1 SQLite with automatic scaling
- **Configuration**: wrangler.toml for environment and binding setup
- **Monitoring**: Built-in logging and error tracking