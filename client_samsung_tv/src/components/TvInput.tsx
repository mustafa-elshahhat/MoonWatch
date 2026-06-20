import type { InputHTMLAttributes } from 'react';

interface TvInputProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
  hint?: string;
}

export function TvInput({ label, error, hint, className = '', ...props }: TvInputProps) {
  return (
    <label className={`tv-input ${className}`}>
      <span className="tv-input__label">{label}</span>
      <input {...props} data-tv-focusable="true" />
      {hint && !error && <span className="tv-input__hint">{hint}</span>}
      {error && <span className="tv-input__error">{error}</span>}
    </label>
  );
}
