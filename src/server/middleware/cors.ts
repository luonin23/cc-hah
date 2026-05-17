/**
 * CORS middleware - allow local desktop, browser access via IP, and mobile web
 */

// Allow localhost, IP addresses, domain names, and Tauri/asset origins
const ALLOWED_ORIGIN_RE =
  /^(?:https?:\/\/(?:[\w.-]+(?::\d+)?|localhost|127\.0\.0\.1)|tauri:\/\/localhost|asset:\/\/localhost)$/

export function corsHeaders(origin?: string | null): Record<string, string> {
  const allowedOrigin =
    origin && ALLOWED_ORIGIN_RE.test(origin) ? origin : '*'
  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
    'Access-Control-Allow-Credentials': 'true',
    'Access-Control-Max-Age': '86400',
  }
}
