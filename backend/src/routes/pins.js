/**
 * Pin management routes
 */

import { generateId } from '../utils/helpers.js';
import { authenticateSession } from './auth.js';

export function pinRoutes(router) {
    // Create/upload pin
    router.post('/api/pins', async (request, env) => {
        // Check authentication
        const authResult = await authenticateSession(request, env);
        if (authResult instanceof Response) {
            return authResult;
        }
        
        try {
            console.log('📸 Photos: Starting photo upload');
            const body = await request.json();
            console.log('📋 Photos: Request body keys:', Object.keys(body));
            console.log('📋 Photos: latitude:', body.latitude, 'longitude:', body.longitude);
            console.log('📋 Photos: location_name:', body.location_name, 'caption:', body.caption);
            console.log('📋 Photos: locations:', body.locations ? 'provided' : 'not provided');
            
            const { 
                photo_data, 
                latitude, 
                longitude, 
                location_name, 
                caption,
                locations
            } = body;
            
            if (!photo_data) {
                console.log('❌ Photos: Missing photo_data field');
                return new Response(JSON.stringify({
                    error: 'Missing photo data',
                    message: 'photo_data field is required'
                }), {
                    status: 400,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            const photoId = generateId();
            const accountId = request.account.id;
            const now = Math.floor(Date.now() / 1000);
            
            console.log('💾 Photos: Creating photo with ID:', photoId, 'for account:', accountId);

            // Insert photo with null handling
            await env.DB.prepare(`
                INSERT INTO photos (id, account_id, photo_data, latitude, longitude, location_name, caption, locations, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `).bind(
                photoId, 
                accountId, 
                JSON.stringify(photo_data), 
                latitude || null, 
                longitude || null, 
                location_name || null, 
                caption || null, 
                locations || null,
                now, 
                now
            ).run();

            // Create timeline entries for all followers
            const followers = await env.DB.prepare(
                'SELECT follower_id FROM follows WHERE following_id = ?'
            ).bind(accountId).all();

            const timelinePromises = followers.results.map(follower => {
                const timelineId = generateId();
                return env.DB.prepare(`
                    INSERT INTO photo_timeline (id, photo_id, account_id, visible_to_account_id, created_at)
                    VALUES (?, ?, ?, ?, ?)
                `).bind(timelineId, photoId, accountId, follower.follower_id, now).run();
            });

            // Also add to own timeline
            const ownTimelineId = generateId();
            timelinePromises.push(
                env.DB.prepare(`
                    INSERT INTO photo_timeline (id, photo_id, account_id, visible_to_account_id, created_at)
                    VALUES (?, ?, ?, ?, ?)
                `).bind(ownTimelineId, photoId, accountId, accountId, now).run()
            );

            await Promise.all(timelinePromises);

            // Return the created photo
            const photo = await env.DB.prepare(`
                SELECT p.*, a.username, a.display_name 
                FROM photos p
                JOIN accounts a ON p.account_id = a.id
                WHERE p.id = ?
            `).bind(photoId).first();

            console.log('✅ Photos: Photo created successfully, returning response');
            
            return new Response(JSON.stringify({
                ...photo,
                photo_data: JSON.parse(photo.photo_data)
            }), {
                status: 201,
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Create photo error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to create photo',
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

    // Get pins since waterline (timeline)
    router.get('/api/pins/timeline', async (request, env) => {
        // Check authentication
        const authResult = await authenticateSession(request, env);
        if (authResult instanceof Response) {
            return authResult;
        }
        
        try {
            const url = new URL(request.url);
            const since = url.searchParams.get('since') || '0';
            const limit = Math.min(parseInt(url.searchParams.get('limit') || '50'), 100);
            
            const accountId = request.account.id;

            const photos = await env.DB.prepare(`
                SELECT p.*, a.username, a.display_name, pt.created_at as timeline_created_at
                FROM photo_timeline pt
                JOIN photos p ON pt.photo_id = p.id
                JOIN accounts a ON p.account_id = a.id
                WHERE pt.visible_to_account_id = ? AND pt.created_at > ?
                ORDER BY pt.created_at DESC
                LIMIT ?
            `).bind(accountId, parseInt(since), limit).all();

            const result = photos.results.map(photo => ({
                ...photo,
                photo_data: JSON.parse(photo.photo_data)
            }));

            return new Response(JSON.stringify({
                photos: result,
                waterline: result.length > 0 ? result[0].timeline_created_at : since
            }), {
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Get timeline error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to get timeline',
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

    // Get pins by account
    router.get('/api/pins/account/:accountId', async (request, env) => {
        // Check authentication
        const authResult = await authenticateSession(request, env);
        if (authResult instanceof Response) {
            return authResult;
        }
        
        try {
            const targetAccountId = request.params.accountId;
            const url = new URL(request.url);
            const limit = Math.min(parseInt(url.searchParams.get('limit') || '50'), 100);
            const offset = parseInt(url.searchParams.get('offset') || '0');

            // No permission check required - pins are publicly viewable

            const photos = await env.DB.prepare(`
                SELECT p.*, a.username, a.display_name 
                FROM photos p
                JOIN accounts a ON p.account_id = a.id
                WHERE p.account_id = ?
                ORDER BY p.created_at DESC
                LIMIT ? OFFSET ?
            `).bind(targetAccountId, limit, offset).all();

            const result = photos.results.map(photo => {
                console.log(`📍 Pin ${photo.id}: caption="${photo.caption}", has_photo_data=${!!photo.photo_data}`);
                const parsed = {
                    ...photo,
                    photo_data: JSON.parse(photo.photo_data)
                };
                console.log(`📍 Pin ${photo.id}: photo_data.image_data length=${parsed.photo_data?.image_data?.length || 0}`);
                return parsed;
            });

            return new Response(JSON.stringify(result), {
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Get photos by account error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to get photos',
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

    // Get single pin
    router.get('/api/pins/:id', async (request, env) => {
        // Check authentication
        const authResult = await authenticateSession(request, env);
        if (authResult instanceof Response) {
            return authResult;
        }
        
        try {
            const photoId = request.params.id;
            
            const photo = await env.DB.prepare(`
                SELECT p.*, a.username, a.display_name 
                FROM photos p
                JOIN accounts a ON p.account_id = a.id
                WHERE p.id = ?
            `).bind(photoId).first();

            if (!photo) {
                return new Response(JSON.stringify({
                    error: 'Photo not found'
                }), {
                    status: 404,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            // No permission check required - pins are publicly viewable

            return new Response(JSON.stringify({
                ...photo,
                photo_data: JSON.parse(photo.photo_data)
            }), {
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Get photo error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to get photo',
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

    // Delete pin
    router.delete('/api/pins/:id', async (request, env) => {
        // Check authentication
        const authResult = await authenticateSession(request, env);
        if (authResult instanceof Response) {
            return authResult;
        }
        
        try {
            const photoId = request.params.id;
            const accountId = request.account.id;

            // Check if photo belongs to current user
            const photo = await env.DB.prepare(
                'SELECT account_id FROM photos WHERE id = ?'
            ).bind(photoId).first();

            if (!photo) {
                return new Response(JSON.stringify({
                    error: 'Photo not found'
                }), {
                    status: 404,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            if (photo.account_id !== accountId) {
                return new Response(JSON.stringify({
                    error: 'Permission denied',
                    message: 'You can only delete your own pins'
                }), {
                    status: 403,
                    headers: { 
                        'Content-Type': 'application/json',
                        ...request.corsHeaders 
                    }
                });
            }

            // Delete photo (cascades to timeline entries)
            await env.DB.prepare('DELETE FROM photos WHERE id = ?').bind(photoId).run();

            return new Response(JSON.stringify({ success: true }), {
                headers: { 
                    'Content-Type': 'application/json',
                    ...request.corsHeaders 
                }
            });
        } catch (error) {
            console.error('Delete photo error:', error);
            return new Response(JSON.stringify({
                error: 'Failed to delete photo',
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