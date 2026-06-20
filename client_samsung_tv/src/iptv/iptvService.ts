import type { TvSettings } from '../settings/settings';
import { sanitizeSettings, validateSettings } from '../settings/settings';
import type {
  IptvCategory,
  LiveStream,
  SeriesEpisode,
  SeriesInfo,
  SeriesItem,
  VodStream,
} from './types';
import type { IptvContentDescriptor } from '../protocol/payloads';

const REQUEST_TIMEOUT_MS = 30000;

export class IptvApiError extends Error {
  constructor(message: string, readonly statusCode?: number) {
    super(message);
    this.name = 'IptvApiError';
  }
}

export class IptvService {
  private readonly settings: TvSettings;
  private readonly categoryCache = new Map<string, IptvCategory[]>();
  private readonly contentCache = new Map<string, unknown[]>();
  private readonly seriesInfoCache = new Map<string, SeriesInfo>();

  constructor(settings: TvSettings) {
    this.settings = sanitizeSettings(settings);
  }

  async verifyCredentials(username = this.settings.iptvUsername, password = this.settings.iptvPassword): Promise<boolean> {
    const candidate = sanitizeSettings({ ...this.settings, iptvUsername: username, iptvPassword: password });
    if (validateSettings(candidate, 'login').length > 0) return false;
    try {
      const data = await this.fetchJson<Record<string, unknown>>(
        this.buildApiUrl('get_server_info', undefined, candidate),
      );
      const userInfo = asRecord(data.user_info);
      return String(userInfo?.auth ?? '') === '1';
    } catch {
      return false;
    }
  }

  async authenticate(): Promise<Record<string, unknown>> {
    this.ensureConfigured('login');
    return this.fetchJson<Record<string, unknown>>(this.buildApiUrl('get_server_info'));
  }

  async getLiveCategories(forceRefresh = false): Promise<IptvCategory[]> {
    return this.getCategories('live', 'get_live_categories', forceRefresh);
  }

  async getVodCategories(forceRefresh = false): Promise<IptvCategory[]> {
    return this.getCategories('movie', 'get_vod_categories', forceRefresh);
  }

  async getSeriesCategories(forceRefresh = false): Promise<IptvCategory[]> {
    return this.getCategories('series', 'get_series_categories', forceRefresh);
  }

  async getLiveStreams(categoryId = '0', forceRefresh = false): Promise<LiveStream[]> {
    const key = `live:${categoryId}`;
    if (!forceRefresh && this.contentCache.has(key)) return this.contentCache.get(key) as LiveStream[];
    const data = await this.fetchJson<unknown[]>(
      this.buildApiUrl('get_live_streams', categoryId === '0' ? undefined : { category_id: categoryId }),
    );
    const streams = data.filter(isRecord).map(parseLiveStream);
    this.contentCache.set(key, streams);
    return streams;
  }

  async getVodStreams(categoryId = '0', forceRefresh = false): Promise<VodStream[]> {
    const key = `movie:${categoryId}`;
    if (!forceRefresh && this.contentCache.has(key)) return this.contentCache.get(key) as VodStream[];
    const data = await this.fetchJson<unknown[]>(
      this.buildApiUrl('get_vod_streams', categoryId === '0' ? undefined : { category_id: categoryId }),
    );
    const streams = data.filter(isRecord).map(parseVodStream);
    this.contentCache.set(key, streams);
    return streams;
  }

  async getSeriesList(categoryId = '0', forceRefresh = false): Promise<SeriesItem[]> {
    const key = `series:${categoryId}`;
    if (!forceRefresh && this.contentCache.has(key)) return this.contentCache.get(key) as SeriesItem[];
    const data = await this.fetchJson<unknown[]>(
      this.buildApiUrl('get_series', categoryId === '0' ? undefined : { category_id: categoryId }),
    );
    const series = data.filter(isRecord).map(parseSeriesItem);
    this.contentCache.set(key, series);
    return series;
  }

