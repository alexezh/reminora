/**
 * Simple OAuth endpoint without router dependency
 */

export default {
    async fetch(request, env, ctx) {
        try {
            const url = new URL(request.url);
            
            // CORS headers
            const corsHeaders = {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            };
            
            // Handle CORS preflight
            if (request.method === 'OPTIONS') {
                return new Response(null, { 
                    status: 200, 
                    headers: corsHeaders 
                });
            }
            
            // Health check
            if (url.pathname === '/health') {
                return new Response(JSON.stringify({ 
                    status: 'ok', 
                    timestamp: new Date().toISOString() 
                }), {
                    headers: { 
                        'Content-Type': 'application/json',
                        ...corsHeaders
                    }
                });
            }
            
            // OAuth callback endpoint
            if (url.pathname === '/api/auth/oauth/callback' && request.method === 'POST') {
                const body = await request.json();
                console.log('OAuth request:', JSON.stringify(body));
                
                const { provider, oauth_id, email, name, avatar_url, access_token, refresh_token } = body;
                
                if (!provider || !oauth_id || !email) {
                    return new Response(JSON.stringify({
                        error: 'Missing required OAuth data',
                        message: 'provider, oauth_id, and email are required'
                    }), {
                        status: 400,
                        headers: { 
                            'Content-Type': 'application/json',
                            ...corsHeaders
                        }
                    });
                }
                
                // Generate IDs
                const accountId = crypto.randomUUID();
                const sessionId = crypto.randomUUID();
                const sessionToken = crypto.randomUUID();
                const now = Math.floor(Date.now() / 1000);
                
                try {
                    // Check if account exists
                    let account = await env.DB.prepare(`
                        SELECT * FROM accounts 
                        WHERE oauth_provider = ? AND oauth_id = ?
                    `).bind(provider, oauth_id).first();
                    
                    if (!account) {
                        // Check if account exists with this email
                        const existingAccount = await env.DB.prepare(`
                            SELECT * FROM accounts WHERE email = ?
                        `).bind(email).first();
                        
                        if (existingAccount) {
                            // Update existing account with OAuth info
                            await env.DB.prepare(`
                                UPDATE accounts 
                                SET oauth_provider = ?, oauth_id = ?, avatar_url = ?, updated_at = ?
                                WHERE id = ?
                            `).bind(provider, oauth_id, avatar_url, now, existingAccount.id).run();
                            
                            account = {
                                ...existingAccount,
                                oauth_provider: provider,
                                oauth_id: oauth_id,
                                avatar_url: avatar_url,
                                updated_at: now
                            };
                        } else {
                            // Create new account - handle uniqueness
                            let handle = email.split('@')[0];
                            let handleSuffix = '';
                            let attempts = 0;
                            
                            // Find unique handle
                            while (attempts < 10) {
                                const testHandle = handle + handleSuffix;
                                const existingHandle = await env.DB.prepare(`
                                    SELECT id FROM accounts WHERE handle = ?
                                `).bind(testHandle).first();
                                
                                if (!existingHandle) {
                                    handle = testHandle;
                                    break;
                                }
                                
                                attempts++;
                                handleSuffix = `_${attempts}`;
                            }
                            
                            await env.DB.prepare(`
                                INSERT INTO accounts (id, username, email, display_name, handle, oauth_provider, oauth_id, avatar_url, created_at, updated_at)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                            `).bind(accountId, handle, email, name || email, handle, provider, oauth_id, avatar_url, now, now).run();
                            
                            account = {
                                id: accountId,
                                username: handle,
                                email: email,
                                display_name: name || email,
                                handle: handle,
                                oauth_provider: provider,
                                oauth_id: oauth_id,
                                avatar_url: avatar_url,
                                created_at: now,
                                updated_at: now
                            };
                        }
                    }
                    
                    // Create session
                    const expiresAt = now + (7 * 24 * 60 * 60); // 7 days
                    
                    await env.DB.prepare(`
                        INSERT INTO sessions (id, account_id, session_token, expires_at, created_at, last_used_at)
                        VALUES (?, ?, ?, ?, ?, ?)
                    `).bind(sessionId, account.id, sessionToken, expiresAt, now, now).run();
                    
                    return new Response(JSON.stringify({
                        session: {
                            token: sessionToken,
                            expires_at: expiresAt
                        },
                        account: {
                            id: account.id,
                            username: account.username,
                            email: account.email,
                            display_name: account.display_name,
                            handle: account.handle,
                            avatar_url: account.avatar_url,
                            needs_handle: false
                        }
                    }), {
                        headers: { 
                            'Content-Type': 'application/json',
                            ...corsHeaders
                        }
                    });
                    
                } catch (dbError) {
                    console.error('Database error:', dbError);
                    return new Response(JSON.stringify({
                        error: 'Database error',
                        message: dbError.message
                    }), {
                        status: 500,
                        headers: { 
                            'Content-Type': 'application/json',
                            ...corsHeaders
                        }
                    });
                }
            }
            
            // Comments API
            if (url.pathname === '/api/comments' && request.method === 'POST') {
                const body = await request.json();
                const { target_photo_id, target_user_id, comment_text, type = 'comment' } = body;
                
                // Basic validation
                if (!comment_text || (!target_photo_id && !target_user_id)) {
                    return new Response(JSON.stringify({
                        error: 'Missing required fields',
                        message: 'comment_text and either target_photo_id or target_user_id are required'
                    }), {
                        status: 400,
                        headers: { 'Content-Type': 'application/json', ...corsHeaders }
                    });
                }
                
                // TODO: Authenticate user from session token
                // For now, use the first available user as the commenter
                const users = await env.DB.prepare('SELECT id FROM accounts LIMIT 1').all();
                const fromUserId = users.results?.[0]?.id || 'unknown';
                
                const commentId = crypto.randomUUID();
                const now = Math.floor(Date.now() / 1000);
                
                try {
                    await env.DB.prepare(`
                        INSERT INTO comments (id, from_user_id, to_user_id, target_photo_id, comment_text, type, is_reaction, created_at, updated_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    `).bind(commentId, fromUserId, target_user_id || null, target_photo_id || null, comment_text, type, type === 'reaction' ? 1 : 0, now, now).run();
                    
                    return new Response(JSON.stringify({
                        id: commentId,
                        message: 'Comment created successfully'
                    }), {
                        headers: { 'Content-Type': 'application/json', ...corsHeaders }
                    });
                } catch (dbError) {
                    return new Response(JSON.stringify({
                        error: 'Database error',
                        message: dbError.message
                    }), {
                        status: 500,
                        headers: { 'Content-Type': 'application/json', ...corsHeaders }
                    });
                }
            }
            
            // Get comments for a user or photo
            if (url.pathname.startsWith('/api/comments/') && request.method === 'GET') {
                const pathParts = url.pathname.split('/');
                const targetType = pathParts[3]; // 'user' or 'photo'
                const targetId = pathParts[4];
                
                if (!targetType || !targetId) {
                    return new Response(JSON.stringify({
                        error: 'Invalid path',
                        message: 'Use /api/comments/user/{userId} or /api/comments/photo/{photoId}'
                    }), {
                        status: 400,
                        headers: { 'Content-Type': 'application/json', ...corsHeaders }
                    });
                }
                
                try {
                    let query;
                    if (targetType === 'user') {
                        query = `
                            SELECT c.*, a.username as from_username, a.display_name as from_display_name, a.handle as from_handle
                            FROM comments c
                            LEFT JOIN accounts a ON c.from_user_id = a.id
                            WHERE c.to_user_id = ?
                            ORDER BY c.created_at DESC
                            LIMIT 50
                        `;
                    } else if (targetType === 'photo') {
                        query = `
                            SELECT c.*, a.username as from_username, a.display_name as from_display_name, a.handle as from_handle
                            FROM comments c
                            LEFT JOIN accounts a ON c.from_user_id = a.id
                            WHERE c.target_photo_id = ?
                            ORDER BY c.created_at ASC
                            LIMIT 50
                        `;
                    } else {
                        throw new Error('Invalid target type');
                    }
                    
                    const results = await env.DB.prepare(query).bind(targetId).all();
                    
                    return new Response(JSON.stringify({
                        comments: results.results || []
                    }), {
                        headers: { 'Content-Type': 'application/json', ...corsHeaders }
                    });
                } catch (dbError) {
                    return new Response(JSON.stringify({
                        error: 'Database error',
                        message: dbError.message
                    }), {
                        status: 500,
                        headers: { 'Content-Type': 'application/json', ...corsHeaders }
                    });
                }
            }
            
            return new Response('Not Found', { 
                status: 404, 
                headers: corsHeaders 
            });
            
        } catch (error) {
            console.error('Worker error:', error);
            return new Response(JSON.stringify({
                error: 'Internal Server Error',
                message: error.message,
                stack: error.stack
            }), { 
                status: 500,
                headers: { 
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                }
            });
        }
    }
};