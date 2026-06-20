export type IptvDescriptorType = 'live' | 'movie' | 'episode';
export type RoomRole = 'host' | 'guest';

export interface IptvContentDescriptor {
  contentType: IptvDescriptorType;
  streamId: string;
  containerExtension?: string | null;
  title: string;
  contentKey?: string;
}

export interface RoomJoinedPayload {
  roomCode: string;
  role: RoomRole;
  guestPresent: boolean;
  contentDescriptor?: IptvContentDescriptor | null;
  serverTimestampMs: number;
  playbackRate?: number;
}

export interface RoomGuestJoinedPayload {
  serverTimestampMs: number;
}

export interface RoomGuestLeftPayload {
  serverTimestampMs: number;
  gracePeriodSeconds: number;
}

export interface RoomGuestReconnectedPayload {
  serverTimestampMs: number;
}

export interface RoomHostAwayPayload {
  serverTimestampMs: number;
  gracePeriodSeconds: number;
}

export interface RoomHostReconnectedPayload {
  serverTimestampMs: number;
}

export interface RoomClosedPayload {
  reason: string;
  serverTimestampMs: number;
}

export interface RoomContentSetPayload {
  descriptor: IptvContentDescriptor;
  serverTimestampMs: number;
}

export interface ErrorPayload {
  code: string;
  message: string;
  serverTimestampMs: number;
}

export interface PlaybackPlayPayload {
  positionMs: number;
  serverTimestampMs: number;
  hostRttMs: number;
  seqNo?: number;
  playbackRate?: number;
}

export interface PlaybackPausePayload {
  positionMs: number;
  serverTimestampMs: number;
  seqNo?: number;
}

export interface PlaybackSeekPayload {
  targetPositionMs: number;
  serverTimestampMs: number;
  seqNo?: number;
  isPlaying?: boolean;
}

export interface PlaybackStateSyncPayload {
  hostPositionMs: number;
  isPlaying: boolean;
  serverTimestampMs: number;
  seqNo?: number;
  playbackRate?: number;
}

export interface PlaybackSpeedPayload {
  speed: number;
  serverTimestampMs: number;
}

export interface PongPayload {
  clientTimestampMs: number;
  serverTimestampMs: number;
}

export interface BufferingStallBroadcastPayload {
  episodeId?: number;
  role: string;
  positionMs: number;
  serverTimestampMs: number;
}

export interface PlayerReadyPayload {
  bothReady: boolean;
  readyRole: RoomRole;
  serverTimestampMs: number;
  contentKey: string;
}

export interface BufferingResumePayload {
  episodeId?: number;
  serverTimestampMs: number;
  resumePositionMs: number;
  isPlaying?: boolean;
}

export function contentKeyOf(descriptor: IptvContentDescriptor): string {
  return `${descriptor.contentType}|${descriptor.streamId}|${descriptor.containerExtension ?? ''}`;
}

export function normalizeDescriptor(descriptor: IptvContentDescriptor): IptvContentDescriptor {
  return {
    contentType: descriptor.contentType,
    streamId: String(descriptor.streamId),
    containerExtension: descriptor.containerExtension ?? null,
    title: descriptor.title,
  };
}
