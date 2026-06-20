import { describe, expect, it } from 'vitest';
import { DeferredCommandQueue } from './playbackCommandQueue';
import type { PlaybackCommand } from './playbackCommand';

function play(id: number, positionMs: number): PlaybackCommand {
  return { id, type: 'play', payload: { positionMs, serverTimestampMs: 0, hostRttMs: 0, seqNo: id } };
}

describe('DeferredCommandQueue (XP-003)', () => {
  it('starts empty', () => {
    const q = new DeferredCommandQueue();
    expect(q.hasPending).toBe(false);
    expect(q.take()).toBeUndefined();
  });

  it('keeps only the latest deferred command (newest intent wins)', () => {
    const q = new DeferredCommandQueue();
    q.defer(play(1, 1000));
    q.defer(play(2, 2000));
    expect(q.hasPending).toBe(true);
    expect(q.take()?.id).toBe(2);
    expect(q.hasPending).toBe(false);
  });

  it('take() empties the queue', () => {
    const q = new DeferredCommandQueue();
    q.defer(play(1, 1000));
    q.take();
    expect(q.take()).toBeUndefined();
  });

  it('clear() discards the pending command', () => {
    const q = new DeferredCommandQueue();
    q.defer(play(1, 1000));
    q.clear();
    expect(q.hasPending).toBe(false);
  });
});
