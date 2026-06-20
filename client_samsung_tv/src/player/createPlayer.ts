import { AvPlayPlayer } from './AvPlayPlayer';
import { HtmlVideoPlayer } from './HtmlVideoPlayer';
import type { TvPlayer, TvPlayerCallbacks } from './TvPlayer';

let activePlayer: TvPlayer | undefined;

export function createTvPlayer(container: HTMLElement, callbacks: TvPlayerCallbacks): TvPlayer {
  activePlayer?.destroy();
  activePlayer = hasAvPlay() ? new AvPlayPlayer(callbacks) : new HtmlVideoPlayer(container, callbacks);
  return activePlayer;
}

export function destroyActivePlayer(): void {
  activePlayer?.destroy();
  activePlayer = undefined;
}

export function hasAvPlay(): boolean {
  return Boolean(window.webapis?.avplay);
}
