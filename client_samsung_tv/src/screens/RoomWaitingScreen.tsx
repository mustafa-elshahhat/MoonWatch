import { Badge, FocusBoundary, Icon, TvButton } from '../components';
import type { IptvContentDescriptor } from '../protocol/payloads';
import type { RoomConnectionState } from '../room/roomClient';

interface RoomWaitingScreenProps {
  roomCode: string;
  role: 'host' | 'guest';
  guestPresent: boolean;
  connectionState: RoomConnectionState;
  descriptor?: IptvContentDescriptor | null;
  onBrowse: (kind: 'live' | 'vod' | 'series') => void;
  onStartContent: () => void;
  onLeave: () => void;
}

const CONNECTION_LABEL: Record<RoomConnectionState, string> = {
  disconnected: 'Disconnected',
  connecting: 'Connecting',
  connected: 'Connected',
  reconnecting: 'Reconnecting',
};

export function RoomWaitingScreen({
  roomCode,
  role,
  guestPresent,
  connectionState,
  descriptor,
  onBrowse,
  onStartContent,
  onLeave,
}: RoomWaitingScreenProps) {
  const isHost = role === 'host';

  return (
    <FocusBoundary className="screen screen--waiting">
      <header className="waiting-header">
        <div className="player-badges-row" style={{ justifyContent: 'center' }}>
          <Badge variant={isHost ? 'host' : 'guest'}>{isHost ? 'Host' : 'Guest'}</Badge>
          {isHost && (
            <Badge variant={guestPresent ? 'type' : 'default'} dot>
              {guestPresent ? 'Guest connected' : 'Waiting for guest'}
            </Badge>
          )}
        </div>
        <div className="room-code">{roomCode}</div>
        <p>{isHost
          ? 'Share this code with a guest, then choose what to watch together.'
          : 'You are in the room. Playback starts when the host chooses content.'}</p>
      </header>

      <section className="waiting-grid">
        <div className="waiting-status">
          <span>Connection</span>
          <strong>
            <span className={`status-dot status-dot--${connectionState}`} aria-hidden="true" />
            {CONNECTION_LABEL[connectionState]}
          </strong>
        </div>
        <div className="waiting-status">
          <span>Guest</span>
          <strong>{guestPresent ? 'Connected' : isHost ? 'Waiting' : 'This TV'}</strong>
        </div>
        <div className="waiting-status">
          <span>Selected content</span>
          <strong style={{ textTransform: 'none' }}>{descriptor?.title ?? 'Not selected'}</strong>
        </div>
      </section>

      <div className="screen__actions screen__actions--center">
        {isHost && (
          <>
            <TvButton onClick={() => onBrowse('live')}><Icon name="live" size={24} /> Live TV</TvButton>
            <TvButton onClick={() => onBrowse('vod')}><Icon name="movie" size={24} /> VOD</TvButton>
            <TvButton onClick={() => onBrowse('series')}><Icon name="series" size={24} /> Series</TvButton>
          </>
        )}
        {descriptor && (
          <TvButton variant="primary" onClick={onStartContent}><Icon name="play" size={24} /> Open player</TvButton>
        )}
        <TvButton variant="danger" onClick={onLeave}>Leave room</TvButton>
      </div>

      {!isHost && !descriptor && (
        <p className="empty-state" style={{ paddingTop: 16 }}>
          The host hasn't selected anything yet. This screen updates automatically.
        </p>
      )}
    </FocusBoundary>
  );
}
