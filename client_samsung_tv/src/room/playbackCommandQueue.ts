import type { PlaybackCommand } from './playbackCommand';

/**
 * Holds at most one pending playback command — the latest intent received
 * before the player is ready to execute it.
 *
 * The TV player (AVPlay) silently ignores seek/play/pause until the media is
 * loaded. Applying a sync command in that window is a no-op, yet marking its
 * sequence number "applied" would drop it permanently. This buffer lets the
 * player defer the newest command and replay it once ready, mirroring the
 * Flutter sync engine's deferred-queue behaviour (XP-003 / XP-004).
 *
 * Only the most recent command is kept: an older intent is always superseded by
 * a newer one, so replay applies a single, current state.
 */
export class DeferredCommandQueue {
  private pending?: PlaybackCommand;

  /** Buffer a command, replacing any previously buffered (older) one. */
  defer(command: PlaybackCommand): void {
    this.pending = command;
  }

  /** Remove and return the buffered command, if any. */
  take(): PlaybackCommand | undefined {
    const command = this.pending;
    this.pending = undefined;
    return command;
  }

  get hasPending(): boolean {
    return this.pending !== undefined;
  }

  clear(): void {
    this.pending = undefined;
  }
}
