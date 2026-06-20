import { DEFAULT_IPTV_BASE_URL, PRODUCTION_SERVER_BASE_URL } from '../config/appConfig';

const SETTINGS_KEY = 'moonwatch.tv.settings.v1';

export interface TvSettings {
  serverBaseUrl: string;
  iptvBaseUrl: string;
  iptvUsername: string;
  iptvPassword: string;
  deviceName: string;
}

export type SettingsValidationScope = 'server' | 'iptv' | 'login' | 'playback' | 'all';

/**
 * Production defaults. The server URL points at the same backend the Flutter
 * client uses. No IPTV provider is shipped: the IPTV base URL and credentials
 * are blank by default, so a fresh TV must enter its own provider details
 * before playback. Stored user values always win.
 */
export const defaultSettings: TvSettings = {
  serverBaseUrl: PRODUCTION_SERVER_BASE_URL,
  iptvBaseUrl: DEFAULT_IPTV_BASE_URL,
  iptvUsername: '',
  iptvPassword: '',
  deviceName: '',
};

/** True when the Server Base URL still matches the bundled production default. */
export function isDefaultServer(settings: TvSettings): boolean {
  return normalizeBaseUrl(settings.serverBaseUrl) === normalizeBaseUrl(PRODUCTION_SERVER_BASE_URL);
}

export function loadSettings(): TvSettings {
  try {
    const raw = window.localStorage.getItem(SETTINGS_KEY);
    if (!raw) return { ...defaultSettings };
    const parsed = JSON.parse(raw) as Partial<TvSettings>;
    const merged = sanitizeSettings({ ...defaultSettings, ...parsed });
    // Fall back to the production server default if a stored server URL is
    // blank, so existing installs are never stranded without a backend. The
    // IPTV base URL is intentionally NOT defaulted — a blank value stays blank
    // so the user is forced to enter their own provider (no provider shipped).
    return {
      ...merged,
      serverBaseUrl: merged.serverBaseUrl || defaultSettings.serverBaseUrl,
    };
  } catch {
    return { ...defaultSettings };
  }
}

export function saveSettings(settings: TvSettings): TvSettings {
  const sanitized = sanitizeSettings(settings);
  window.localStorage.setItem(SETTINGS_KEY, JSON.stringify(sanitized));
  return sanitized;
}

export function sanitizeSettings(settings: TvSettings): TvSettings {
  return {
    serverBaseUrl: normalizeBaseUrl(settings.serverBaseUrl),
    iptvBaseUrl: normalizeBaseUrl(settings.iptvBaseUrl),
    iptvUsername: settings.iptvUsername.trim(),
    iptvPassword: settings.iptvPassword,
    deviceName: settings.deviceName.trim(),
  };
}

export function normalizeBaseUrl(value: string): string {
  return value.trim().replace(/\/+$/, '');
}

export function validateSettings(settings: TvSettings, scope: SettingsValidationScope = 'all'): string[] {
  const candidate = sanitizeSettings(settings);
  const errors: string[] = [];
  const needsServer = scope === 'server' || scope === 'all';
  const needsIptv = scope === 'iptv' || scope === 'login' || scope === 'playback' || scope === 'all';
  const needsCredentials = scope === 'login' || scope === 'playback' || scope === 'all';

  if (needsServer) {
    if (!candidate.serverBaseUrl) errors.push('Server Base URL is required.');
    else if (!isHttpUrl(candidate.serverBaseUrl)) errors.push('Server Base URL must start with http:// or https://.');
  }

  if (needsIptv) {
    if (!candidate.iptvBaseUrl) errors.push('IPTV Base URL is required.');
    else if (!isHttpUrl(candidate.iptvBaseUrl)) errors.push('IPTV Base URL must start with http:// or https://.');
  }

  if (needsCredentials) {
    if (!candidate.iptvUsername) errors.push('IPTV username is required.');
    if (!candidate.iptvPassword) errors.push('IPTV password is required.');
  }

  return errors;
}

export function hasServerSettings(settings: TvSettings): boolean {
  return validateSettings(settings, 'server').length === 0;
}

export function hasPlaybackSettings(settings: TvSettings): boolean {
  return validateSettings(settings, 'playback').length === 0;
}

function isHttpUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
}
