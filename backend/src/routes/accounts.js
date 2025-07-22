/**
 * Account management routes
 */

import { generateId } from '../utils/helpers.js';
import { authenticateSession } from './auth.js';

export function accountRoutes(router) {
    // Create account
    router.post('/api/accounts', async (request, env) => {
        try {
            const { username, email, display_name, bio } = await request.json();
            
            if (!username || !email) {
                return new Response(JSON.stringify({
                    error: 'Missing required fields',
                    message: 'Username and email are required'
                }), {
                    status: 400,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            const accountId = generateId();
            const now = Math.floor(Date.now() / 1000);

            await env.DB.prepare(`
                INSERT INTO accounts (id, username, email, display_name, bio, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            `).bind(accountId, username, email, display_name || username, bio || '', now, now).run();

            const account = await env.DB.prepare(
                'SELECT id, username, email, display_name, bio, created_at FROM accounts WHERE id = ?'
            ).bind(accountId).first();

            return new Response(JSON.stringify(account), {
                status: 201,
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Create account error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to create account',
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

    // Get account profile
    router.get('/api/accounts/:id', async (request, env) => {
        // Check authentication
        const authResult = await authenticateSession(request, env);
        if (authResult instanceof Response) {
            return authResult;
        }
        
        try {
            const accountId = request.params.id;
            
            const account = await env.DB.prepare(`
                SELECT id, username, display_name, bio, created_at
                FROM accounts WHERE id = ?
            `).bind(accountId).first();

            if (!account) {
                return new Response(JSON.stringify({
                    error: 'Account not found',
                    accountId: accountId
                }), {
                    status: 404,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            return new Response(JSON.stringify(account), {
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Get account error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to get account',
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

    // Update account
    router.put('/api/accounts/:id', async (request, env) => {
        // Check authentication
        const authResult = await authenticateSession(request, env);
        if (authResult instanceof Response) {
            return authResult;
        }
        
        try {
            const accountId = request.params.id;
            
            // Only allow users to update their own account
            if (request.account.id !== accountId) {
                return new Response(JSON.stringify({
                    error: 'Permission denied',
                    message: 'You can only update your own account'
                }), {
                    status: 403,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            const { display_name, bio } = await request.json();
            const now = Math.floor(Date.now() / 1000);

            await env.DB.prepare(`
                UPDATE accounts 
                SET display_name = ?, bio = ?, updated_at = ?
                WHERE id = ?
            `).bind(display_name, bio, now, accountId).run();

            const account = await env.DB.prepare(
                'SELECT id, username, email, display_name, bio, updated_at FROM accounts WHERE id = ?'
            ).bind(accountId).first();

            return new Response(JSON.stringify(account), {
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Update account error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to update account',
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