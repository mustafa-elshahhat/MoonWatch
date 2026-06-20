import { useEffect, useRef } from 'react';

type RemoteHandler = () => void;

export interface RemoteHandlers {
  onBack?: RemoteHandler;
  onPlay?: RemoteHandler;
  onPause?: RemoteHandler;
  onFastForward?: RemoteHandler;
  onRewind?: RemoteHandler;
}

type RemoteKey = 'up' | 'down' | 'left' | 'right' | 'enter' | 'back' | 'play' | 'pause' | 'fastForward' | 'rewind';

const TIZEN_MEDIA_KEYS = ['MediaPlay', 'MediaPause', 'MediaPlayPause', 'MediaFastForward', 'MediaRewind'];

export function registerTizenRemoteKeys(): void {
  const input = window.tizen?.tvinputdevice;
  if (!input) return;
  try {
    if (input.registerKeyBatch) input.registerKeyBatch(TIZEN_MEDIA_KEYS);
    else TIZEN_MEDIA_KEYS.forEach((key) => input.registerKey(key));
  } catch {
    // Key registration is a best-effort Tizen runtime step.
  }
}

export function useRemoteNavigation(handlers: RemoteHandlers): void {
  // Keep the latest handlers in a ref so the keydown listener and Tizen key
  // registration run exactly once per mount, instead of being torn down and
  // re-added on every render (which also risks dropping a keypress mid-swap).
  const handlersRef = useRef(handlers);
  handlersRef.current = handlers;

  useEffect(() => {
    registerTizenRemoteKeys();

    const onKeyDown = (event: KeyboardEvent) => {
      const key = mapKey(event);
      if (!key) return;
      const current = handlersRef.current;

      if (key === 'up' || key === 'down' || key === 'left' || key === 'right') {
        event.preventDefault();
        moveFocus(key);
        return;
      }

      if (key === 'enter') {
        const target = document.activeElement as HTMLElement | null;
        if (target?.matches('input, textarea')) return;
        event.preventDefault();
        target?.click();
        return;
      }

      if (key === 'back') {
        event.preventDefault();
        current.onBack?.();
        return;
      }

      if (key === 'play') {
        event.preventDefault();
        current.onPlay?.();
        return;
      }

      if (key === 'pause') {
        event.preventDefault();
        current.onPause?.();
        return;
      }

      if (key === 'fastForward') {
        event.preventDefault();
        current.onFastForward?.();
        return;
      }

      if (key === 'rewind') {
        event.preventDefault();
        current.onRewind?.();
      }
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
    // Mount-only: handlers are read live via handlersRef.
  }, []);
}

export function focusFirst(container: ParentNode = document): boolean {
  const focusable = getFocusable(container);
  if (focusable[0]) {
    focusable[0].focus();
    return true;
  }
  return false;
}

function mapKey(event: KeyboardEvent): RemoteKey | undefined {
  switch (event.key) {
    case 'ArrowUp':
      return 'up';
    case 'ArrowDown':
      return 'down';
    case 'ArrowLeft':
      return 'left';
    case 'ArrowRight':
      return 'right';
    case 'Enter':
    case 'OK':
      return 'enter';
    case 'Backspace':
    case 'Escape':
    case 'BrowserBack':
      return 'back';
    case 'MediaPlay':
      return 'play';
    case 'MediaPause':
      return 'pause';
    case 'MediaPlayPause':
      return 'play';
    case 'MediaFastForward':
      return 'fastForward';
    case 'MediaRewind':
      return 'rewind';
    default:
      break;
  }

  switch (event.keyCode) {
    case 13:
      return 'enter';
    case 10009:
      return 'back';
    case 415:
      return 'play';
    case 19:
      return 'pause';
    case 10252:
      return 'play';
    case 417:
      return 'fastForward';
    case 412:
      return 'rewind';
    default:
      return undefined;
  }
}

// --- Focusable caching (TV-005) -------------------------------------------
// The previous implementation re-queried the whole document and ran
// getBoundingClientRect + getComputedStyle on every candidate for every D-pad
// press — a forced reflow per keypress that feels laggy on TV SoCs. We now:
//   1. scope the query to the active FocusBoundary (or the document fallback),
//   2. cache the (visibility-filtered) focusable list per boundary, rebuilding
//      only when that subtree mutates (MutationObserver), so getComputedStyle
//      leaves the hot path, and
//   3. read each candidate's rect just once in moveFocus.
interface FocusableCache {
  boundary: ParentNode;
  items: HTMLElement[];
  observer: MutationObserver;
}

let focusableCache: FocusableCache | undefined;

function activeBoundary(): ParentNode {
  const active = document.activeElement;
  if (active instanceof Element) {
    const boundary = active.closest('[data-focus-boundary="true"]');
    if (boundary) return boundary;
  }
  // No active boundary (e.g. the player screen): use the last mounted boundary
  // if present, otherwise scan the document.
  const boundaries = document.querySelectorAll<HTMLElement>('[data-focus-boundary="true"]');
  return boundaries.length ? boundaries[boundaries.length - 1] : document;
}

function scopedFocusable(): HTMLElement[] {
  const boundary = activeBoundary();
  const stillConnected = !(boundary instanceof Node) || boundary.isConnected;
  if (focusableCache && focusableCache.boundary === boundary && stillConnected) {
    return focusableCache.items;
  }

  focusableCache?.observer.disconnect();

  const items = getFocusable(boundary);
  const observer = new MutationObserver(() => {
    // Any structural/attribute change in the boundary invalidates the cache;
    // it is rebuilt lazily on the next navigation.
    focusableCache?.observer.disconnect();
    focusableCache = undefined;
  });
  if (boundary instanceof Node) {
    observer.observe(boundary, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['disabled', 'aria-disabled', 'class', 'style', 'hidden'],
    });
  }
  focusableCache = { boundary, items, observer };
  return items;
}

