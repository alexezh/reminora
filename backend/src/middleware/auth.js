/**
 * Authentication middleware
 * 
 * DEPRECATED: Simple account ID authentication removed.
 * All API endpoints now use session-based authentication only.
 * Only the /health endpoint uses no authentication.
 * 
 * Use authenticateSession from routes/auth.js for all protected routes.
 */

// Simple authentication method removed - use session authentication only