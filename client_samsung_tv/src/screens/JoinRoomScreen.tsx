import { useState } from 'react';
import { ErrorState, FocusBoundary, Icon, LoadingState, TvButton } from '../components';

interface JoinRoomScreenProps {
  onJoin: (code: string) => Promise<void>;
  onBack: () => void;
}

const CODE_LENGTH = 6;

export function JoinRoomScreen({ onJoin, onBack }: JoinRoomScreenProps) {
  const [code, setCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const join = async () => {
    if (!/^[A-Z2-9]{6}$/.test(code)) {
      setError('Room code must be six characters: A–Z or 2–9.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      await onJoin(code);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not join room.');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <FocusBoundary className="screen screen--center">
        <LoadingState title="Joining room" detail="Waiting for the host server to confirm." />
      </FocusBoundary>
    );
  }

  if (error) {
    return (
      <FocusBoundary className="screen screen--center">
        <ErrorState
          icon={<Icon name="alert" size={30} />}
          title="Join failed"
          message={error}
          actionLabel="Try again"
          onAction={() => setError('')}
          secondaryLabel="Back"
          onSecondary={onBack}
        />
      </FocusBoundary>
    );
  }

  return (
    <FocusBoundary className="screen screen--center">
      <div className="room-action-panel" style={{ textAlign: 'center' }}>
        <p className="eyebrow">Guest mode</p>
        <h1>Join a room</h1>
        <p style={{ margin: '0 auto 4px' }}>Enter the host's room code. Playback URLs still resolve locally on this TV.</p>

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

        <div className="screen__actions screen__actions--center">
          <TvButton variant="quiet" onClick={onBack}><Icon name="back" size={24} /> Back</TvButton>
          <TvButton variant="primary" disabled={code.length !== CODE_LENGTH} onClick={() => void join()}>
            <Icon name="join" size={24} /> Join room
          </TvButton>
        </div>
      </div>
    </FocusBoundary>
  );
}
