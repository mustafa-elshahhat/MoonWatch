import type { ReactNode } from 'react';

type BadgeVariant = 'default' | 'type' | 'live' | 'host' | 'guest';

interface BadgeProps {
  variant?: BadgeVariant;
  dot?: boolean;
  children: ReactNode;
}

export function Badge({ variant = 'default', dot = false, children }: BadgeProps) {
  return (
    <span className={`badge${variant === 'default' ? '' : ` badge--${variant}`}`}>
      {dot && <span className="badge__dot" aria-hidden="true" />}
      {children}
    </span>
  );
}
