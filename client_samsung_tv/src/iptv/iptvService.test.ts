import { describe, expect, it } from 'vitest';
import { IptvService } from './iptvService';
import type { TvSettings } from '../settings/settings';

const settings: TvSettings = {
  serverBaseUrl: 'https://moviedate.runasp.net',
  iptvBaseUrl: 'http://provider.example:8080',
  iptvUsername: 'user',
  iptvPassword: 'pass',
  deviceName: '',
};

describe('IPTV playback URL builders', () => {
  const svc = new IptvService(settings);

  it('builds live URLs as base/user/pass/streamId.ext', () => {
    expect(svc.livePlaybackUrl('123', 'ts')).toBe('http://provider.example:8080/user/pass/123.ts');
  });

  it('builds movie URLs under /movie', () => {
    expect(svc.vodPlaybackUrl('456', 'mp4')).toBe('http://provider.example:8080/movie/user/pass/456.mp4');
  });

  it('builds episode URLs under /series', () => {
    expect(svc.episodePlaybackUrl('789', 'mkv')).toBe('http://provider.example:8080/series/user/pass/789.mkv');
  });

  it('resolvePlaybackUrl dispatches by content type', () => {
    expect(
      svc.resolvePlaybackUrl({ contentType: 'live', streamId: '1', containerExtension: 'ts', title: 'x' }),
    ).toBe('http://provider.example:8080/user/pass/1.ts');
    expect(
      svc.resolvePlaybackUrl({ contentType: 'movie', streamId: '2', containerExtension: null, title: 'x' }),
    ).toBe('http://provider.example:8080/movie/user/pass/2.mp4');
    expect(
      svc.resolvePlaybackUrl({ contentType: 'episode', streamId: '3', containerExtension: 'mp4', title: 'x' }),
    ).toBe('http://provider.example:8080/series/user/pass/3.mp4');
  });
});
