import type { ReactNode } from 'react';
import { TvButton } from './TvButton';

interface TvModalProps {
  title: string;
  children: ReactNode;
  confirmLabel?: string;
  cancelLabel?: string;
  onConfirm?: () => void;
  onCancel?: () => void;
}

export function TvModal({ title, children, confirmLabel = 'OK', cancelLabel, onConfirm, onCancel }: TvModalProps) {
  return (
    <div className="tv-modal" role="dialog" aria-modal="true" aria-label={title}>
      <div className="tv-modal__panel">
        <h2>{title}</h2>
        <div className="tv-modal__content">{children}</div>
        <div className="tv-modal__actions">
          {cancelLabel && <TvButton onClick={onCancel}>{cancelLabel}</TvButton>}
          <TvButton variant="primary" onClick={onConfirm}>{confirmLabel}</TvButton>
        </div>
      </div>
    </div>
  );
}
