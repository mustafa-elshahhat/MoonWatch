import { useState } from 'react';
import { ErrorState, FocusBoundary, Icon, LoadingState, TvButton } from '../components';

interface CreateRoomScreenProps {
  onCreate: () => Promise<void>;
  onBack: () => void;
}

export function CreateRoomScreen({ onCreate, onBack }: CreateRoomScreenProps) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const create = async () => {
    setLoading(true);
    setError('');
    try {
      await onCreate();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not create room.');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <FocusBoundary className="screen screen--center">
        <LoadingState title="Creating room" detail="Connecting to the MoonWatch server." />
      </FocusBoundary>
    );
  }

  if (error) {
    return (
      <FocusBoundary className="screen screen--center">
        <ErrorState
          icon={<Icon name="alert" size={30} />}
          title="Room not created"
          message={error}
          actionLabel="Try again"
          onAction={() => void create()}
          secondaryLabel="Back"
          onSecondary={onBack}
        />
      </FocusBoundary>
    );
  }

  return (
    <FocusBoundary className="screen screen--center">
      <div className="room-action-panel" style={{ textAlign: 'center' }}>
        <p className="eyebrow">Host mode</p>
        <h1>Create a room</h1>
        <p style={{ margin: '0 auto 8px' }}>
          This TV becomes the host. Guests join with a six-character code and follow your play, pause, and seek.
        </p>
        <div className="screen__actions screen__actions--center">
          <TvButton variant="quiet" onClick={onBack}><Icon name="back" size={24} /> Back</TvButton>
          <TvButton variant="primary" onClick={() => void create()}><Icon name="create" size={24} /> Create room</TvButton>
        </div>
      </div>
    </FocusBoundary>
  );
}
