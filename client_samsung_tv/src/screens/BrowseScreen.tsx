import { useEffect, useMemo, useState } from 'react';
import { Badge, EmptyState, ErrorState, FocusBoundary, Icon, SkeletonGrid, TvButton, TvCard, TvGrid } from '../components';
import { useAutoPagedItems } from '../hooks/useAutoPagedItems';
import { IptvService } from '../iptv/iptvService';
import type { CatalogContent, IptvCategory, LiveStream, VodStream } from '../iptv/types';
import type { IptvContentDescriptor } from '../protocol/payloads';
import type { TvSettings } from '../settings/settings';
import { validateSettings } from '../settings/settings';
import { userFacingError } from '../utils/format';

/** TV-sized initial/page size — keeps the focusable DOM small on big categories. */
const PAGE_SIZE = 48;

interface BrowseScreenProps {
  kind: 'live' | 'movie';
  settings: TvSettings;
  roomRole?: string;
  onSelect: (descriptor: IptvContentDescriptor) => Promise<void> | void;
  onBack: () => void;
  onSettings: () => void;
}

export function BrowseScreen({ kind, settings, roomRole, onSelect, onBack, onSettings }: BrowseScreenProps) {
  const [categories, setCategories] = useState<IptvCategory[]>([]);
  const [selectedCategory, setSelectedCategory] = useState('0');
  const [items, setItems] = useState<CatalogContent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [reloadToken, setReloadToken] = useState(0);
  const iptv = useMemo(() => new IptvService(settings), [settings]);
  const title = kind === 'live' ? 'Live TV' : 'Movies';

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
        const loaded = kind === 'live' ? await iptv.getLiveCategories() : await iptv.getVodCategories();
        if (cancelled) return;
        setCategories([{ categoryId: '0', categoryName: 'All' }, ...loaded]);
      } catch (err) {
        if (!cancelled) setError(userFacingError(err, `Could not load ${title} categories.`));
      }
    };
    void load();
    return () => { cancelled = true; };
  }, [iptv, kind, settings, title, reloadToken]);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setLoading(true);
      setError('');
      try {
        const loaded = kind === 'live'
          ? (await iptv.getLiveStreams(selectedCategory)).map(liveToContent)
          : (await iptv.getVodStreams(selectedCategory)).map(vodToContent);
        if (!cancelled) setItems(loaded);
      } catch (err) {
        if (!cancelled) setError(userFacingError(err, `Could not load ${title}.`));
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    return () => { cancelled = true; };
  }, [iptv, kind, selectedCategory, title, reloadToken]);

  const retry = () => setReloadToken((value) => value + 1);
  const currentCategory = categories.find((category) => category.categoryId === selectedCategory)?.categoryName ?? 'All';
  // Render the (possibly huge) list one page at a time, appending more
  // automatically as the remote nears the end. Page auto-resets when `items`
  // changes — i.e. when the category changes or the list reloads.
  const { visibleItems, total, shownCount, hasMore, onItemFocus, sentinelRef } = useAutoPagedItems(items, PAGE_SIZE);

  return (
    <FocusBoundary className="screen screen--catalog">
      <header className="screen__header">
        <div>
          <p className="eyebrow">{roomRole === 'guest' ? 'Guest viewing only' : kind === 'live' ? 'Live channels' : 'On demand'}</p>
          <h1>{title}</h1>
        </div>
        <TvButton variant="quiet" onClick={onBack}><Icon name="back" size={26} /> Home</TvButton>
      </header>

      {categories.length > 0 && (
        <div className="category-rail" aria-label="Categories">
          {categories.map((category) => (
            <TvButton
              key={category.categoryId}
              variant={category.categoryId === selectedCategory ? 'primary' : 'quiet'}
              onClick={() => setSelectedCategory(category.categoryId)}
            >
              {category.categoryName}
            </TvButton>
          ))}
        </div>
      )}

      <div className="catalog-toolbar">
        <span className="catalog-meta"><strong>{currentCategory}</strong></span>
        {!loading && !error && total > 0 && (
          <span className="catalog-meta">Showing {shownCount} of {total} {total === 1 ? 'item' : 'items'}</span>
        )}
      </div>

      {error ? (
        <ErrorState
          icon={<Icon name="alert" size={30} />}
          title={`${title} unavailable`}
          message={error}
          actionLabel="Try again"
          onAction={retry}
          secondaryLabel="Settings"
          onSecondary={onSettings}
        />
      ) : loading ? (
        <SkeletonGrid count={kind === 'live' ? 8 : 10} />
      ) : items.length === 0 ? (
        <EmptyState
          icon={<Icon name={kind === 'live' ? 'live' : 'movie'} size={40} />}
          title="Nothing here yet"
          hint={`No ${title.toLowerCase()} found in “${currentCategory}”. Try another category.`}
        />
      ) : (
        <>
          <TvGrid>
            {visibleItems.map((item, index) => (
              <TvCard
                key={item.id}
                variant={kind === 'live' ? 'live' : 'poster'}
                title={item.title}
                subtitle={item.subtitle}
                image={item.image}
                meta={item.description}
                badges={kind === 'live' ? <Badge variant="live" dot>Live</Badge> : undefined}
                onClick={() => void onSelect(item.descriptor)}
                onFocus={() => onItemFocus(index)}
              />
            ))}
          </TvGrid>
          {hasMore && (
            <div ref={sentinelRef} className="tv-loading-row" aria-hidden="true">
              <span className="tv-loading-row__spinner" />
              <span>Loading more… {shownCount} of {total}</span>
            </div>
          )}
        </>
      )}
    </FocusBoundary>
  );
}

function liveToContent(stream: LiveStream): CatalogContent {
  return {
    id: `live:${stream.streamId}`,
    title: stream.name,
    subtitle: stream.epgChannelId || 'Live channel',
    image: stream.streamIcon,
    descriptor: {
      contentType: 'live',
      streamId: String(stream.streamId),
      containerExtension: null,
      title: stream.name,
    },
  };
}

function vodToContent(stream: VodStream): CatalogContent {
  return {
    id: `movie:${stream.streamId}`,
    title: stream.name,
    subtitle: stream.genre || stream.releaseDate || 'Movie',
    image: stream.streamIcon,
    description: stream.rating ? `★ ${stream.rating}` : undefined,
    descriptor: {
      contentType: 'movie',
      streamId: String(stream.streamId),
      containerExtension: stream.containerExtension || 'mp4',
      title: stream.name,
    },
  };
}
