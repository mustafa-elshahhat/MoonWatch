import { describe, expect, it } from 'vitest';
import { act, renderHook } from '@testing-library/react';
import { usePagedItems } from './usePagedItems';

describe('usePagedItems', () => {
  it('shows one page initially and lazily loads more', () => {
    const items = Array.from({ length: 120 }, (_, i) => i);
    const { result } = renderHook(() => usePagedItems(items, 48));

    expect(result.current.shownCount).toBe(48);
    expect(result.current.visibleItems).toHaveLength(48);
    expect(result.current.hasMore).toBe(true);

    act(() => result.current.loadMore());
    expect(result.current.shownCount).toBe(96);

    act(() => result.current.loadMore());
    expect(result.current.shownCount).toBe(120);
    expect(result.current.hasMore).toBe(false);
  });

  it('handles lists smaller than one page', () => {
    const { result } = renderHook(() => usePagedItems([1, 2, 3], 48));
    expect(result.current.shownCount).toBe(3);
    expect(result.current.hasMore).toBe(false);
  });
});
