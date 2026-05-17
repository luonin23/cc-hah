import { getDefaultBaseUrl, setBaseUrl } from '../api/client'

export function isTauriRuntime() {
  if (typeof window === 'undefined') return false
  return '__TAURI_INTERNALS__' in window || '__TAURI__' in window
}

/**
 * Attempt to auto-detect the server URL.
 * - Tauri: get from native sidecar
 * - Browser: try the page origin first (same-server access), then query param, then default
 */
export async function initializeDesktopServerUrl() {
  const fallbackUrl = getDefaultBaseUrl()
  const queryUrl =
    typeof window !== 'undefined'
      ? new URLSearchParams(window.location.search).get('serverUrl')
      : null

  if (!isTauriRuntime()) {
    // Browser mode: prefer same origin (server hosts frontend on :2024 and backend on :3456)
    const pageOrigin = typeof window !== 'undefined'
      ? window.location.origin  // e.g. http://156.245.144.135:2024
      : null

    // Derive the backend URL from the frontend origin (port 2024 -> port 3456)
    let autoDetectedUrl: string | null = null
    if (pageOrigin) {
      try {
        const u = new URL(pageOrigin)
        autoDetectedUrl = u.protocol + '//' + u.hostname + ':3456'
      } catch { /* ignore */ }
    }

    // Priority: query param > auto-detected > fallback
    const candidates = [
      queryUrl?.trim(),
      autoDetectedUrl,
      fallbackUrl,
    ].filter(Boolean) as string[]

    for (const candidate of candidates) {
      try {
        await waitForHealth(candidate)
        setBaseUrl(candidate)
        return candidate
      } catch {
        console.log('[desktop] Server URL ' + candidate + ' healthcheck failed, trying next...')
      }
    }

    // All failed - use fallback anyway but throw
    setBaseUrl(fallbackUrl)
    throw new Error(
      'Could not reach server. Tried: ' + candidates.join(', ') + '. Falling back to ' + fallbackUrl
    )
  }

  try {
    const { invoke } = await import('@tauri-apps/api/core')
    const serverUrl = await invoke<string>('get_server_url')
    setBaseUrl(serverUrl)
    await waitForHealth(serverUrl)
    return serverUrl
  } catch (error) {
    const message =
      error instanceof Error ? error.message : 'desktop server startup failed: ' + String(error)
    console.error('[desktop] Failed to initialize desktop server URL', error)
    throw new Error(message || 'desktop server startup failed (fallback would be ' + fallbackUrl + ')')
  }
}

async function waitForHealth(serverUrl: string) {
  let lastError: unknown

  for (let attempt = 0; attempt < 30; attempt++) {
    try {
      const response = await fetch(serverUrl + '/health', {
        method: 'GET',
        mode: 'cors',
        credentials: 'same-origin',
        cache: 'no-store',
        headers: {
          'Accept': 'application/json',
        },
      })
      if (response.ok) {
        return
      }
      lastError = new Error('healthcheck returned ' + response.status)
    } catch (error) {
      lastError = error
    }

    await new Promise((resolve) => setTimeout(resolve, 250))
  }

  throw new Error(
    lastError instanceof Error
      ? 'Local server healthcheck failed: ' + lastError.message
      : 'Local server healthcheck failed',
  )
}
