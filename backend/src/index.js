/**
 * Reminora Backend - Cloudflare Workers with D1
 * Handles photo storage, user accounts, and social features
 */

import { Router } from 'itty-router';
import { handleCORS } from './middleware/cors.js';
import { authenticate } from './middleware/auth.js';
import { photoRoutes } from './routes/photos.js';
import { followRoutes } from './routes/follows.js';
import { accountRoutes } from './routes/accounts.js';

const router = Router();

// Apply CORS to all routes
router.all('*', handleCORS);

// Health check endpoint
router.get('/health', () => {
    return new Response(JSON.stringify({ 
        status: 'ok', 
        timestamp: new Date().toISOString() 
    }), {
        headers: { 'Content-Type': 'application/json' }
    });
});

// Account routes (auth required)
router.all('/api/accounts/*', authenticate);
accountRoutes(router);

// Photo routes (auth required)
router.all('/api/photos/*', authenticate);
photoRoutes(router);

// Follow routes (auth required)
router.all('/api/follows/*', authenticate);
followRoutes(router);

// 404 handler
router.all('*', () => new Response('Not Found', { status: 404 }));

export default {
    async fetch(request, env, ctx) {
        try {
            return await router.handle(request, env, ctx);
        } catch (error) {
            console.error('Worker error:', error);
            return new Response(JSON.stringify({ 
                error: 'Internal server error',
                message: error.message 
            }), {
                status: 500,
                headers: { 'Content-Type': 'application/json' }
            });
        }
    }
};