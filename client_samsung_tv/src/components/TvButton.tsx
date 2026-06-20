import type { ButtonHTMLAttributes, ReactNode } from 'react';

interface TvButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'quiet' | 'danger';
  wide?: boolean;
  children: ReactNode;
}

export function TvButton({ variant = 'secondary', wide = false, className = '', children, ...props }: TvButtonProps) {
  return (
    <button
      {...props}
      className={`tv-button tv-button--${variant} ${wide ? 'tv-button--wide' : ''} ${className}`}
      data-tv-focusable="true"
      type={props.type ?? 'button'}
    >
      {children}
    </button>
  );
}
