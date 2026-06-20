import type { TvPlayer, TvPlayerCallbacks } from './TvPlayer';

export class HtmlVideoPlayer implements TvPlayer {
  private video?: HTMLVideoElement;
  private cleanup: Array<() => void> = [];

  constructor(
    private readonly container: HTMLElement,
    private readonly callbacks: TvPlayerCallbacks,
  ) {}

  async load(url: string): Promise<void> {
    this.destroy();
    const video = document.createElement('video');
    video.className = 'html-video-player';
    video.preload = 'auto';
    video.autoplay = false;
    video.controls = false;
    video.playsInline = true;
    video.src = url;

    this.video = video;
    this.container.innerHTML = '';
    this.container.appendChild(video);

    await new Promise<void>((resolve, reject) => {
      let settled = false;
      const settle = (fn: () => void) => {
        if (settled) return;
        settled = true;
        window.clearTimeout(timeout);
        fn();
      };
      const timeout = window.setTimeout(() => {
        settle(() => reject(new Error('Playback load timed out.')));
      }, 20000);

      const add = <K extends keyof HTMLMediaElementEventMap>(
        event: K,
        handler: (event: HTMLMediaElementEventMap[K]) => void,
      ) => {
        video.addEventListener(event, handler);
        this.cleanup.push(() => video.removeEventListener(event, handler));
      };

      add('loadedmetadata', () => {
        this.callbacks.onReady?.();
        settle(resolve);
      });
      add('canplay', () => {
        this.callbacks.onReady?.();
        settle(resolve);
      });
      add('playing', () => {
        this.callbacks.onBufferingChange?.(false);
        this.callbacks.onPlaying?.();
      });
      add('pause', () => this.callbacks.onPaused?.());
      add('waiting', () => this.callbacks.onBufferingChange?.(true));
      add('stalled', () => this.callbacks.onBufferingChange?.(true));
      add('canplaythrough', () => this.callbacks.onBufferingChange?.(false));
      add('ended', () => this.callbacks.onEnded?.());
      add('error', () => {
        const message = video.error?.message || 'HTML5 video playback failed.';
        this.callbacks.onError?.(message);
        settle(() => reject(new Error(message)));
      });

      video.load();
    });
  }

  async play(): Promise<void> {
    if (!this.video) return;
    await this.video.play();
  }

  pause(): void {
    this.video?.pause();
  }

  seek(ms: number): void {
    if (!this.video) return;
    const seconds = Math.max(0, ms / 1000);
    const duration = this.video.duration;
    this.video.currentTime = Number.isFinite(duration) && duration > 0 ? Math.min(seconds, duration) : seconds;
  }

  async getPosition(): Promise<number> {
    return Math.round((this.video?.currentTime ?? 0) * 1000);
  }

  async getDuration(): Promise<number> {
    const duration = this.video?.duration ?? 0;
    return Number.isFinite(duration) && duration > 0 ? Math.round(duration * 1000) : 0;
  }

  getState(): string | undefined {
    if (!this.video) return 'NONE';
    const READY = ['HAVE_NOTHING', 'HAVE_METADATA', 'HAVE_CURRENT_DATA', 'HAVE_FUTURE_DATA', 'HAVE_ENOUGH_DATA'];
    return this.video.paused ? `PAUSED (${READY[this.video.readyState] ?? this.video.readyState})` : `PLAYING (${READY[this.video.readyState] ?? this.video.readyState})`;
  }

  destroy(): void {
    for (const dispose of this.cleanup.splice(0)) dispose();
    if (this.video) {
      this.video.pause();
      this.video.removeAttribute('src');
      this.video.load();
      this.video.remove();
      this.video = undefined;
    }
  }
}
