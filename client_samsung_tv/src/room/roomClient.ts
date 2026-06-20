import {
  HubConnection,
  HubConnectionBuilder,
  HubConnectionState,
  LogLevel,
} from '@microsoft/signalr';
import { RoomEvents } from '../protocol/roomEvents';
import type {
  BufferingResumePayload,
  BufferingStallBroadcastPayload,
  ErrorPayload,
  IptvContentDescriptor,
  PlaybackPausePayload,
  PlaybackPlayPayload,
  PlaybackSeekPayload,
  PlaybackSpeedPayload,
  PlaybackStateSyncPayload,
  PlayerReadyPayload,
  PongPayload,
  RoomClosedPayload,
  RoomContentSetPayload,
  RoomGuestLeftPayload,
  RoomHostAwayPayload,
  RoomJoinedPayload,
  RoomRole,
} from '../protocol/payloads';
import { normalizeDescriptor } from '../protocol/payloads';
import { normalizeBaseUrl } from '../settings/settings';

export type RoomConnectionState = 'disconnected' | 'connecting' | 'connected' | 'reconnecting';

export interface LatencySnapshot {
  rttMs: number;
  clockOffsetMs: number;
}

export interface RoomClientEvents {
  onConnectionState?: (state: RoomConnectionState) => void;
  onRoomJoined?: (payload: RoomJoinedPayload) => void;
  onGuestJoined?: () => void;
  onGuestLeft?: (payload: RoomGuestLeftPayload) => void;
  onGuestReconnected?: () => void;
  onHostAway?: (payload: RoomHostAwayPayload) => void;
  onHostReconnected?: () => void;
  onRoomClosed?: (payload: RoomClosedPayload) => void;
  onContentSet?: (payload: RoomContentSetPayload) => void;
  onRoomError?: (payload: ErrorPayload) => void;
  onPlayerReady?: (payload: PlayerReadyPayload) => void;
  onPlaybackPlay?: (payload: PlaybackPlayPayload) => void;
  onPlaybackPause?: (payload: PlaybackPausePayload) => void;
  onPlaybackSeek?: (payload: PlaybackSeekPayload) => void;
  onPlaybackStateSync?: (payload: PlaybackStateSyncPayload) => void;
  onPlaybackSpeed?: (payload: PlaybackSpeedPayload) => void;
  onBufferingStall?: (payload: BufferingStallBroadcastPayload) => void;
  onBufferingResume?: (payload: BufferingResumePayload) => void;
  onLatency?: (latency: LatencySnapshot) => void;
}

interface PendingJoin {
  resolve: (payload: RoomJoinedPayload) => void;
  reject: (error: Error) => void;
  timer: number;
}

export class RoomClient {
  private connection?: HubConnection;
  private pendingJoin?: PendingJoin;
  private roomCode?: string;
  private role?: RoomRole;
  private pingTimer?: number;
  private burstTimers: number[] = [];
  private rttMs = 100;
  private clockOffsetMs = 0;
  private hasLatency = false;

  constructor(
    private readonly serverBaseUrl: string,
    private readonly events: RoomClientEvents,
  ) {}

  get currentRoomCode(): string | undefined {
    return this.roomCode;
  }

  get currentRole(): RoomRole | undefined {
    return this.role;
  }

  get latency(): LatencySnapshot {
    return { rttMs: this.rttMs, clockOffsetMs: this.clockOffsetMs };
  }

  async connect(): Promise<void> {
    if (this.connection?.state === HubConnectionState.Connected) return;
    if (!this.connection) this.connection = this.createConnection();

    this.updateConnectionState('connecting');
    await this.connection.start();
    this.updateConnectionState('connected');
  }

  async createRoom(): Promise<RoomJoinedPayload> {
    await this.connect();
    const pending = this.waitForRoomJoined();
    await this.connection!.invoke(RoomEvents.hubCreateRoom);
    return pending;
  }

  async joinRoom(roomCode: string, role: RoomRole = 'guest'): Promise<RoomJoinedPayload> {
    await this.connect();
    const pending = this.waitForRoomJoined();
    await this.connection!.invoke(RoomEvents.hubJoinRoom, roomCode.toUpperCase(), role);
    return pending;
  }

  async leaveRoom(): Promise<void> {
    if (this.connection?.state === HubConnectionState.Connected) {
      await this.connection.invoke(RoomEvents.hubLeaveRoom);
    }
    this.clearRoom();
  }

