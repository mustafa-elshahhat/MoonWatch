import { useEffect, useMemo, useState } from 'react';
import { EmptyState, ErrorState, FocusBoundary, Icon, SkeletonGrid, TvButton, TvCard, TvGrid } from '../components';
import { IptvService } from '../iptv/iptvService';
import type { IptvCategory, SeriesEpisode, SeriesInfo, SeriesItem } from '../iptv/types';
import type { IptvContentDescriptor } from '../protocol/payloads';
import type { TvSettings } from '../settings/settings';
import { validateSettings } from '../settings/settings';
import { userFacingError } from '../utils/format';

interface SeriesScreenProps {
  settings: TvSettings;
  roomRole?: string;
  onSelect: (descriptor: IptvContentDescriptor) => Promise<void> | void;
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

  const seasons = seriesInfo ? Object.keys(seriesInfo.seasons).sort((a, b) => Number(a) - Number(b)) : [];
  const currentCategory = categories.find((category) => category.categoryId === categoryId)?.categoryName ?? 'All';

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
          {!loading && <span className="catalog-meta">{series.length} {series.length === 1 ? 'series' : 'series'}</span>}
        </div>
      )}

      {loading ? (
        <SkeletonGrid count={10} />
      ) : selectedSeries && seriesInfo ? (
        seasons.length === 0 ? (
          <EmptyState icon={<Icon name="series" size={40} />} title="No episodes" hint="This series has no episodes available from the provider." />
        ) : (
          <div className="season-stack">
            {seasons.map((season) => (
              <section key={season}>
                <h2>Season {season}</h2>
                <TvGrid compact>
                  {seriesInfo.seasons[season].map((episode) => (
                    <TvCard
                      key={episode.id}
                      title={episode.title}
                      subtitle={`Episode ${episode.episodeNum}`}
                      image={episode.coverBig || selectedSeries.cover}
                      meta={episode.duration}
                      onClick={() => void onSelect(episodeToDescriptor(episode))}
                    />
                  ))}
                </TvGrid>
              </section>
            ))}
          </div>
        )
      ) : series.length === 0 ? (
        <EmptyState
          icon={<Icon name="series" size={40} />}
          title="Nothing here yet"
          hint={`No series found in “${currentCategory}”. Try another category.`}
        />
      ) : (
        <TvGrid>
          {series.map((item) => (
            <TvCard
              key={item.seriesId}
              title={item.name}
              subtitle={item.genre || item.releaseDate || 'Series'}
              image={item.cover}
              meta={item.rating ? `★ ${item.rating}` : undefined}
              onClick={() => void openSeries(item)}
            />
          ))}
        </TvGrid>
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
