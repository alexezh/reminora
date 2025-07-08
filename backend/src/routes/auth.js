/**
 * Authentication routes with OAuth support
 */

import { generateId } from '../utils/helpers.js';
import { generateSessionToken, hashToken } from '../utils/auth.js';

export function authRoutes(router) {
    // OAuth callback endpoint
    router.post('/api/auth/oauth/callback', async (request, env) => {
        try {
            const { 
                provider, 
                code, 
                oauth_id, 
                email, 
                name, 
                avatar_url,
                access_token,
                refresh_token,
                expires_in 
            } = await request.json();
            
            if (!provider || !oauth_id || !email) {
                return new Response(JSON.stringify({
                    error: 'Missing required OAuth data',
                    message: 'provider, oauth_id, and email are required'
                }), {
                    status: 400,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            // Check if account already exists with this OAuth ID
            let account = await env.DB.prepare(`
                SELECT * FROM accounts 
                WHERE oauth_provider = ? AND oauth_id = ?
            `).bind(provider, oauth_id).first();

            const now = Math.floor(Date.now() / 1000);

            if (!account) {
                // Check if account exists with this email
                const existingAccount = await env.DB.prepare(
                    'SELECT id FROM accounts WHERE email = ?'
                ).bind(email).first();

                if (existingAccount) {
                    // Link OAuth to existing account
                    await env.DB.prepare(`
                        UPDATE accounts 
                        SET oauth_provider = ?, oauth_id = ?, avatar_url = ?, updated_at = ?
                        WHERE email = ?
                    `).bind(provider, oauth_id, avatar_url, now, email).run();
                    
                    account = await env.DB.prepare(
                        'SELECT * FROM accounts WHERE email = ?'
                    ).bind(email).first();
                } else {
                    // Create new account - will need handle selection
                    const accountId = generateId();
                    const username = email.split('@')[0]; // Temporary username
                    
                    await env.DB.prepare(`
                        INSERT INTO accounts (
                            id, username, email, display_name, oauth_provider, 
                            oauth_id, avatar_url, created_at, updated_at
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    `).bind(
                        accountId, 
                        username, 
                        email, 
                        name || username, 
                        provider, 
                        oauth_id, 
                        avatar_url, 
                        now, 
                        now
                    ).run();

                    account = await env.DB.prepare(
                        'SELECT * FROM accounts WHERE id = ?'
                    ).bind(accountId).first();
                }
            } else {
                // Update existing OAuth account
                await env.DB.prepare(`
                    UPDATE accounts 
                    SET email = ?, display_name = ?, avatar_url = ?, updated_at = ?
                    WHERE id = ?
                `).bind(email, name || account.display_name, avatar_url, now, account.id).run();
            }

            // Store/update OAuth tokens
            if (access_token) {
                const tokenId = generateId();
                const expiresAt = expires_in ? now + expires_in : null;

                await env.DB.prepare(`
                    INSERT OR REPLACE INTO oauth_tokens (
                        id, account_id, provider, access_token, refresh_token, 
                        expires_at, created_at, updated_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                `).bind(
                    tokenId, 
                    account.id, 
                    provider, 
                    access_token, 
                    refresh_token, 
                    expiresAt, 
                    now, 
                    now
                ).run();
            }

            // Create session
            const sessionToken = generateSessionToken();
            const sessionId = generateId();
            const sessionExpiresAt = now + (30 * 24 * 60 * 60); // 30 days

            await env.DB.prepare(`
                INSERT INTO sessions (
                    id, account_id, session_token, expires_at, created_at, 
                    user_agent, ip_address
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
            `).bind(
                sessionId,
                account.id,
                sessionToken,
                sessionExpiresAt,
                now,
                request.headers.get('User-Agent') || '',
                request.headers.get('CF-Connecting-IP') || ''
            ).run();

            // Return account info and session
            const response = {
                account: {
                    id: account.id,
                    username: account.username,
                    email: account.email,
                    display_name: account.display_name,
                    handle: account.handle,
                    avatar_url: account.avatar_url,
                    needs_handle: !account.handle
                },
                session: {
                    token: sessionToken,
                    expires_at: sessionExpiresAt
                }
            };

            return new Response(JSON.stringify(response), {
                status: 200,
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('OAuth callback error:', error);
            return new Response(JSON.stringify({
                error: 'OAuth authentication failed',
                message: error.message
            }), {
                status: 500,
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        }
    });

    // Complete account setup (set handle)
    router.post('/api/auth/complete-setup', async (request, env, ctx) => {
        try {
            // This endpoint requires authentication
            const authResult = await authenticateSession(request, env);
            if (authResult instanceof Response) return authResult;
            
            const { handle } = await request.json();
            
            if (!handle) {
                return new Response(JSON.stringify({
                    error: 'Handle required',
                    message: 'handle is required'
                }), {
                    status: 400,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            // Validate handle format
            if (!/^[a-zA-Z0-9_]{3,20}$/.test(handle)) {
                return new Response(JSON.stringify({
                    error: 'Invalid handle',
                    message: 'Handle must be 3-20 characters, alphanumeric and underscore only'
                }), {
                    status: 400,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            // Check if handle is available
            const existingHandle = await env.DB.prepare(
                'SELECT id FROM accounts WHERE handle = ? AND id != ?'
            ).bind(handle, request.account.id).first();

            if (existingHandle) {
                return new Response(JSON.stringify({
                    error: 'Handle taken',
                    message: 'This handle is already taken'
                }), {
                    status: 409,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            // Update account with handle
            const now = Math.floor(Date.now() / 1000);
            await env.DB.prepare(`
                UPDATE accounts 
                SET handle = ?, updated_at = ?
                WHERE id = ?
            `).bind(handle, now, request.account.id).run();

            // Return updated account
            const account = await env.DB.prepare(
                'SELECT id, username, email, display_name, handle, avatar_url FROM accounts WHERE id = ?'
            ).bind(request.account.id).first();

            return new Response(JSON.stringify(account), {
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Complete setup error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to complete setup',
                message: error.message
            }), {
                status: 500,
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        }
    });

    // Check handle availability
    router.get('/api/auth/check-handle/:handle', async (request, env) => {
        try {
            const handle = request.params.handle;
            
            if (!/^[a-zA-Z0-9_]{3,20}$/.test(handle)) {
                return new Response(JSON.stringify({
                    available: false,
                    message: 'Invalid handle format'
                }), {
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            const existingHandle = await env.DB.prepare(
                'SELECT id FROM accounts WHERE handle = ?'
            ).bind(handle).first();

            return new Response(JSON.stringify({
                available: !existingHandle,
                message: existingHandle ? 'Handle is taken' : 'Handle is available'
            }), {
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Check handle error:', error);
            return new Response(JSON.stringify({
                available: false,
                message: 'Error checking handle'
            }), {
                status: 500,
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        }
    });

    // Logout
    router.post('/api/auth/logout', async (request, env) => {
        try {
            const sessionToken = request.headers.get('Authorization')?.replace('Bearer ', '');
            
            if (sessionToken) {
                await env.DB.prepare(
                    'DELETE FROM sessions WHERE session_token = ?'
                ).bind(sessionToken).run();
            }

            return new Response(JSON.stringify({ success: true }), {
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Logout error:', error);
            return new Response(JSON.stringify({
                error: 'Logout failed',
                message: error.message
            }), {
                status: 500,
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        }
    });

    // Refresh session
    router.post('/api/auth/refresh', async (request, env) => {
        try {
            const { refresh_token } = await request.json();
            
            if (!refresh_token) {
                return new Response(JSON.stringify({
                    error: 'Refresh token required'
                }), {
                    status: 400,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            // Find account with this refresh token
            const tokenRecord = await env.DB.prepare(`
                SELECT t.*, a.* FROM oauth_tokens t
                JOIN accounts a ON t.account_id = a.id
                WHERE t.refresh_token = ?
            `).bind(refresh_token).first();

            if (!tokenRecord) {
                return new Response(JSON.stringify({
                    error: 'Invalid refresh token'
                }), {
                    status: 401,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            // Create new session
            const sessionToken = generateSessionToken();
            const sessionId = generateId();
            const now = Math.floor(Date.now() / 1000);
            const sessionExpiresAt = now + (30 * 24 * 60 * 60); // 30 days

            await env.DB.prepare(`
                INSERT INTO sessions (
                    id, account_id, session_token, expires_at, created_at
                )
                VALUES (?, ?, ?, ?, ?)
            `).bind(sessionId, tokenRecord.account_id, sessionToken, sessionExpiresAt, now).run();

            return new Response(JSON.stringify({
                session: {
                    token: sessionToken,
                    expires_at: sessionExpiresAt
                },
                account: {
                    id: tokenRecord.account_id,
                    username: tokenRecord.username,
                    handle: tokenRecord.handle,
                    display_name: tokenRecord.display_name,
                    avatar_url: tokenRecord.avatar_url
                }
            }), {
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Refresh session error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to refresh session',
                message: error.message
            }), {
                status: 500,
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        }
    });
}

// Session-based authentication middleware
export async function authenticateSession(request, env) {
    const authHeader = request.headers.get('Authorization');
    const sessionToken = authHeader?.replace('Bearer ', '');
    
    if (!sessionToken) {
        return new Response(JSON.stringify({ 
            error: 'Authentication required',
            message: 'Authorization header with session token is required'
        }), {
            status: 401,
            headers: { 
                'Content-Type': 'application/json',
                ...request.corsHeaders 
            }
        });
    }

    try {
        const session = await env.DB.prepare(`
            SELECT s.*, a.id as account_id, a.username, a.display_name, a.handle, a.email
            FROM sessions s
            JOIN accounts a ON s.account_id = a.id
            WHERE s.session_token = ? AND s.expires_at > ?
        `).bind(sessionToken, Math.floor(Date.now() / 1000)).first();

        if (!session) {
            return new Response(JSON.stringify({ 
                error: 'Invalid session',
                message: 'Session token is invalid or expired'
            }), {
                status: 401,
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        }

        // Update last used time
        await env.DB.prepare(
            'UPDATE sessions SET last_used_at = ? WHERE id = ?'
        ).bind(Math.floor(Date.now() / 1000), session.id).run();

        // Add account info to request for downstream handlers
        request.account = {
            id: session.account_id,
            username: session.username,
            display_name: session.display_name,
            handle: session.handle,
            email: session.email
        };

        return null; // Success, continue to next handler
    } catch (error) {
        console.error('Session auth error:', error);
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