import { Icon } from './Icon';
import type { ActiveRoom } from '../room/roomApi';

interface RoomCardProps {
  room: ActiveRoom;
  onJoin: (code: string) => void;
}

const CONTENT_LABEL: Record<string, string> = {
  live: 'Live',
  movie: 'Movie',
  episode: 'Series',
};

/**
 * Focusable, remote-joinable card for one active room. Mirrors the Flutter
 * client's room_card.dart: room code, a coloured status line, age and host
 * ping, plus a clear Join affordance. Shows content *type* only (never titles,
 * URLs or credentials) — exactly what the public rooms endpoint exposes.
 */
export function RoomCard({ room, onJoin }: RoomCardProps) {
  const joinable = room.isJoinable;
  const participants = (room.hostConnected ? 1 : 0) + (room.hasGuest ? 1 : 0);

  let statusText = 'Waiting for guest';
  let statusKind: 'success' | 'accent' | 'danger' = 'success';
  if (!joinable) {
    statusText = 'Room is full';
    statusKind = 'danger';
  } else if (room.contentSet) {
    statusText = `Playing: ${CONTENT_LABEL[room.contentType ?? ''] ?? 'Content'}`;
    statusKind = 'accent';
  }

  const age = formatAge(room.createdAt);
  const ping = room.hostRtt && room.hostRtt > 0 && room.hostRtt < 500 ? `${room.hostRtt}ms ping` : undefined;

  return (
    <button
      type="button"
      className={`room-list-card room-list-card--${statusKind} ${joinable ? '' : 'room-list-card--full'}`}
      data-tv-focusable="true"
      aria-disabled={joinable ? undefined : 'true'}
      aria-label={`Room ${room.roomCode}. ${statusText}.${joinable ? ' Press to join.' : ''}`}
      onClick={() => joinable && onJoin(room.roomCode)}
    >
      <span className="room-list-card__icon" aria-hidden="true">
        <Icon name={joinable ? (room.contentSet ? 'play' : 'live') : 'alert'} size={28} />
      </span>
      <span className="room-list-card__body">
        <span className="room-list-card__top">
          <span className="room-list-card__code">{room.roomCode}</span>
          {age && <span className="room-list-card__age">{age}</span>}
        </span>
        <span className="room-list-card__status">
          <span className="status-dot" aria-hidden="true" />
          {statusText}
        </span>
        <span className="room-list-card__meta">
          <span>{participants}/2 watching</span>
          {ping && <span>· {ping}</span>}
        </span>
      </span>
      <span className="room-list-card__join">{joinable ? 'Join' : 'Full'}</span>
    </button>
  );
}

function formatAge(createdAt?: string): string {
  if (!createdAt) return '';
  const created = Date.parse(createdAt);
  if (Number.isNaN(created)) return '';
  const minutes = Math.max(0, Math.floor((Date.now() - created) / 60000));
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes}m ago`;
  return `${Math.floor(minutes / 60)}h ago`;
}
