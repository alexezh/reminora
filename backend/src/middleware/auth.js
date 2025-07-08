/**
 * Authentication middleware
 * For simplicity, using account ID in header. In production, use JWT tokens.
 */

export async function authenticate(request, env) {
    const accountId = request.headers.get('X-Account-ID');
    
    if (!accountId) {
        return new Response(JSON.stringify({ 
            error: 'Authentication required',
            message: 'X-Account-ID header is required'
        }), {
            status: 401,
            headers: { 
                'Content-Type': 'application/json',
                ...request.corsHeaders 
            }
        });
    }

    // Verify account exists in database
    try {
        const account = await env.DB.prepare(
            'SELECT id, username, display_name FROM accounts WHERE id = ?'
        ).bind(accountId).first();

        if (!account) {
            return new Response(JSON.stringify({ 
                error: 'Invalid account',
                message: 'Account not found'
            }), {
                status: 401,
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        }

        // Add account info to request for downstream handlers
        request.account = account;
    } catch (error) {
        console.error('Auth error:', error);
        return new Response(JSON.stringify({ 
            error: 'Authentication failed',
            message: 'Database error during authentication'
        }), {
            status: 500,
            headers: { 
                'Content-Type': 'application/json',
                ...request.corsHeaders 
            }
        });
    }
}