import type { IptvContentDescriptor } from '../protocol/payloads';

export type IptvContentKind = 'live' | 'movie' | 'series';

export interface IptvCategory {
  categoryId: string;
  categoryName: string;
  parentId?: number;
}

export interface LiveStream {
  streamId: number;
  name: string;
  streamIcon?: string;
  epgChannelId?: string;
  categoryId: string;
  containerExtensionCode?: number;
}

export interface VodStream {
  streamId: number;
  name: string;
  streamIcon?: string;
  categoryId: string;
  containerExtension: string;
  rating?: number;
  plot?: string;
  cast?: string;
  genre?: string;
  releaseDate?: string;
}

export interface SeriesItem {
  seriesId: number;
  name: string;
  cover?: string;
  categoryId: string;
  plot?: string;
  cast?: string;
  genre?: string;
  rating?: number;
  releaseDate?: string;
  lastModified?: string;
}

export interface SeriesEpisode {
  id: string;
  episodeNum: number;
  title: string;
  containerExtension: string;
  plot?: string;
  duration?: string;
  rating?: number;
  coverBig?: string;
}

export interface SeriesInfo {
  info: Record<string, unknown>;
  seasons: Record<string, SeriesEpisode[]>;
}

export interface CatalogContent {
  id: string;
  title: string;
  subtitle?: string;
  image?: string;
  description?: string;
  descriptor: IptvContentDescriptor;
}
