import type { ReactNode } from 'react';

interface TvGridProps {
  children: ReactNode;
  /** 5-column dense layout (episodes). */
  compact?: boolean;
  /** 3-column layout for large feature tiles. */
  wide?: boolean;
}

export function TvGrid({ children, compact = false, wide = false }: TvGridProps) {
  const modifier = compact ? 'tv-grid--compact' : wide ? 'tv-grid--wide' : '';
  return <div className={`tv-grid ${modifier}`}>{children}</div>;
}
