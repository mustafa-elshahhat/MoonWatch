import { useCallback, useMemo, useRef, useState } from 'react';

export interface PagedItems<T> {
  /** The slice that should actually be rendered. */
  visibleItems: T[];
  /** Total number of items in the (already filtered) source list. */
  total: number;
  /** How many items are currently visible. */
  shownCount: number;
  /** Whether another page can be appended. */
  hasMore: boolean;
  /** Append the next page. Safe to call when !hasMore (no-op). */
  loadMore: () => void;
}

/**
 * Render a large in-memory list one TV-sized page at a time.
 *
 * The full list is kept in memory but only `pageSize` items are rendered until
 * the caller asks for more — this keeps the DOM (and the number of focusable
 * elements the remote has to walk) small on big "All" categories.
 *
 * The page resets to the first page automatically whenever the source list
 * identity changes (new category, new search/filter result). Pass a stable
 * (memoized) array so the reset only fires when the data really changes.
 */
export function usePagedItems<T>(items: T[], pageSize = 48): PagedItems<T> {
  const [page, setPage] = useState(1);

  // Reset to the first page synchronously when the source list changes, using
  // React's "adjust state during render" pattern. `effectivePage` makes even a
  // discarded render show the correct first page, so there is never a flash of
  // a larger page before an effect could run.
  const prevItemsRef = useRef(items);
  let effectivePage = page;
  if (prevItemsRef.current !== items) {
    prevItemsRef.current = items;
    effectivePage = 1;
    if (page !== 1) setPage(1);
  }

  const total = items.length;
  const shownCount = Math.min(effectivePage * pageSize, total);
  const visibleItems = useMemo(() => items.slice(0, shownCount), [items, shownCount]);
  const hasMore = shownCount < total;

  const loadMore = useCallback(() => setPage((current) => current + 1), []);

  return { visibleItems, total, shownCount, hasMore, loadMore };
}
