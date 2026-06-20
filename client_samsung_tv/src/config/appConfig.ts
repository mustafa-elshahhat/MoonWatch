/**
 * Central production configuration for the MoonWatch Samsung TV client.
 *
 * These values mirror the shipped Flutter MoonWatch client so the TV app
 * behaves like the TV version of the same product out of the box:
 *   - Server base URL  -> client/assets/config/appsettings.local.json ("ServerBaseUrl")
 *   - IPTV base URL    -> client/assets/config/appsettings.local.json (IPTV provider)
 *   - API prefix       -> client/lib/core/network/http_client.dart ("/api/v1")
 *   - SignalR hub path -> client/lib/core/constants/app_constants.dart ("/hubs/room")
 *
 * The Server Base URL is the production backend and is used as the default so
 * no manual entry is needed for normal use. Users can still override it under
 * "Advanced server settings". The IPTV provider URL and credentials are NOT
 * shipped — each user must enter their own provider in Settings on first run
 * (mirroring the Flutter client, which keeps provider details out of source via
 * a gitignored appsettings.local.json). This avoids committing a real
 * third-party provider endpoint (and cleartext HTTP) to a public repo.
 */

/** Production MoonWatch backend (SignalR room server + REST API). */
export const PRODUCTION_SERVER_BASE_URL = 'https://moviedate.runasp.net';

/**
 * Default IPTV provider base URL. Intentionally blank — no provider is shipped.
 * The user must enter their own IPTV Base URL (https:// recommended) in
 * Settings; validation blocks playback until one is supplied.
 */
export const DEFAULT_IPTV_BASE_URL = '';

/** REST API version prefix used by the MoonWatch backend. */
export const API_PREFIX = '/api/v1';

/** SignalR hub path for room / watch-party sync. */
export const ROOM_HUB_PATH = '/hubs/room';

/** Human-facing product name. */
export const APP_NAME = 'MoonWatch TV';
