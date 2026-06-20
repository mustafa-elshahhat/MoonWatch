import type { CSSProperties } from 'react';

export type IconName =
  | 'live'
  | 'movie'
  | 'series'
  | 'create'
  | 'join'
  | 'settings'
  | 'back'
  | 'play'
  | 'pause'
  | 'rewind'
  | 'forward'
  | 'check'
  | 'alert'
  | 'signal'
  | 'search'
  | 'moon';

interface IconProps {
  name: IconName;
  size?: number;
  className?: string;
  style?: CSSProperties;
}

/** Filled icons (play/pause) read better at a glance than outlined ones. */
const FILLED: Partial<Record<IconName, string>> = {
  play: 'M8 5v14l11-7z',
  pause: 'M7 4h4v16H7zM13 4h4v16h-4z',
};

const PATHS: Record<IconName, string> = {
  live: 'M4 9a16 16 0 0 1 16 0M7 13a10 10 0 0 1 10 0M12 17h.01M3 20h7l2-4 2 4h7',
  movie: 'M3 4h18v16H3zM7 4v16M17 4v16M3 9h4M17 9h4M3 15h4M17 15h4',
  series: 'M4 8h16v11H4zM7 8V5h10v3M2 12h2M20 12h2',
  create: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 8v8M8 12h8',
  join: 'M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 16l4-4-4-4M14 12H4',
  settings: 'M21 7h-7M9 7H3M21 17h-3M13 17H3M9 7a2 2 0 1 0 0-.01M18 17a2 2 0 1 0 0-.01',
  back: 'M15 18l-6-6 6-6',
  play: 'M8 5v14l11-7z',
  pause: 'M7 4h4v16H7zM13 4h4v16h-4z',
  rewind: 'M13 6l-7 6 7 6M20 6l-7 6 7 6',
  forward: 'M11 6l7 6-7 6M4 6l7 6-7 6',
  check: 'M20 6L9 17l-5-5',
  alert: 'M12 3L2 20h20L12 3zM12 10v4M12 18h.01',
  signal: 'M5 13a10 10 0 0 1 14 0M8.5 16.5a5 5 0 0 1 7 0M12 20h.01M2 9.5a16 16 0 0 1 20 0',
  search: 'M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-3.5-3.5',
  moon: 'M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z',
};

export function Icon({ name, size = 24, className = '', style }: IconProps) {
  const filled = FILLED[name];
  return (
    <svg
      className={className}
      style={style}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill={filled ? 'currentColor' : 'none'}
      stroke={filled ? 'none' : 'currentColor'}
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      <path d={filled ?? PATHS[name]} />
    </svg>
  );
}