  async getSeriesInfo(seriesId: string, forceRefresh = false): Promise<SeriesInfo> {
    if (!forceRefresh && this.seriesInfoCache.has(seriesId)) return this.seriesInfoCache.get(seriesId)!;
    const data = await this.fetchJson<Record<string, unknown>>(
      this.buildApiUrl('get_series_info', { series_id: seriesId }),
    );
    const info = parseSeriesInfo(data);
    this.seriesInfoCache.set(seriesId, info);
    return info;
  }

  livePlaybackUrl(streamId: string, extension?: string | null): string {
    this.ensureConfigured('playback');
    const fileName = extension ? `${streamId}.${extension}` : streamId;
    return this.buildPlaybackUrl([this.settings.iptvUsername, this.settings.iptvPassword, fileName]);
  }

  vodPlaybackUrl(streamId: string, containerExtension = 'mp4'): string {
    this.ensureConfigured('playback');
    const fileName = containerExtension ? `${streamId}.${containerExtension}` : streamId;
    return this.buildPlaybackUrl(['movie', this.settings.iptvUsername, this.settings.iptvPassword, fileName]);
  }

  episodePlaybackUrl(streamId: string, containerExtension = 'mp4'): string {
    this.ensureConfigured('playback');
    const fileName = containerExtension ? `${streamId}.${containerExtension}` : streamId;
    return this.buildPlaybackUrl(['series', this.settings.iptvUsername, this.settings.iptvPassword, fileName]);
  }

  resolvePlaybackUrl(descriptor: IptvContentDescriptor): string {
    if (descriptor.contentType === 'live') {
      return this.livePlaybackUrl(descriptor.streamId, descriptor.containerExtension);
    }
    if (descriptor.contentType === 'movie') {
      return this.vodPlaybackUrl(descriptor.streamId, descriptor.containerExtension ?? 'mp4');
    }
    return this.episodePlaybackUrl(descriptor.streamId, descriptor.containerExtension ?? 'mp4');
  }

  private async getCategories(kind: string, action: string, forceRefresh: boolean): Promise<IptvCategory[]> {
    this.ensureConfigured('iptv');
    if (!forceRefresh && this.categoryCache.has(kind)) return this.categoryCache.get(kind)!;
    const data = await this.fetchJson<unknown[]>(this.buildApiUrl(action));
    const categories = data.filter(isRecord).map(parseCategory);
    this.categoryCache.set(kind, categories);
    return categories;
  }

  private ensureConfigured(scope: 'iptv' | 'login' | 'playback'): void {
    const errors = validateSettings(this.settings, scope);
    if (errors.length) throw new IptvApiError(errors[0]);
  }

  private buildApiUrl(
    action: string,
    extra?: Record<string, string>,
    settings: TvSettings = this.settings,
  ): string {
    const url = new URL(settings.iptvBaseUrl);
    url.pathname = joinUrlPath(url.pathname, 'player_api.php');
    url.search = '';
    url.searchParams.set('username', settings.iptvUsername.trim());
    url.searchParams.set('password', settings.iptvPassword);
    url.searchParams.set('action', action);
    for (const [key, value] of Object.entries(extra ?? {})) {
      url.searchParams.set(key, value);
    }
    return url.toString();
  }

  private buildPlaybackUrl(pathSegments: string[]): string {
    const url = new URL(this.settings.iptvBaseUrl);
    const existing = url.pathname.split('/').filter(Boolean);
    url.pathname = `/${[...existing, ...pathSegments].map(encodeURIComponent).join('/')}`;
    url.search = '';
    return url.toString();
  }

