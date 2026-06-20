import { normalizeBaseUrl } from '../settings/settings';

/**
 * Public, read-only summary of an active room, as returned by the existing
 * `GET /api/v1/rooms` endpoint. Contains no IPTV credentials, no playback URLs
 * and no private playback state — only what is safe to advertise to a guest who
 * is choosing a room to join.
 */
export interface ActiveRoom {
  roomCode: string;
  state: string;
  hostConnected: boolean;
  hasGuest: boolean;
  isJoinable: boolean;
  createdAt?: string;
  contentSet: boolean;
  contentType?: string | null;
  hostRtt?: number;
}

const REQUEST_TIMEOUT_MS = 10000;

/**
 * Fetch the list of active rooms from the MoonWatch room server. This is the
 * same endpoint the Flutter client polls on its Join screen.
 */
export async function fetchActiveRooms(serverBaseUrl: string, signal?: AbortSignal): Promise<ActiveRoom[]> {
  const base = normalizeBaseUrl(serverBaseUrl);
  if (!base) throw new Error('Server is not configured.');

  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  const onAbort = () => controller.abort();
  signal?.addEventListener('abort', onAbort);

  try {
    const response = await fetch(`${base}/api/v1/rooms`, {
      signal: controller.signal,
      headers: { Accept: 'application/json' },
    });
    if (!response.ok) throw new Error(`Room server returned HTTP ${response.status}.`);
    const data = (await response.json()) as { rooms?: unknown };
    const rooms = Array.isArray(data.rooms) ? data.rooms : [];
    return rooms.filter(isRecord).map(parseActiveRoom);
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw new Error('Room server timeout.');
    }
    throw error instanceof Error ? error : new Error('Could not reach the room server.');
  } finally {
    window.clearTimeout(timeout);
    signal?.removeEventListener('abort', onAbort);
  }
}

function parseActiveRoom(json: Record<string, unknown>): ActiveRoom {
  return {
    roomCode: String(json.roomCode ?? ''),
    state: String(json.state ?? 'waiting'),
    hostConnected: Boolean(json.hostConnected),
    hasGuest: Boolean(json.hasGuest),
    isJoinable: json.isJoinable === undefined ? !json.hasGuest : Boolean(json.isJoinable),
    createdAt: typeof json.createdAt === 'string' ? json.createdAt : undefined,
    contentSet: Boolean(json.contentSet),
    contentType: typeof json.contentType === 'string' ? json.contentType : null,
    hostRtt: typeof json.hostRtt === 'number' ? json.hostRtt : undefined,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
