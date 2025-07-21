# middleware/ Directory

## Purpose
Middleware functions for request processing in the Reminora backend.

## Files

### cors.js
- **Purpose**: Handle CORS (Cross-Origin Resource Sharing) headers
- **Function**: `handleCORS(request)`
- **Applied**: To all routes via `router.all('*', handleCORS)`
- **Headers Set**:
  - `Access-Control-Allow-Origin: *`
  - `Access-Control-Allow-Headers: Content-Type, Authorization`
  - `Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS`

### auth.js
- **Purpose**: ~~Simple authentication middleware~~ **DEPRECATED**
- **Status**: **Removed for security**
- **Previous Function**: `authenticate()` - validated X-Account-ID headers
- **Current**: Documentation only - all authentication now uses sessions
- **Replacement**: Use `authenticateSession()` from `routes/auth.js`

## Authentication Strategy

### Old (Removed)
```javascript
// DEPRECATED - Do not use
const accountId = request.headers.get('X-Account-ID');
```

### Current (Session-Based)
```javascript
// Use this pattern for all protected routes
import { authenticateSession } from '../routes/auth.js';

// In router setup
router.all('/api/protected/*', authenticateSession);

// In route handlers
export function protectedRoute(request, env) {
    const currentUser = request.account; // Populated by authenticateSession
    // ... route logic
}
```

## Middleware Order
1. **CORS** - Applied to all routes first
2. **Session Auth** - Applied to protected API routes
3. **Route Handlers** - Actual endpoint logic

## Security Notes
- Simple account ID authentication completely removed
- All protected routes require valid session tokens
- Sessions expire after 30 days for security
- OAuth integration provides secure token generation