  private async fetchJson<T>(url: string): Promise<T> {
    this.ensureConfigured('iptv');
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    try {
      const response = await fetch(url, {
        signal: controller.signal,
        headers: {
          Accept: 'application/json, text/plain, */*',
        },
      });
      if (!response.ok) {
        if (response.status === 403) throw new IptvApiError('IPTV authentication failed, check credentials.', 403);
        throw new IptvApiError(`IPTV request failed with HTTP ${response.status}.`, response.status);
      }
      return (await response.json()) as T;
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') {
        throw new IptvApiError('IPTV server timeout.');
      }
      if (error instanceof IptvApiError) throw error;
      throw new IptvApiError('Could not reach IPTV provider. Check network, provider URL, and CORS for browser development.');
    } finally {
      window.clearTimeout(timeout);
    }
  }
}

function joinUrlPath(basePath: string, fileName: string): string {
  const parts = basePath.split('/').filter(Boolean);
  return `/${[...parts, fileName].join('/')}`;
}

function parseCategory(json: Record<string, unknown>): IptvCategory {
  return {
    categoryId: stringValue(json.category_id),
    categoryName: stringValue(json.category_name, 'Unknown'),
    parentId: optionalNumber(json.parent_id),
  };
}

function parseLiveStream(json: Record<string, unknown>): LiveStream {
  return {
    streamId: intValue(json.stream_id),
    name: stringValue(json.name, 'Unknown Channel'),
    streamIcon: optionalString(json.stream_icon),
    epgChannelId: optionalString(json.epg_channel_id),
    categoryId: stringValue(json.category_id),
    containerExtensionCode: optionalNumber(json.container_extension),
  };
}

function parseVodStream(json: Record<string, unknown>): VodStream {
  return {
    streamId: intValue(json.stream_id),
    name: stringValue(json.name, 'Unknown Movie'),
    streamIcon: optionalString(json.stream_icon),
    categoryId: stringValue(json.category_id),
    containerExtension: stringValue(json.container_extension, 'mp4'),
    rating: optionalNumber(json.rating),
    plot: optionalString(json.plot),
    cast: optionalString(json.cast),
    genre: optionalString(json.genre),
    releaseDate: optionalString(json.releasedate),
  };
}

function parseSeriesItem(json: Record<string, unknown>): SeriesItem {
  return {
    seriesId: intValue(json.series_id),
    name: stringValue(json.name, 'Unknown Series'),
    cover: optionalString(json.cover),
    categoryId: stringValue(json.category_id),
    plot: optionalString(json.plot),
    cast: optionalString(json.cast),
    genre: optionalString(json.genre),
    rating: optionalNumber(json.rating),
    releaseDate: optionalString(json.releaseDate),
    lastModified: optionalString(json.last_modified),
  };
}

function parseSeriesInfo(json: Record<string, unknown>): SeriesInfo {
  const info = asRecord(json.info) ?? {};
  const episodes = asRecord(json.episodes) ?? {};
  const seasons: Record<string, SeriesEpisode[]> = {};
  for (const [seasonNumber, value] of Object.entries(episodes)) {
    if (!Array.isArray(value)) continue;
    seasons[seasonNumber] = value.filter(isRecord).map(parseSeriesEpisode);
  }
  return { info, seasons };
}

function parseSeriesEpisode(json: Record<string, unknown>): SeriesEpisode {
  const info = asRecord(json.info);
  return {
    id: stringValue(json.id),
    episodeNum: intValue(json.episode_num),
    title: stringValue(json.title, 'Episode'),
    containerExtension: stringValue(json.container_extension, 'mp4'),
    plot: optionalString(json.plot),
    duration: optionalString(json.duration),
    rating: optionalNumber(json.rating),
    coverBig: optionalString(info?.movie_image) ?? optionalString(info?.cover_big),
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return isRecord(value) ? value : undefined;
}

function stringValue(value: unknown, fallback = ''): string {
  if (value === null || value === undefined) return fallback;
  const text = String(value);
  return text || fallback;
}

function optionalString(value: unknown): string | undefined {
  const text = stringValue(value).trim();
  return text || undefined;
}

function intValue(value: unknown): number {
  if (typeof value === 'number') return Math.trunc(value);
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

function optionalNumber(value: unknown): number | undefined {
  if (value === null || value === undefined || value === '') return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}
