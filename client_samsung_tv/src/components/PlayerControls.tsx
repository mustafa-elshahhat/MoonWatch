import { Badge } from './Badge';
import { Icon } from './Icon';
import { formatClock } from '../utils/format';
import type { RoomConnectionState } from '../room/roomClient';
import type { IptvDescriptorType, RoomRole } from '../protocol/payloads';

interface PlayerControlsProps {
  title: string;
  contentType: IptvDescriptorType;
  mode: 'solo' | 'room';
  role?: RoomRole;
  roomCode?: string;
  connectionState?: RoomConnectionState;
  playerLabel: string;
  isPlaying: boolean;
  isLive: boolean;
  positionMs: number;
  durationMs: number;
  canControl: boolean;
  onPlayPause: () => void;
  onSeekBack: () => void;
  onSeekForward: () => void;
  onBack: () => void;
}

const TYPE_LABEL: Record<IptvDescriptorType, string> = {
  live: 'Live',
  movie: 'Movie',
  episode: 'Episode',
};

const CONNECTION_LABEL: Record<RoomConnectionState, string> = {
  disconnected: 'Disconnected',
  connecting: 'Connecting',
  connected: 'Connected',
  reconnecting: 'Reconnecting',
};

export function PlayerControls({
  title,
  contentType,
  mode,
  role,
  roomCode,
  connectionState,
  playerLabel,
  isPlaying,
  isLive,
  positionMs,
  durationMs,
  canControl,
  onPlayPause,
  onSeekBack,
  onSeekForward,
  onBack,
}: PlayerControlsProps) {
  const progress = isLive || durationMs <= 0 ? 0 : Math.min(100, (positionMs / durationMs) * 100);

  return (
    <>
      <div className="player-topbar">
        <div className="player-topbar__main">
          <button className="player-btn" data-tv-focusable="true" onClick={onBack} aria-label="Back">
            <Icon name="back" size={30} />
          </button>
          <div className="player-meta">
            <div className="player-badges-row">
              {isLive ? (
                <Badge variant="live" dot>Live</Badge>
              ) : (
                <Badge variant="type">{TYPE_LABEL[contentType]}</Badge>
              )}
              {mode === 'room' && (
                <Badge variant={role === 'host' ? 'host' : 'guest'}>{role === 'host' ? 'Host' : 'Guest'}</Badge>
              )}
              {roomCode && <span className="room-code room-code--sm">{roomCode}</span>}
              <Badge>{playerLabel}</Badge>
            </div>
            <h1 className="player-title">{title}</h1>
            {mode === 'room' && role === 'guest' && (
              <p className="player-subtitle">Playback follows the host.</p>
            )}
          </div>
        </div>
        {mode === 'room' && connectionState && (
          <div className="player-topbar__side">
            <div className="conn-pill">
              <span className={`status-dot status-dot--${connectionState}`} aria-hidden="true" />
              {CONNECTION_LABEL[connectionState]}
            </div>
          </div>
        )}
      </div>

      <div className="player-controls">
        <div className={`player-progress ${isLive ? 'player-progress--live' : ''}`}>
          <span className="player-progress__time">{isLive ? 'LIVE' : formatClock(positionMs)}</span>
          <div className="player-progress__bar" aria-label="Playback position">
            <div className="player-progress__fill" style={{ width: isLive ? '100%' : `${progress}%` }} />
          </div>
          <span className="player-progress__time player-progress__time--end">{isLive ? '' : formatClock(durationMs)}</span>
        </div>
        <div className="player-actions">
          <button
            className="player-btn"
            data-tv-focusable="true"
            disabled={!canControl || isLive}
            onClick={onSeekBack}
            aria-label="Rewind 10 seconds"
          >
            <Icon name="rewind" size={30} />
          </button>
          <button
            className="player-btn player-btn--primary"
            data-tv-focusable="true"
            disabled={!canControl}
            onClick={onPlayPause}
            aria-label={isPlaying ? 'Pause' : 'Play'}
          >
            <Icon name={isPlaying ? 'pause' : 'play'} size={38} />
          </button>
          <button
            className="player-btn"
            data-tv-focusable="true"
            disabled={!canControl || isLive}
            onClick={onSeekForward}
            aria-label="Forward 10 seconds"
          >
            <Icon name="forward" size={30} />
          </button>
        </div>
      </div>
    </>
  );
}
