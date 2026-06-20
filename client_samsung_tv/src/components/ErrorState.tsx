import type { ReactNode } from 'react';
import { TvButton } from './TvButton';

interface ErrorStateProps {
  title?: string;
  message: string;
  icon?: ReactNode;
  actionLabel?: string;
  onAction?: () => void;
  secondaryLabel?: string;
  onSecondary?: () => void;
}

export function ErrorState({
  title = 'Something needs attention',
  message,
  icon = '!',
  actionLabel,
  onAction,
  secondaryLabel,
  onSecondary,
}: ErrorStateProps) {
  return (
    <div className="state-view state-view--error" role="alert">
      <div className="state-view__mark" aria-hidden="true">{icon}</div>
      <h2>{title}</h2>
      <p>{message}</p>
      {(onAction || onSecondary) && (
        <div className="screen__actions screen__actions--center">
          {secondaryLabel && onSecondary && <TvButton onClick={onSecondary}>{secondaryLabel}</TvButton>}
          {actionLabel && onAction && <TvButton variant="primary" onClick={onAction}>{actionLabel}</TvButton>}
        </div>
      )}
    </div>
  );
}
