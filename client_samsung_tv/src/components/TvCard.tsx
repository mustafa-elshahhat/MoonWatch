import type { ButtonHTMLAttributes, ReactNode } from 'react';

interface TvCardProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  title: string;
  eyebrow?: string;
  subtitle?: string;
  image?: string;
  meta?: string;
  /** Glyph/emoji shown for feature tiles or as a poster fallback. */
  icon?: ReactNode;
  /** poster (2:3, default) | feature (16:9 icon tile) | live (16:9 channel). */
  variant?: 'poster' | 'feature' | 'live';
  /** Badges overlaid on the media (e.g. LIVE). */
  badges?: ReactNode;
  selected?: boolean;
  children?: ReactNode;
}

export function TvCard({
  title,
  eyebrow,
  subtitle,
  image,
  meta,
  icon,
  variant = 'poster',
  badges,
  selected,
  children,
  className = '',
  ...props
}: TvCardProps) {
  return (
    <button
      {...props}
      className={`tv-card tv-card--${variant} ${selected ? 'tv-card--selected' : ''} ${className}`}
      data-tv-focusable="true"
      type="button"
    >
      <div className="tv-card__image" aria-hidden="true">
        {image ? (
          <img src={image} alt="" loading="lazy" onError={hideBrokenImage} />
        ) : icon ? (
          <span className="tv-card__icon">{icon}</span>
        ) : (
          <span>{title.slice(0, 1).toUpperCase()}</span>
        )}
        {badges && <div className="tv-card__badge-row">{badges}</div>}
      </div>
      <div className="tv-card__body">
        {eyebrow && <div className="tv-card__eyebrow">{eyebrow}</div>}
        <div className="tv-card__title">{title}</div>
        {subtitle && <div className="tv-card__subtitle">{subtitle}</div>}
        {meta && <div className="tv-card__meta">{meta}</div>}
        {children}
      </div>
    </button>
  );
}

/** Hide a broken poster so the striped/glyph fallback background shows through. */
function hideBrokenImage(event: React.SyntheticEvent<HTMLImageElement>) {
  event.currentTarget.style.display = 'none';
}