  async setContent(descriptor: IptvContentDescriptor): Promise<void> {
    await this.invoke(RoomEvents.hubSetContent, normalizeDescriptor(descriptor));
  }

  async play(positionMs: number, clientTimestampMs = Date.now()): Promise<void> {
    await this.invoke(RoomEvents.hubPlay, Math.max(0, Math.round(positionMs)), clientTimestampMs);
  }

  async pause(positionMs: number): Promise<void> {
    await this.invoke(RoomEvents.hubPause, Math.max(0, Math.round(positionMs)));
  }

  async seek(targetPositionMs: number): Promise<void> {
    await this.invoke(RoomEvents.hubSeek, Math.max(0, Math.round(targetPositionMs)));
  }

  async notifyPlayerReady(contentKey: string): Promise<void> {
    await this.invoke(RoomEvents.hubNotifyPlayerReady, contentKey);
  }

  async notifyBufferingStall(positionMs: number, episodeId: number): Promise<void> {
    await this.invoke(RoomEvents.hubNotifyBufferingStall, Math.max(0, Math.round(positionMs)), episodeId);
  }

  async notifyBufferingReady(episodeId: number): Promise<void> {
    await this.invoke(RoomEvents.hubNotifyBufferingReady, episodeId);
  }

  async dispose(): Promise<void> {
    this.stopLatency();
    this.rejectPendingJoin(new Error('Room connection disposed.'));
    if (this.connection) {
      await this.connection.stop();
      this.connection = undefined;
    }
    this.updateConnectionState('disconnected');
  }

  private createConnection(): HubConnection {
    const hubUrl = `${normalizeBaseUrl(this.serverBaseUrl)}/hubs/room`;
    const connection = new HubConnectionBuilder()
      .withUrl(hubUrl)
      .withAutomaticReconnect([0, 2000, 5000, 10000, 20000])
      .configureLogging(import.meta.env.PROD ? LogLevel.Error : LogLevel.Warning)
      .build();

    connection.onreconnecting(() => this.updateConnectionState('reconnecting'));
    connection.onreconnected(() => {
      this.updateConnectionState('connected');
      void this.rejoinAfterReconnect();
    });
    connection.onclose(() => {
      this.updateConnectionState('disconnected');
      this.stopLatency();
    });

    connection.on(RoomEvents.roomJoined, (payload: RoomJoinedPayload) => this.handleRoomJoined(payload));
    connection.on(RoomEvents.roomGuestJoined, () => this.events.onGuestJoined?.());
    connection.on(RoomEvents.roomGuestLeft, (payload: RoomGuestLeftPayload) => this.events.onGuestLeft?.(payload));
    connection.on(RoomEvents.roomGuestReconnected, () => this.events.onGuestReconnected?.());
    connection.on(RoomEvents.roomHostAway, (payload: RoomHostAwayPayload) => this.events.onHostAway?.(payload));
    connection.on(RoomEvents.roomHostReconnected, () => this.events.onHostReconnected?.());
    connection.on(RoomEvents.roomClosed, (payload: RoomClosedPayload) => this.handleRoomClosed(payload));
    connection.on(RoomEvents.roomContentSet, (payload: RoomContentSetPayload) => this.events.onContentSet?.(payload));
    connection.on(RoomEvents.roomError, (payload: ErrorPayload) => this.handleRoomError(payload));
    connection.on(RoomEvents.playerReady, (payload: PlayerReadyPayload) => this.events.onPlayerReady?.(payload));
    connection.on(RoomEvents.playbackPlay, (payload: PlaybackPlayPayload) => this.events.onPlaybackPlay?.(payload));
    connection.on(RoomEvents.playbackPause, (payload: PlaybackPausePayload) => this.events.onPlaybackPause?.(payload));
    connection.on(RoomEvents.playbackSeek, (payload: PlaybackSeekPayload) => this.events.onPlaybackSeek?.(payload));
    connection.on(RoomEvents.playbackStateSync, (payload: PlaybackStateSyncPayload) => this.events.onPlaybackStateSync?.(payload));
    connection.on(RoomEvents.playbackSpeed, (payload: PlaybackSpeedPayload) => this.events.onPlaybackSpeed?.(payload));
    connection.on(RoomEvents.bufferingStall, (payload: BufferingStallBroadcastPayload) => this.events.onBufferingStall?.(payload));
    connection.on(RoomEvents.bufferingResume, (payload: BufferingResumePayload) => this.events.onBufferingResume?.(payload));
    connection.on(RoomEvents.pong, (payload: PongPayload) => this.handlePong(payload));

    return connection;
  }

