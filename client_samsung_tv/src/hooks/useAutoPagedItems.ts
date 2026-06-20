import { useCallback, useEffect, useRef } from 'react';
import { usePagedItems, type PagedItems } from './usePagedItems';

export interface AutoPagedItems<T> extends PagedItems<T> {
  /**
   * Call from each rendered card's `onFocus` with its index. When the remote
   * focuses an item near the end of the visible slice, the next page is appended
   * automatically — the focused card stays mounted, so focus never jumps and the
   * grid never scrolls back to the top.
   */
  onItemFocus: (index: number) => void;
  /**
   * Attach to a non-focusable element at the bottom of the list. An
   * IntersectionObserver appends the next page as that sentinel approaches the
   * viewport, so plain scrolling (mouse wheel / page-down) also lazy-loads.
   */
  sentinelRef: React.RefObject<HTMLDivElement | null>;
}

/** How close to the end of the visible slice focus must get before auto-loading. */
const NEAR_END_THRESHOLD = 10;

/**
 * In-memory paging that loads more automatically — no "Load more" button.
 *
 * Wraps {@link usePagedItems}: the full list is kept in memory but only one
 * TV-sized page is rendered until either the remote focuses near the end of the
 * slice or the bottom sentinel scrolls into view. Both triggers are cheap because
 * appending a page is just a synchronous re-slice of data already in memory.
 */
export function useAutoPagedItems<T>(items: T[], pageSize = 48): AutoPagedItems<T> {
  const paged = usePagedItems(items, pageSize);
  const { hasMore, loadMore, shownCount } = paged;
  const sentinelRef = useRef<HTMLDivElement | null>(null);

  const onItemFocus = useCallback(
    (index: number) => {
      if (hasMore && index >= shownCount - NEAR_END_THRESHOLD) loadMore();
    },
    [hasMore, loadMore, shownCount],
  );

  useEffect(() => {
    const sentinel = sentinelRef.current;
    if (!sentinel || !hasMore) return;
    // The catalog screen scrolls inside its own `.screen` element, so observe
    // against that scroll container rather than the (non-scrolling) viewport.
    const root = sentinel.closest('.screen') as Element | null;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) loadMore();
      },
      { root, rootMargin: '600px 0px' },
    );
    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [hasMore, loadMore, shownCount]);

  return { ...paged, onItemFocus, sentinelRef };
}
