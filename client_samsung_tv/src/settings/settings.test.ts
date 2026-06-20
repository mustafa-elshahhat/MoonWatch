import { beforeEach, describe, expect, it } from 'vitest';
import {
  defaultSettings,
  loadSettings,
  normalizeBaseUrl,
  sanitizeSettings,
  saveSettings,
  validateSettings,
  type TvSettings,
} from './settings';
import { PRODUCTION_SERVER_BASE_URL } from '../config/appConfig';

describe('settings defaults', () => {
  beforeEach(() => window.localStorage.clear());

  it('ships the production server but no IPTV provider (TV-004)', () => {
    expect(defaultSettings.serverBaseUrl).toBe(PRODUCTION_SERVER_BASE_URL);
    expect(defaultSettings.iptvBaseUrl).toBe('');
    expect(defaultSettings.iptvUsername).toBe('');
    expect(defaultSettings.iptvPassword).toBe('');
  });

  it('returns defaults when nothing is stored', () => {
    expect(loadSettings()).toEqual(defaultSettings);
  });

  it('keeps a blank IPTV base URL blank, forcing user entry (TV-004)', () => {
    saveSettings({ ...defaultSettings, iptvBaseUrl: '' });
    expect(loadSettings().iptvBaseUrl).toBe('');
  });

  it('falls back to the production server when a stored server URL is blank', () => {
    window.localStorage.setItem('moonwatch.tv.settings.v1', JSON.stringify({ serverBaseUrl: '' }));
    expect(loadSettings().serverBaseUrl).toBe(PRODUCTION_SERVER_BASE_URL);
  });
});

describe('settings validation', () => {
  const base: TvSettings = {
    serverBaseUrl: 'https://moviedate.runasp.net',
    iptvBaseUrl: 'http://provider.example:8080',
    iptvUsername: 'user',
    iptvPassword: 'pass',
    deviceName: '',
  };

  it('passes with full valid settings', () => {
    expect(validateSettings(base, 'all')).toEqual([]);
  });

  it('requires an IPTV base URL for playback', () => {
    expect(validateSettings({ ...base, iptvBaseUrl: '' }, 'playback').length).toBeGreaterThan(0);
  });

  it('requires credentials for login', () => {
    expect(validateSettings({ ...base, iptvUsername: '', iptvPassword: '' }, 'login')).toHaveLength(2);
  });

  it('rejects non-http(s) URLs', () => {
    expect(validateSettings({ ...base, serverBaseUrl: 'ftp://x' }, 'server')).toHaveLength(1);
  });
});

describe('sanitizeSettings', () => {
  it('trims whitespace and trailing slashes but preserves the password verbatim', () => {
    const s = sanitizeSettings({
      serverBaseUrl: ' https://x/ ',
      iptvBaseUrl: 'http://y//',
      iptvUsername: '  u ',
      iptvPassword: ' p ',
      deviceName: ' tv ',
    });
    expect(s.serverBaseUrl).toBe('https://x');
    expect(s.iptvBaseUrl).toBe('http://y');
    expect(s.iptvUsername).toBe('u');
    expect(s.iptvPassword).toBe(' p ');
    expect(s.deviceName).toBe('tv');
  });

  it('normalizeBaseUrl strips trailing slashes', () => {
    expect(normalizeBaseUrl('http://a/b/')).toBe('http://a/b');
  });
});
