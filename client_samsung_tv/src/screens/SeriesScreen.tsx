import { Fragment, useEffect, useMemo, useState } from 'react';
import { EmptyState, ErrorState, FocusBoundary, Icon, SkeletonGrid, TvButton, TvCard, TvGrid } from '../components';
import { useAutoPagedItems } from '../hooks/useAutoPagedItems';
import { IptvService } from '../iptv/iptvService';
import type { EpisodeContext, EpisodeEntry } from '../iptv/episodeContext';
import type { IptvCategory, SeriesEpisode, SeriesInfo, SeriesItem } from '../iptv/types';
import type { IptvContentDescriptor } from '../protocol/payloads';
import type { TvSettings } from '../settings/settings';
import { validateSettings } from '../settings/settings';
import { userFacingError } from '../utils/format';

/** TV-sized initial/page size — keeps the focusable DOM small on big categories. */
const PAGE_SIZE = 48;

interface FlatEpisode {
  episode: SeriesEpisode;
  season: string;
}

interface SeriesScreenProps {
  settings: TvSettings;
  roomRole?: string;
  onSelect: (descriptor: IptvContentDescriptor, episodeContext?: EpisodeContext) => Promise<void> | void;
  onBack: () => void;
  onSettings: () => void;
}

export function SeriesScreen({ settings, roomRole, onSelect, onBack, onSettings }: SeriesScreenProps) {
  const iptv = useMemo(() => new IptvService(settings), [settings]);
  const [categories, setCategories] = useState<IptvCategory[]>([]);
  const [categoryId, setCategoryId] = useState('0');
  const [series, setSeries] = useState<SeriesItem[]>([]);
  const [selectedSeries, setSelectedSeries] = useState<SeriesItem | undefined>();
  const [seriesInfo, setSeriesInfo] = useState<SeriesInfo | undefined>();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [reloadToken, setReloadToken] = useState(0);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      const validation = validateSettings(settings, 'playback');
      if (validation.length > 0) {
        setError(validation[0]);
        setLoading(false);
        return;
      }
      setError('');
      try {
        const loaded = await iptv.getSeriesCategories();
        if (!cancelled) setCategories([{ categoryId: '0', categoryName: 'All' }, ...loaded]);
      } catch (err) {
        if (!cancelled) setError(userFacingError(err, 'Could not load series categories.'));
      }
    };
    void load();
    return () => { cancelled = true; };
  }, [iptv, settings, reloadToken]);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setLoading(true);
      setError('');
      setSelectedSeries(undefined);
      setSeriesInfo(undefined);
      try {
        const loaded = await iptv.getSeriesList(categoryId);
        if (!cancelled) setSeries(loaded);
      } catch (err) {
        if (!cancelled) setError(userFacingError(err, 'Could not load series.'));
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    return () => { cancelled = true; };
  }, [categoryId, iptv, reloadToken]);

  const openSeries = async (item: SeriesItem) => {
    setSelectedSeries(item);
    setLoading(true);
    setError('');
    try {
      setSeriesInfo(await iptv.getSeriesInfo(String(item.seriesId)));
    } catch (err) {
      setError(userFacingError(err, 'Could not load episodes.'));
    } finally {
      setLoading(false);
    }
  };

  const retry = () => {
    if (selectedSeries) void openSeries(selectedSeries);
    else setReloadToken((value) => value + 1);
  };

  const currentCategory = categories.find((category) => category.categoryId === categoryId)?.categoryName ?? 'All';

  // Flatten every episode in season → episode order. This single ordered list
  // backs both the bounded episode grid and the player's Next Episode context,
  // so the next episode rolls naturally into the next season.
  const flatEpisodes = useMemo<FlatEpisode[]>(() => {
    if (!seriesInfo) return [];
    const seasonKeys = Object.keys(seriesInfo.seasons).sort((a, b) => Number(a) - Number(b));
    return seasonKeys.flatMap((season) => (seriesInfo.seasons[season] ?? []).map((episode) => ({ episode, season })));
  }, [seriesInfo]);

  const episodeEntries = useMemo<EpisodeEntry[]>(
    () => flatEpisodes.map((flat) => ({
      descriptor: episodeToDescriptor(flat.episode),
      season: flat.season,
      episodeNum: flat.episode.episodeNum,
    })),
    [flatEpisodes],
  );

  // Two independent paged views (hooks always run, regardless of which view is
  // showing). Each resets automatically when its source list identity changes.
  const seriesPaged = useAutoPagedItems(series, PAGE_SIZE);
  const episodesPaged = useAutoPagedItems(flatEpisodes, PAGE_SIZE);

  const selectEpisode = (index: number) => {
    const entry = episodeEntries[index];
    if (!entry) return;
    void onSelect(entry.descriptor, {
      seriesTitle: selectedSeries?.name ?? entry.descriptor.title,
      episodes: episodeEntries,
      index,
    });
  };

  if (error) {
    return (
      <FocusBoundary className="screen">
        <ErrorState
          icon={<Icon name="alert" size={30} />}
          title="Series unavailable"
          message={error}
          actionLabel="Try again"
          onAction={retry}
          secondaryLabel="Settings"
          onSecondary={onSettings}
        />
      </FocusBoundary>
    );
  }

  return (
    <FocusBoundary className="screen screen--catalog">
      <header className="screen__header">
        <div>
          <p className="eyebrow">{roomRole === 'guest' ? 'Guest viewing only' : selectedSeries ? 'Choose an episode' : 'Series'}</p>
          <h1>{selectedSeries?.name ?? 'Series'}</h1>
        </div>
        <TvButton variant="quiet" onClick={selectedSeries ? () => setSelectedSeries(undefined) : onBack}>
          <Icon name="back" size={26} /> {selectedSeries ? 'All series' : 'Home'}
        </TvButton>
      </header>

      {!selectedSeries && categories.length > 0 && (
        <div className="category-rail" aria-label="Categories">
          {categories.map((category) => (
            <TvButton
              key={category.categoryId}
              variant={category.categoryId === categoryId ? 'primary' : 'quiet'}
              onClick={() => setCategoryId(category.categoryId)}
            >
              {category.categoryName}
            </TvButton>
          ))}
        </div>
      )}

      {!selectedSeries && (
        <div className="catalog-toolbar">
          <span className="catalog-meta"><strong>{currentCategory}</strong></span>
          {!loading && seriesPaged.total > 0 && (
            <span className="catalog-meta">Showing {seriesPaged.shownCount} of {seriesPaged.total} series</span>
          )}
        </div>
      )}

      {loading ? (
        <SkeletonGrid count={10} />
      ) : selectedSeries && seriesInfo ? (
        flatEpisodes.length === 0 ? (
          <EmptyState icon={<Icon name="series" size={40} />} title="No episodes" hint="This series has no episodes available from the provider." />
        ) : (
          <>
            <TvGrid compact>
              {episodesPaged.visibleItems.map((item, index) => {
                const previous = index > 0 ? episodesPaged.visibleItems[index - 1] : undefined;
                const showHeader = !previous || previous.season !== item.season;
                return (
                  <Fragment key={`${item.season}-${item.episode.id}-${index}`}>
                    {showHeader && <h2 className="season-heading">Season {item.season}</h2>}
                    <TvCard
                      title={item.episode.title}
                      subtitle={`Episode ${item.episode.episodeNum}`}
                      image={item.episode.coverBig || selectedSeries.cover}
                      meta={item.episode.duration}
                      onClick={() => selectEpisode(index)}
                      onFocus={() => episodesPaged.onItemFocus(index)}
                    />
                  </Fragment>
                );
              })}
            </TvGrid>
            {episodesPaged.hasMore && (
              <div ref={episodesPaged.sentinelRef} className="tv-loading-row" aria-hidden="true">
                <span className="tv-loading-row__spinner" />
                <span>Loading more episodes… {episodesPaged.shownCount} of {episodesPaged.total}</span>
              </div>
            )}
          </>
        )
      ) : series.length === 0 ? (
        <EmptyState
          icon={<Icon name="series" size={40} />}
          title="Nothing here yet"
          hint={`No series found in “${currentCategory}”. Try another category.`}
        />
      ) : (
        <>
          <TvGrid>
            {seriesPaged.visibleItems.map((item, index) => (
              <TvCard
                key={item.seriesId}
                title={item.name}
                subtitle={item.genre || item.releaseDate || 'Series'}
                image={item.cover}
                meta={item.rating ? `★ ${item.rating}` : undefined}
                onClick={() => void openSeries(item)}
                onFocus={() => seriesPaged.onItemFocus(index)}
              />
            ))}
          </TvGrid>
          {seriesPaged.hasMore && (
            <div ref={seriesPaged.sentinelRef} className="tv-loading-row" aria-hidden="true">
              <span className="tv-loading-row__spinner" />
              <span>Loading more… {seriesPaged.shownCount} of {seriesPaged.total}</span>
            </div>
          )}
        </>
      )}
    </FocusBoundary>
  );
}

function episodeToDescriptor(episode: SeriesEpisode): IptvContentDescriptor {
  return {
    contentType: 'episode',
    streamId: episode.id,
    containerExtension: episode.containerExtension || 'mp4',
    title: episode.title,
  };
}
