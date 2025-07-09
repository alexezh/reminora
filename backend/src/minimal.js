/**
 * Minimal worker to test basic functionality
 */

export default {
    async fetch(request, env, ctx) {
        try {
            const url = new URL(request.url);
            
            if (url.pathname === '/health') {
                return new Response(JSON.stringify({ 
                    status: 'ok', 
                    timestamp: new Date().toISOString() 
                }), {
                    headers: { 'Content-Type': 'application/json' }
                });
            }
            
            return new Response('Hello World', { status: 200 });
        } catch (error) {
            return new Response(JSON.stringify({
                error: 'Error',
                message: error.message,
                stack: error.stack
            }), { 
                status: 500,
                headers: { 'Content-Type': 'application/json' }
            });
        }
    }
};