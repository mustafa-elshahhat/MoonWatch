import { describe, expect, it } from 'vitest';
import { episodeLabel, nextEpisode, type EpisodeContext, type EpisodeEntry } from './episodeContext';

function ep(season: string, episodeNum: number): EpisodeEntry {
  return {
    season,
    episodeNum,
    descriptor: {
      contentType: 'episode',
      streamId: `${season}-${episodeNum}`,
      containerExtension: 'mp4',
      title: `S${season}E${episodeNum}`,
    },
  };
}

describe('nextEpisode', () => {
  const episodes = [ep('1', 1), ep('1', 2), ep('2', 1)];

  it('advances within a season', () => {
    const next = nextEpisode({ seriesTitle: 'Show', episodes, index: 0 });
    expect(next?.entry.episodeNum).toBe(2);
    expect(next?.context.index).toBe(1);
  });

  it('rolls over to the next season', () => {
    const next = nextEpisode({ seriesTitle: 'Show', episodes, index: 1 });
    expect(next?.entry.season).toBe('2');
    expect(next?.entry.episodeNum).toBe(1);
  });

  it('returns undefined at the last episode', () => {
    expect(nextEpisode({ seriesTitle: 'Show', episodes, index: 2 })).toBeUndefined();
  });
});

describe('episodeLabel', () => {
  it('zero-pads season and episode', () => {
    expect(episodeLabel(ep('1', 2))).toBe('S01·E02');
    expect(episodeLabel(ep('10', 12))).toBe('S10·E12');
  });
});
