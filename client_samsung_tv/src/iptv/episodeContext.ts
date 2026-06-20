import type { IptvContentDescriptor } from '../protocol/payloads';

/** One episode in series order, with the season/number used for the "Up next" hint. */
export interface EpisodeEntry {
  descriptor: IptvContentDescriptor;
  season: string;
  episodeNum: number;
}

/**
 * Client-only navigation context that lets the player jump to the next episode.
 *
 * This is never sent over SignalR — only the plain {@link IptvContentDescriptor}
 * crosses the wire (unchanged protocol). The host resolves the next episode
 * locally and syncs it to guests via the existing SetContent flow; guests never
 * receive this context, so the Next Episode control stays host/solo-only.
 */
export interface EpisodeContext {
  seriesTitle: string;
  /** All episodes flattened in season → episode order. */
  episodes: EpisodeEntry[];
  /** Index of the currently playing episode within {@link episodes}. */
  index: number;
}

export interface NextEpisode {
  entry: EpisodeEntry;
  context: EpisodeContext;
}

/**
 * The episode after the current one in series order (rolls over to the first
 * episode of the next season). Returns undefined when already at the last episode.
 */
export function nextEpisode(context: EpisodeContext): NextEpisode | undefined {
  const nextIndex = context.index + 1;
  if (nextIndex < 0 || nextIndex >= context.episodes.length) return undefined;
  return { entry: context.episodes[nextIndex], context: { ...context, index: nextIndex } };
}

/** Short "S01·E02" style label for an episode entry. */
export function episodeLabel(entry: EpisodeEntry): string {
  const season = entry.season.padStart(2, '0');
  const ep = String(entry.episodeNum).padStart(2, '0');
  return `S${season}·E${ep}`;
}
