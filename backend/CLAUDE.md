# Backend Directory

## Purpose
Cloudflare Workers backend for the Reminora photo sharing app using D1 database.

## Authentication Strategy

### Session-Based Authentication Only
- **All API endpoints** use session-based authentication via `Authorization: Bearer {session_token}` header
- **OAuth flow** creates session tokens that expire after 30 days
- **No simple authentication** - removed X-Account-ID method for security

### Endpoints by Authentication:
- `/health` - **No auth required** (public health check)
- `/api/auth/*` - **Public** (OAuth login/logout)
- `/api/accounts/*` - **Session auth required**
- `/api/pins/*` - **Session auth required** 
- `/api/follows/*` - **Session auth required**

## Key Components
- **src/index.js** - Main router and middleware setup
- **src/routes/auth.js** - OAuth login and session management
- **src/routes/accounts.js** - User account management
- **src/routes/pins.js** - Pin storage and retrieval
- **src/routes/follows.js** - Social following system
- **src/middleware/** - CORS and authentication middleware
- **migrations/** - Database schema and updates

## OAuth Flow
1. Client sends OAuth callback data to `/api/auth/oauth/callback`
2. Backend creates/updates user account
3. Backend generates session token
4. Client uses session token for all API calls
5. Session expires after 30 days

## Database
- **D1 SQLite database** with tables for accounts, photos, follows, sessions
- **Session management** with automatic cleanup of expired sessions
- **OAuth token storage** for refresh capabilities

## Deployment
- Deployed to Cloudflare Workers
- Connected to D1 database instance
- Uses wrangler.toml for configuration