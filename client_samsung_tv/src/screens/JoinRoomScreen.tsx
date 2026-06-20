import { useCallback, useEffect, useRef, useState } from 'react';
import { EmptyState, ErrorState, FocusBoundary, Icon, LoadingState, RoomCard, TvButton } from '../components';
import { fetchActiveRooms, type ActiveRoom } from '../room/roomApi';
import type { TvSettings } from '../settings/settings';

interface JoinRoomScreenProps {
  settings: TvSettings;
  onJoin: (code: string) => Promise<void>;
  onBack: () => void;
}

const CODE_LENGTH = 6;
const REFRESH_INTERVAL_MS = 12000;
type RoomsStatus = 'loading' | 'loaded' | 'error';

export function JoinRoomScreen({ settings, onJoin, onBack }: JoinRoomScreenProps) {
  const [code, setCode] = useState('');
  const [joining, setJoining] = useState(false);
  const [error, setError] = useState('');

  const [rooms, setRooms] = useState<ActiveRoom[]>([]);
  const [roomsStatus, setRoomsStatus] = useState<RoomsStatus>('loading');
  const [roomsError, setRoomsError] = useState('');
  const abortRef = useRef<AbortController | undefined>(undefined);

  const loadRooms = useCallback(
    async (silent: boolean) => {
      abortRef.current?.abort();
      const controller = new AbortController();
      abortRef.current = controller;
      if (!silent) setRoomsStatus('loading');
      try {
        const list = await fetchActiveRooms(settings.serverBaseUrl, controller.signal);
        if (controller.signal.aborted) return;
        setRooms(list);
        setRoomsStatus('loaded');
        setRoomsError('');
      } catch (err) {
        if (controller.signal.aborted) return;
        // A failed silent refresh keeps the last good list on screen.
        if (!silent) {
          setRoomsError(err instanceof Error ? err.message : 'Could not load rooms.');
          setRoomsStatus('error');
        }
      }
    },
    [settings.serverBaseUrl],
  );

  // Poll the active-rooms list while the screen is mounted; stop on leave.
  useEffect(() => {
    void loadRooms(false);
    const timer = window.setInterval(() => void loadRooms(true), REFRESH_INTERVAL_MS);
    return () => {
      window.clearInterval(timer);
      abortRef.current?.abort();
    };
  }, [loadRooms]);

  const join = useCallback(
    async (raw: string) => {
      const next = raw.toUpperCase();
      if (!/^[A-Z2-9]{6}$/.test(next)) {
        setError('Room code must be six characters: A–Z or 2–9.');
        return;
      }
      setJoining(true);
      setError('');
      try {
        await onJoin(next);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Could not join room.');
        setJoining(false);
      }
    },
    [onJoin],
  );

  if (joining) {
    return (
      <FocusBoundary className="screen screen--center">
        <LoadingState title="Joining room" detail="Waiting for the host server to confirm." />
      </FocusBoundary>
    );
  }

  return (
    <FocusBoundary className="screen screen--join">
      <header className="screen__header">
        <div>
          <p className="eyebrow">Guest mode</p>
          <h1>Join a room</h1>
        </div>
        <TvButton variant="quiet" onClick={onBack}><Icon name="back" size={26} /> Home</TvButton>
      </header>

      <div className="join-layout">
        <section className="join-rooms" aria-label="Available rooms">
          <div className="join-section-head">
            <h2>Available rooms</h2>
            <TvButton variant="quiet" onClick={() => void loadRooms(false)} aria-label="Refresh rooms">
              <Icon name="refresh" size={22} /> Refresh
            </TvButton>
          </div>

          {roomsStatus === 'loading' ? (
            <LoadingState title="Finding rooms" detail="Looking for active watch parties…" />
          ) : roomsStatus === 'error' ? (
            <ErrorState
              icon={<Icon name="alert" size={30} />}
              title="Couldn’t load rooms"
              message={roomsError}
              actionLabel="Try again"
              onAction={() => void loadRooms(false)}
            />
          ) : rooms.length === 0 ? (
            <EmptyState
              icon={<Icon name="live" size={40} />}
              title="No active rooms"
              hint="No one is hosting right now. Enter a code to join, or create your own room."
            />
          ) : (
            <div className="room-list">
              {rooms.map((room) => (
                <RoomCard key={room.roomCode} room={room} onJoin={(value) => void join(value)} />
              ))}
            </div>
          )}
        </section>

        <section className="join-code room-action-panel" aria-label="Join by code">
          <p className="eyebrow">Have a code?</p>
          <h2>Enter room code</h2>
          <p className="join-code__hint">Type the host’s 6-character code. Playback URLs still resolve locally on this TV.</p>

          <div className="code-display" aria-hidden="true">
            {Array.from({ length: CODE_LENGTH }).map((_, index) => (
              <div
                key={index}
                className={`code-cell ${code[index] ? 'code-cell--filled' : ''} ${index === code.length ? 'code-cell--active' : ''}`}
              >
                {code[index] ?? ''}
              </div>
            ))}
          </div>

          <input
            className="code-input"
            data-tv-focusable="true"
            value={code}
            maxLength={CODE_LENGTH}
            placeholder="ABC234"
            aria-label="Room code"
            inputMode="text"
            autoCapitalize="characters"
            onChange={(event) => setCode(event.currentTarget.value.toUpperCase().replace(/[^A-Z2-9]/g, '').slice(0, CODE_LENGTH))}
          />

          {error && <p className="join-code__error" role="alert">{error}</p>}

          <div className="screen__actions screen__actions--center">
            <TvButton variant="primary" disabled={code.length !== CODE_LENGTH} onClick={() => void join(code)}>
              <Icon name="join" size={24} /> Join room
            </TvButton>
          </div>
        </section>
      </div>
    </FocusBoundary>
  );
}
