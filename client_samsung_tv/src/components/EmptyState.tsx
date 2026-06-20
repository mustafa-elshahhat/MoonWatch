import type { ReactNode } from 'react';
import { TvButton } from './TvButton';

interface EmptyStateProps {
  title: string;
  hint?: string;
  icon?: ReactNode;
  actionLabel?: string;
  onAction?: () => void;
}

export function EmptyState({ title, hint, icon = '☾', actionLabel, onAction }: EmptyStateProps) {
  return (
    <div className="state-view" role="status">
      <div className="state-view__mark state-view__mark--empty" aria-hidden="true">{icon}</div>
      <h2>{title}</h2>
      {hint && <p>{hint}</p>}
      {actionLabel && onAction && (
        <TvButton variant="primary" onClick={onAction}>{actionLabel}</TvButton>
      )}
    </div>
  );
}
