import { useEffect, useRef, type ReactNode } from 'react';
import { focusFirst } from '../navigation/remote';

interface FocusBoundaryProps {
  children: ReactNode;
  autoFocus?: boolean;
  className?: string;
}

export function FocusBoundary({ children, autoFocus = true, className = '' }: FocusBoundaryProps) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!autoFocus) return;
    const el = ref.current;
    if (!el) return;

    let tries = 0;
    let timer = 0;
    const attempt = () => {
      if (!el.isConnected) return;
      // Don't steal focus if the user already moved into this screen.
      const inside = el.contains(document.activeElement) && document.activeElement !== document.body;
      if (inside) return;
      // Retry while data is still streaming in so focus never gets stranded.
      if (!focusFirst(el) && ++tries < 8) timer = window.setTimeout(attempt, 120);
    };
    timer = window.setTimeout(attempt, 40);
    return () => window.clearTimeout(timer);
  }, [autoFocus]);

  return <div ref={ref} className={className} data-focus-boundary="true">{children}</div>;
}
