/**
 * Test router import specifically
 */

import { Router } from 'itty-router';

const router = Router();

router.get('/health', () => {
    return new Response(JSON.stringify({ 
        status: 'ok', 
        timestamp: new Date().toISOString() 
    }), {
        headers: { 'Content-Type': 'application/json' }
    });
});

export default {
    async fetch(request, env, ctx) {
        try {
            return await router.handle(request, env, ctx);
        } catch (error) {
            return new Response(JSON.stringify({
                error: 'Router Error',
                message: error.message,
                stack: error.stack
            }), { 
                status: 500,
                headers: { 'Content-Type': 'application/json' }
            });
        }
    }
};