import type {
  BufferingResumePayload,
  BufferingStallBroadcastPayload,
  PlaybackPausePayload,
  PlaybackPlayPayload,
  PlaybackSeekPayload,
  PlaybackSpeedPayload,
  PlaybackStateSyncPayload,
} from '../protocol/payloads';

export type PlaybackCommand =
  | { id: number; type: 'play'; payload: PlaybackPlayPayload }
  | { id: number; type: 'pause'; payload: PlaybackPausePayload }
  | { id: number; type: 'seek'; payload: PlaybackSeekPayload }
  | { id: number; type: 'stateSync'; payload: PlaybackStateSyncPayload }
  | { id: number; type: 'speed'; payload: PlaybackSpeedPayload }
  | { id: number; type: 'bufferingStall'; payload: BufferingStallBroadcastPayload }
  | { id: number; type: 'bufferingResume'; payload: BufferingResumePayload };
