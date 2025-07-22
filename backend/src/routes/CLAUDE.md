# routes/ Directory

## Purpose
API route handlers for the Reminora backend.

## Authentication Requirements

All route files implement **session-based authentication only**:
- Routes expect `Authorization: Bearer {session_token}` header
- Session validation done via `authenticateSession()` middleware
- Account information populated from validated session

## Route Files

### auth.js
- **Purpose**: OAuth login, session management
- **Authentication**: Mixed (some public, some require session)
- **Public Routes**:
  - `POST /api/auth/oauth/callback` - Process OAuth login
  - `POST /api/auth/logout` - End session
  - `POST /api/auth/refresh` - Refresh session token
  - `GET /api/auth/check-handle/:handle` - Check handle availability
- **Protected Routes**:
  - `POST /api/auth/complete-setup` - Set user handle (requires session)

### accounts.js  
- **Purpose**: User account management
- **Authentication**: Session required for all routes
- **Routes**:
  - `GET /api/accounts/:id` - Get account profile
  - `POST /api/accounts` - Create account
  - `PUT /api/accounts/:id` - Update account

### pins.js
- **Purpose**: Pin storage and timeline
- **Authentication**: Session required for all routes  
- **Routes**:
  - `POST /api/pins` - Upload pin
  - `GET /api/pins/timeline` - Get timeline
  - `GET /api/pins/account/:accountId` - Get user pins
  - `GET /api/pins/:id` - Get single pin
  - `DELETE /api/pins/:id` - Delete pin

### follows.js
- **Purpose**: Social following system
- **Authentication**: Session required for all routes
- **Routes**:
  - `POST /api/follows` - Follow user
  - `DELETE /api/follows/:following_id` - Unfollow user
  - `GET /api/follows/following` - Get following list  
  - `GET /api/follows/search` - Search users

## Session Authentication Implementation

Each protected route uses this pattern:
```javascript
// Applied in index.js
router.all('/api/accounts/*', authenticateSession);
router.all('/api/pins/*', authenticateSession);
router.all('/api/follows/*', authenticateSession);

// Route handlers access account via request.account
export function someRoute(request, env) {
    const currentUserId = request.account.id;
    // ... route logic
}
```

## Account Access in Routes
- `request.account.id` - Current user's account ID
- `request.account.username` - Current user's username  
- `request.account.display_name` - Current user's display name
- `request.account.handle` - Current user's handle
- `request.account.email` - Current user's email