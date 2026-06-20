interface SkeletonGridProps {
  count?: number;
}

export function SkeletonGrid({ count = 8 }: SkeletonGridProps) {
  return (
    <div className="skeleton-grid" aria-hidden="true">
      {Array.from({ length: count }).map((_, index) => (
        <div className="skeleton-card" key={index}>
          <div className="skeleton-card__poster skeleton" />
          <div className="skeleton-card__line skeleton" />
          <div className="skeleton-card__line skeleton" />
        </div>
      ))}
    </div>
  );
}