function moveFocus(direction: 'up' | 'down' | 'left' | 'right'): void {
  const focusable = scopedFocusable();
  if (focusable.length === 0) return;

  const active = document.activeElement instanceof HTMLElement && focusable.includes(document.activeElement)
    ? document.activeElement
    : focusable[0];

  if (!active) return;
  const activeCenter = center(active.getBoundingClientRect());

  const candidates = focusable
    .filter((item) => item !== active)
    .map((item) => ({ item, rect: item.getBoundingClientRect() }))
    // Guard against a cached item that became hidden before the cache rebuilt.
    .filter(({ rect }) => rect.width > 0 && rect.height > 0)
    .filter(({ rect }) => isDirectionCandidate(direction, activeCenter, center(rect)))
    .map(({ item, rect }) => ({ item, score: scoreCandidate(direction, activeCenter, center(rect)) }))
    .sort((a, b) => a.score - b.score);

  const next = candidates[0]?.item;
  if (!next) return;
  next.focus();
  next.scrollIntoView({ block: 'nearest', inline: 'nearest' });
}

function getFocusable(container: ParentNode): HTMLElement[] {
  return Array.from(container.querySelectorAll<HTMLElement>('[data-tv-focusable="true"]'))
    .filter((item) => {
      if (item.getAttribute('aria-disabled') === 'true') return false;
      if ('disabled' in item && Boolean((item as HTMLButtonElement).disabled)) return false;
      const rect = item.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0 && window.getComputedStyle(item).visibility !== 'hidden';
    });
}

function center(rect: DOMRect): { x: number; y: number } {
  return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
}

function isDirectionCandidate(
  direction: 'up' | 'down' | 'left' | 'right',
  from: { x: number; y: number },
  to: { x: number; y: number },
): boolean {
  const slack = 8;
  if (direction === 'up') return to.y < from.y - slack;
  if (direction === 'down') return to.y > from.y + slack;
  if (direction === 'left') return to.x < from.x - slack;
  return to.x > from.x + slack;
}

function scoreCandidate(
  direction: 'up' | 'down' | 'left' | 'right',
  from: { x: number; y: number },
  to: { x: number; y: number },
): number {
  const dx = Math.abs(to.x - from.x);
  const dy = Math.abs(to.y - from.y);
  if (direction === 'up' || direction === 'down') return dy * 1.2 + dx * 2.2;
  return dx * 1.2 + dy * 2.2;
}
