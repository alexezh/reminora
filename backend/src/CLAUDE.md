# src/ Directory

## Purpose
Source code for the Reminora Cloudflare Workers backend.

## Authentication Implementation

### Session Authentication (Required for All APIs)
- **File**: `routes/auth.js` - `authenticateSession()` function
- **Header**: `Authorization: Bearer {session_token}`
- **Validation**: Checks session token exists and is not expired
- **Database**: Validates against `sessions` table with account join

### Deprecated Simple Authentication
- **File**: `middleware/auth.js` - **REMOVED**
- **Previous**: Used `X-Account-ID` header 
- **Status**: Deprecated for security reasons

## File Structure

### Core
- **index.js** - Main router setup and error handling
- **middleware/cors.js** - CORS headers for all requests
- **middleware/auth.js** - Deprecated auth middleware (documentation only)

### Route Handlers
- **routes/auth.js** - OAuth login, session management, token handling
- **routes/accounts.js** - User account CRUD operations
- **routes/photos.js** - Photo upload, retrieval, timeline
- **routes/follows.js** - Social following system

### Utilities
- **utils/auth.js** - Session token generation and validation
- **utils/helpers.js** - Common helper functions

## API Authentication Flow

1. **Public Endpoints** (No Auth):
   - `GET /health`
   - `POST /api/auth/oauth/callback`
   - `POST /api/auth/logout`
   - `POST /api/auth/refresh`

2. **Protected Endpoints** (Session Auth Required):
   - All `/api/accounts/*` endpoints
   - All `/api/photos/*` endpoints  
   - All `/api/follows/*` endpoints

3. **Session Validation**:
   ```javascript
   const authHeader = request.headers.get('Authorization');
   const sessionToken = authHeader?.replace('Bearer ', '');
   // Validate token against sessions table
   ```

## Security Notes
- Session tokens expire after 30 days
- OAuth tokens stored securely in database
- Account ID in requests comes from validated session
- No direct account ID authentication accepted