import type { TvPlayer, TvPlayerCallbacks } from './TvPlayer';
import { describeUrl, diag } from './diagnostics';

/**
 * Toggled on <html> while AVPlay is active. Samsung's AVPlay decodes onto a
 * native video plane that sits *behind* the web layer, so the document chain
 * must be made transparent (see styles.css) for the picture to show — otherwise
 * the opaque page paints over it and the screen looks black even though audio
 * and decoding are fine.
 */
const AVPLAY_ACTIVE_CLASS = 'avplay-active';

export class AvPlayPlayer implements TvPlayer {
  private loaded = false;
  private viewportListenersBound = false;
  private readonly onViewportChange = () => {
    if (!document.hidden) this.updateDisplayRect();
  };

  constructor(private readonly callbacks: TvPlayerCallbacks) {}

  async load(url: string): Promise<void> {
    this.destroy();
    const avplay = this.avplay();
    diag('load', describeUrl(url));

    avplay.open(url);

    avplay.setListener({
      onbufferingstart: () => {
        diag('onbufferingstart');
        this.callbacks.onBufferingChange?.(true);
      },
      onbufferingprogress: (percent) => diag('onbufferingprogress', percent),
      onbufferingcomplete: () => {
        diag('onbufferingcomplete');
        this.callbacks.onBufferingChange?.(false);
      },
      onstreamcompleted: () => {
        diag('onstreamcompleted');
        this.callbacks.onEnded?.();
      },
      onevent: (eventType, eventData) => diag('onevent', eventType, eventData),
      onerror: (eventType) => {
        diag('onerror', eventType);
        this.callbacks.onError?.(describeAvPlayError(eventType));
      },
    });

    // Expose the native video plane and size it *before* prepare — some firmware
    // never shows the picture if the display rect is only set afterwards.
    this.markActive(true);
    this.updateDisplayRect();

    try {
      avplay.setStreamingProperty?.('USER_AGENT', 'VLC/3.0.16 LibVLC/3.0.16');
    } catch {
      // Some firmware versions reject optional streaming properties.
    }

    await new Promise<void>((resolve, reject) => {
      avplay.prepareAsync(
        () => {
          this.loaded = true;
          // Re-apply once prepared (authoritative) and keep it correct on resize.
          this.updateDisplayRect();
          this.bindViewportListeners();
          diag('prepared', { state: this.getState() });
          this.callbacks.onReady?.();
          resolve();
        },
        (error) => {
          diag('prepare failed', error);
          reject(new Error(`Samsung AVPlay prepare failed: ${String(error)}`));
        },
      );
    });
  }

  play(): void {
    if (!this.loaded) return;
    this.avplay().play();
    // The native plane occasionally needs a nudge to repaint after play().
    this.updateDisplayRect();
    this.callbacks.onPlaying?.();
  }

  pause(): void {
    if (!this.loaded) return;
    this.avplay().pause();
    this.callbacks.onPaused?.();
  }

  seek(ms: number): Promise<void> {
    if (!this.loaded) return Promise.resolve();
    return new Promise((resolve, reject) => {
      this.avplay().seekTo(
        Math.max(0, Math.round(ms)),
        resolve,
        (error) => reject(new Error(`Samsung AVPlay seek failed: ${String(error)}`)),
      );
    });
  }

  async getPosition(): Promise<number> {
    if (!this.loaded) return 0;
    try {
      const position = this.avplay().getCurrentTime();
      return typeof position === 'number' && Number.isFinite(position) && position > 0 ? position : 0;
    } catch {
      return 0;
    }
  }

  async getDuration(): Promise<number> {
    if (!this.loaded) return 0;
    try {
      // Live streams legitimately report 0 / NaN here — keep it non-throwing so
      // the UI can fall back to its LIVE state instead of crashing.
      const duration = this.avplay().getDuration();
      return typeof duration === 'number' && Number.isFinite(duration) && duration > 0 ? duration : 0;
    } catch {
      return 0;
    }
  }

  getState(): string | undefined {
    try {
      return window.webapis?.avplay?.getState?.();
    } catch {
      return undefined;
    }
  }

  destroy(): void {
    this.unbindViewportListeners();
    const avplay = window.webapis?.avplay;
    if (avplay) {
      try {
        const state = avplay.getState?.();
        if (state && state !== 'NONE' && state !== 'IDLE') avplay.stop();
      } catch {
        // Ignore cleanup errors from firmware-specific states.
      }
      try {
        avplay.close();
      } catch {
        // Ignore close errors when the AVPlay instance is already closed.
      }
    }
    this.markActive(false);
    this.loaded = false;
  }

  private updateDisplayRect(): void {
    const avplay = window.webapis?.avplay;
    if (!avplay) return;
    const width = Math.round(window.innerWidth) || 1920;
    const height = Math.round(window.innerHeight) || 1080;
    try {
      avplay.setDisplayRect(0, 0, width, height);
      // LETTER_BOX honours the rect and preserves aspect ratio (no stretch).
      avplay.setDisplayMethod?.('PLAYER_DISPLAY_MODE_LETTER_BOX');
      diag('setDisplayRect', { x: 0, y: 0, width, height });
    } catch (error) {
      // Setting the rect before prepare can throw on some firmware; the
      // post-prepare call is authoritative, so this is non-fatal.
      diag('setDisplayRect failed', error);
    }
  }

  private bindViewportListeners(): void {
    if (this.viewportListenersBound) return;
    this.viewportListenersBound = true;
    window.addEventListener('resize', this.onViewportChange);
    document.addEventListener('visibilitychange', this.onViewportChange);
  }

  private unbindViewportListeners(): void {
    if (!this.viewportListenersBound) return;
    this.viewportListenersBound = false;
    window.removeEventListener('resize', this.onViewportChange);
    document.removeEventListener('visibilitychange', this.onViewportChange);
  }

  private markActive(active: boolean): void {
    document.documentElement.classList.toggle(AVPLAY_ACTIVE_CLASS, active);
  }

  private avplay(): SamsungAvPlay {
    const avplay = window.webapis?.avplay;
    if (!avplay) throw new Error('Samsung AVPlay API is not available.');
    return avplay;
  }
}

/** Human-readable AVPlay error with the codec caveat for emulator testing. */
function describeAvPlayError(eventType: unknown): string {
  const code = String(eventType ?? 'unknown');
  return `Samsung AVPlay error: ${code}. This stream's codec may be unsupported here — the TV emulator's codec support differs from a real Samsung TV.`;
}
