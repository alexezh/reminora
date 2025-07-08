/**
 * Follow system routes
 */

import { generateId } from '../utils/helpers.js';

export function followRoutes(router) {
    // Follow a user
    router.post('/api/follows', async (request, env) => {
        try {
            const { following_id } = await request.json();
            const follower_id = request.account.id;
            
            if (!following_id) {
                return new Response(JSON.stringify({
                    error: 'Missing following_id',
                    message: 'following_id is required'
                }), {
                    status: 400,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            if (follower_id === following_id) {
                return new Response(JSON.stringify({
                    error: 'Cannot follow yourself'
                }), {
                    status: 400,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            // Check if target account exists
            const targetAccount = await env.DB.prepare(
                'SELECT id FROM accounts WHERE id = ?'
            ).bind(following_id).first();

            if (!targetAccount) {
                return new Response(JSON.stringify({
                    error: 'Account not found'
                }), {
                    status: 404,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            // Check if already following
            const existingFollow = await env.DB.prepare(
                'SELECT 1 FROM follows WHERE follower_id = ? AND following_id = ?'
            ).bind(follower_id, following_id).first();

            if (existingFollow) {
                return new Response(JSON.stringify({
                    error: 'Already following this user'
                }), {
                    status: 409,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            const followId = generateId();
            const now = Math.floor(Date.now() / 1000);

            await env.DB.prepare(`
                INSERT INTO follows (id, follower_id, following_id, created_at)
                VALUES (?, ?, ?, ?)
            `).bind(followId, follower_id, following_id, now).run();

            // Add existing photos from followed user to follower's timeline
            const existingPhotos = await env.DB.prepare(
                'SELECT id, created_at FROM photos WHERE account_id = ? ORDER BY created_at DESC LIMIT 100'
            ).bind(following_id).all();

            const timelinePromises = existingPhotos.results.map(photo => {
                const timelineId = generateId();
                return env.DB.prepare(`
                    INSERT INTO photo_timeline (id, photo_id, account_id, visible_to_account_id, created_at)
                    VALUES (?, ?, ?, ?, ?)
                `).bind(timelineId, photo.id, following_id, follower_id, photo.created_at).run();
            });

            await Promise.all(timelinePromises);

            const follow = await env.DB.prepare(`
                SELECT f.*, a.username, a.display_name 
                FROM follows f
                JOIN accounts a ON f.following_id = a.id
                WHERE f.id = ?
            `).bind(followId).first();

            return new Response(JSON.stringify(follow), {
                status: 201,
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Follow user error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to follow user',
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

    // Unfollow a user
    router.delete('/api/follows/:following_id', async (request, env) => {
        try {
            const following_id = request.params.following_id;
            const follower_id = request.account.id;

            const follow = await env.DB.prepare(
                'SELECT id FROM follows WHERE follower_id = ? AND following_id = ?'
            ).bind(follower_id, following_id).first();

            if (!follow) {
                return new Response(JSON.stringify({
                    error: 'Not following this user'
                }), {
                    status: 404,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            // Remove follow relationship
            await env.DB.prepare(
                'DELETE FROM follows WHERE follower_id = ? AND following_id = ?'
            ).bind(follower_id, following_id).run();

            // Remove photos from timeline
            await env.DB.prepare(
                'DELETE FROM photo_timeline WHERE visible_to_account_id = ? AND account_id = ?'
            ).bind(follower_id, following_id).run();

            return new Response(JSON.stringify({ success: true }), {
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Unfollow user error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to unfollow user',
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

    // Get followers list
    router.get('/api/follows/followers', async (request, env) => {
        try {
            const url = new URL(request.url);
            const accountId = url.searchParams.get('account_id') || request.account.id;
            const limit = Math.min(parseInt(url.searchParams.get('limit') || '50'), 100);
            const offset = parseInt(url.searchParams.get('offset') || '0');

            const followers = await env.DB.prepare(`
                SELECT f.created_at, a.id, a.username, a.display_name
                FROM follows f
                JOIN accounts a ON f.follower_id = a.id
                WHERE f.following_id = ?
                ORDER BY f.created_at DESC
                LIMIT ? OFFSET ?
            `).bind(accountId, limit, offset).all();

            return new Response(JSON.stringify(followers.results), {
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Get followers error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to get followers',
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

    // Get following list
    router.get('/api/follows/following', async (request, env) => {
        try {
            const url = new URL(request.url);
            const accountId = url.searchParams.get('account_id') || request.account.id;
            const limit = Math.min(parseInt(url.searchParams.get('limit') || '50'), 100);
            const offset = parseInt(url.searchParams.get('offset') || '0');

            const following = await env.DB.prepare(`
                SELECT f.created_at, a.id, a.username, a.display_name
                FROM follows f
                JOIN accounts a ON f.following_id = a.id
                WHERE f.follower_id = ?
                ORDER BY f.created_at DESC
                LIMIT ? OFFSET ?
            `).bind(accountId, limit, offset).all();

            return new Response(JSON.stringify(following.results), {
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Get following error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to get following',
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

    // Search users to follow
    router.get('/api/follows/search', async (request, env) => {
        try {
            const url = new URL(request.url);
            const query = url.searchParams.get('q');
            const limit = Math.min(parseInt(url.searchParams.get('limit') || '20'), 50);

            if (!query || query.length < 2) {
                return new Response(JSON.stringify({
                    error: 'Query too short',
                    message: 'Search query must be at least 2 characters'
                }), {
                    status: 400,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            const users = await env.DB.prepare(`
                SELECT a.id, a.username, a.display_name, a.bio,
                       CASE WHEN f.follower_id IS NOT NULL THEN 1 ELSE 0 END as is_following
                FROM accounts a
                LEFT JOIN follows f ON a.id = f.following_id AND f.follower_id = ?
                WHERE (a.username LIKE ? OR a.display_name LIKE ?) AND a.id != ?
                ORDER BY is_following DESC, a.username
                LIMIT ?
            `).bind(
                request.account.id,
                `%${query}%`,
                `%${query}%`,
                request.account.id,
                limit
            ).all();

            return new Response(JSON.stringify(users.results), {
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Search users error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to search users',
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