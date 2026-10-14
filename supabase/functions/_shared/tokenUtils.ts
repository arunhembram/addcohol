// Cryptographic and security utilities for payment acknowledgement

/**
 * Computes a SHA-256 hex string from an opaque QR token.
 * Prevents raw token exposure in database records.
 */
export async function hashQrToken(token: string): Promise<string> {
  const normalized = token.trim();
  const encoder = new TextEncoder();
  const data = encoder.encode(normalized);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Generates an opaque, cryptographically-secure random token for QR display.
 * Contains NO amounts, NO secrets, NO phone numbers, NO database IDs.
 */
export function generateOpaqueQrToken(): string {
  const randomBytes = new Uint8Array(16);
  crypto.getRandomValues(randomBytes);
  const hex = Array.from(randomBytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  return `PAYACK_${hex}`;
}

// In-memory sliding window rate limiter for edge function instances
const rateLimitMap = new Map<string, number[]>();

export function checkRateLimit(key: string, maxRequests: number, windowSeconds: number): boolean {
  const now = Date.now();
  const windowMs = windowSeconds * 1000;
  const timestamps = rateLimitMap.get(key) || [];
  
  // Filter out timestamps outside window
  const validTimestamps = timestamps.filter((ts) => now - ts < windowMs);
  
  if (validTimestamps.length >= maxRequests) {
    rateLimitMap.set(key, validTimestamps);
    return false; // Rate limit exceeded
  }

  validTimestamps.push(now);
  rateLimitMap.set(key, validTimestamps);
  return true; // Allowed
}