  private async invoke(method: string, ...args: unknown[]): Promise<void> {
    await this.connect();
    await this.connection!.invoke(method, ...args);
  }

  private waitForRoomJoined(): Promise<RoomJoinedPayload> {
    this.rejectPendingJoin(new Error('Superseded by another room operation.'));
    return new Promise((resolve, reject) => {
      const timer = window.setTimeout(() => {
        this.pendingJoin = undefined;
        reject(new Error('Room operation timed out.'));
      }, 15000);
      this.pendingJoin = { resolve, reject, timer };
    });
  }

  private handleRoomJoined(payload: RoomJoinedPayload): void {
    this.roomCode = payload.roomCode;
    this.role = payload.role;
    this.startLatency();
    if (this.pendingJoin) {
      window.clearTimeout(this.pendingJoin.timer);
      this.pendingJoin.resolve(payload);
      this.pendingJoin = undefined;
    }
    this.events.onRoomJoined?.(payload);
  }

  private handleRoomError(payload: ErrorPayload): void {
    if (this.pendingJoin) {
      this.rejectPendingJoin(new Error(payload.message || payload.code));
    }
    this.events.onRoomError?.(payload);
  }

  private handleRoomClosed(payload: RoomClosedPayload): void {
    this.clearRoom();
    this.events.onRoomClosed?.(payload);
  }

  private rejectPendingJoin(error: Error): void {
    if (!this.pendingJoin) return;
    window.clearTimeout(this.pendingJoin.timer);
    this.pendingJoin.reject(error);
    this.pendingJoin = undefined;
  }

  private clearRoom(): void {
    this.roomCode = undefined;
    this.role = undefined;
    this.stopLatency();
  }

  private async rejoinAfterReconnect(): Promise<void> {
    if (!this.roomCode || !this.role) return;
    // Both host and guest re-invoke JoinRoom on reconnect. The server keeps the
    // room alive for a grace period and rebinds the new SignalR connection id to
    // the existing slot (host grace: BE-001/XP-001), so host reconnect is now
    // supported instead of being treated as fatal.
    try {
      await this.connection!.invoke(RoomEvents.hubJoinRoom, this.roomCode, this.role);
    } catch (error) {
      this.events.onRoomError?.({
        code: 'reconnect_failed',
        message: error instanceof Error ? error.message : 'Could not reconnect to the room.',
        serverTimestampMs: Date.now(),
      });
    }
  }

  private startLatency(): void {
    this.stopLatency();
    this.sendPing();
    this.burstTimers = [
      window.setTimeout(() => this.sendPing(), 1000),
      window.setTimeout(() => this.sendPing(), 2000),
    ];
    this.pingTimer = window.setInterval(() => this.sendPing(), 15000);
  }

  private stopLatency(): void {
    if (this.pingTimer) window.clearInterval(this.pingTimer);
    for (const timer of this.burstTimers) window.clearTimeout(timer);
    this.pingTimer = undefined;
    this.burstTimers = [];
    this.hasLatency = false;
    this.rttMs = 100;
    this.clockOffsetMs = 0;
  }

  private sendPing(): void {
    if (this.connection?.state !== HubConnectionState.Connected) return;
    void this.connection.invoke(RoomEvents.hubPing, Date.now(), this.rttMs).catch(() => undefined);
  }

  private handlePong(payload: PongPayload): void {
    const now = Date.now();
    const rawRttMs = Math.min(Math.max(now - payload.clientTimestampMs, 0), 2000);
    const rawOffsetMs = payload.serverTimestampMs - (payload.clientTimestampMs + Math.floor(rawRttMs / 2));
    if (!this.hasLatency) {
      this.rttMs = rawRttMs;
      this.clockOffsetMs = rawOffsetMs;
      this.hasLatency = true;
    } else {
      this.rttMs = Math.round(0.3 * rawRttMs + 0.7 * this.rttMs);
      this.clockOffsetMs = Math.round(0.3 * rawOffsetMs + 0.7 * this.clockOffsetMs);
    }
    this.events.onLatency?.(this.latency);
  }

  private updateConnectionState(state: RoomConnectionState): void {
    this.events.onConnectionState?.(state);
  }
}
