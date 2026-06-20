import { describe, expect, it } from 'vitest';
import { RoomEvents } from './roomEvents';

// Snapshot guard for the TypeScript protocol constants (SP-002). Combined with
// scripts/check-protocol-drift.mjs (which diffs the C#/Dart/TS string sets),
// this catches an accidental rename/removal on the TV side.
describe('protocol constants', () => {
  it('matches the expected event/hub-method set', () => {
    expect({ ...RoomEvents }).toEqual({
      roomJoined: 'room:joined',
      roomGuestJoined: 'room:guest_joined',
      roomGuestLeft: 'room:guest_left',
      roomGuestReconnected: 'room:guest_reconnected',
      roomHostAway: 'room:host_away',
      roomHostReconnected: 'room:host_reconnected',
      roomClosed: 'room:closed',
      roomContentSet: 'room:content_set',
      roomError: 'room:error',
      playerReady: 'player:ready',
      playbackPlay: 'playback:play',
      playbackPause: 'playback:pause',
      playbackSeek: 'playback:seek',
      playbackStateSync: 'playback:state_sync',
      playbackSpeed: 'playback:speed',
      bufferingStall: 'buffering:stall',
      bufferingReady: 'buffering:ready',
      bufferingResume: 'buffering:resume',
      pong: 'pong',
      hubCreateRoom: 'CreateRoom',
      hubJoinRoom: 'JoinRoom',
      hubLeaveRoom: 'LeaveRoom',
      hubSetContent: 'SetContent',
      hubPlay: 'Play',
      hubPause: 'Pause',
      hubSeek: 'Seek',
      hubSetPlaybackSpeed: 'SetPlaybackSpeed',
      hubNotifyBufferingStall: 'NotifyBufferingStall',
      hubNotifyPlayerReady: 'NotifyPlayerReady',
      hubNotifyBufferingReady: 'NotifyBufferingReady',
      hubPing: 'Ping',
    });
  });
});
