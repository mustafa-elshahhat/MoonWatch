interface LoadingStateProps {
  title?: string;
  detail?: string;
}

export function LoadingState({ title = 'Loading', detail = 'Preparing MoonWatch TV.' }: LoadingStateProps) {
  return (
    <div className="state-view" aria-live="polite">
      <div className="state-view__pulse" />
      <h2>{title}</h2>
      <p>{detail}</p>
    </div>
  );
}
