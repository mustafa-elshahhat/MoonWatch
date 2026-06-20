export interface TvPlayer {
  load(url: string): Promise<void>;
  play(): Promise<void> | void;
  pause(): Promise<void> | void;
  seek(ms: number): Promise<void> | void;
  getPosition(): Promise<number>;
  getDuration(): Promise<number>;
  destroy(): void;
}

export interface TvPlayerCallbacks {
  onReady?: () => void;
  onPlaying?: () => void;
  onPaused?: () => void;
  onBufferingChange?: (buffering: boolean) => void;
  onEnded?: () => void;
  onError?: (message: string) => void;
}
