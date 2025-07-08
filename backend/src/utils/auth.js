/**
 * Authentication utility functions
 */

import { subtle } from 'crypto';

/**
 * Generate a secure session token
 */
export function generateSessionToken() {
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
}

/**
 * Hash a token for secure storage
 */
export async function hashToken(token) {
    const encoder = new TextEncoder();
    const data = encoder.encode(token);
    const hashBuffer = await subtle.digest('SHA-256', data);
    const hashArray = new Uint8Array(hashBuffer);
    return Array.from(hashArray, byte => byte.toString(16).padStart(2, '0')).join('');
}

/**
 * Verify a token against its hash
 */
export async function verifyToken(token, hash) {
    const tokenHash = await hashToken(token);
    return tokenHash === hash;
}

/**
 * Generate a secure random string for various purposes
 */
export function generateSecureRandom(length = 32) {
    const array = new Uint8Array(length);
    crypto.getRandomValues(array);
    return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
}