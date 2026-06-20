import type { TvPlayer, TvPlayerCallbacks } from './TvPlayer';

export class AvPlayPlayer implements TvPlayer {
  private loaded = false;

  constructor(private readonly callbacks: TvPlayerCallbacks) {}

  async load(url: string): Promise<void> {
    this.destroy();
    const avplay = this.avplay();
    avplay.open(url);
    avplay.setListener({
      onbufferingstart: () => this.callbacks.onBufferingChange?.(true),
      onbufferingcomplete: () => this.callbacks.onBufferingChange?.(false),
      onstreamcompleted: () => this.callbacks.onEnded?.(),
      onerror: (eventType) => this.callbacks.onError?.(`Samsung AVPlay error: ${String(eventType)}`),
    });
    try {
      avplay.setStreamingProperty?.('USER_AGENT', 'VLC/3.0.16 LibVLC/3.0.16');
    } catch {
      // Some firmware versions reject optional streaming properties.
    }

    await new Promise<void>((resolve, reject) => {
      avplay.prepareAsync(
        () => {
          this.loaded = true;
          this.updateDisplayRect();
          this.callbacks.onReady?.();
          resolve();
        },
        (error) => reject(new Error(`Samsung AVPlay prepare failed: ${String(error)}`)),
      );
    });
  }

  play(): void {
    if (!this.loaded) return;
    this.avplay().play();
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
    return this.avplay().getCurrentTime();
  }

  async getDuration(): Promise<number> {
    if (!this.loaded) return 0;
    const duration = this.avplay().getDuration();
    return Number.isFinite(duration) ? duration : 0;
  }

  destroy(): void {
    const avplay = window.webapis?.avplay;
    if (!avplay) return;
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
    this.loaded = false;
  }

  private updateDisplayRect(): void {
    const width = window.innerWidth || 1920;
    const height = window.innerHeight || 1080;
    this.avplay().setDisplayRect(0, 0, width, height);
    try {
      this.avplay().setDisplayMethod?.('PLAYER_DISPLAY_MODE_FULL_SCREEN');
    } catch {
      // Optional on older TV firmware.
    }
  }

  private avplay(): SamsungAvPlay {
    const avplay = window.webapis?.avplay;
    if (!avplay) throw new Error('Samsung AVPlay API is not available.');
    return avplay;
  }
}
