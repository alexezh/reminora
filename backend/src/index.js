/**
 * Reminora Backend - Cloudflare Workers with D1
 * Handles photo storage, user accounts, and social features
 */

import { Router } from 'itty-router';
import { handleCORS } from './middleware/cors.js';
import { authRoutes } from './routes/auth.js';
import { pinRoutes } from './routes/pins.js';
import { followRoutes } from './routes/follows.js';
import { accountRoutes } from './routes/accounts.js';

const router = Router();

// Apply CORS to all routes
router.all('*', handleCORS);

// Health check endpoint
router.get('/health', () => {
    return new Response(JSON.stringify({
        status: 'ok++',
        timestamp: new Date().toISOString(),
        version: 'fixed-router-v2'
    }), {
        headers: { 'Content-Type': 'application/json' }
    });
});

// Test endpoint to verify routing works
router.get('/test', () => {
    return new Response(JSON.stringify({
        message: 'Test endpoint works',
        timestamp: new Date().toISOString()
    }), {
        headers: { 'Content-Type': 'application/json' }
    });
});

// Auth routes (public, no auth required)
authRoutes(router);

// Register all route handlers (they handle authentication internally)
accountRoutes(router);
pinRoutes(router);
followRoutes(router);

// 404 handler
router.all('*', () => new Response('Not Found', { status: 405 }));

export default {
    fetch: router.fetch
};