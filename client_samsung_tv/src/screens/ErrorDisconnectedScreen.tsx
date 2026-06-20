import { ErrorState, FocusBoundary, Icon } from '../components';

interface ErrorDisconnectedScreenProps {
  title?: string;
  message: string;
  onHome: () => void;
  onSettings: () => void;
}

export function ErrorDisconnectedScreen({ title = 'Disconnected', message, onHome, onSettings }: ErrorDisconnectedScreenProps) {
  return (
    <FocusBoundary className="screen screen--center">
      <ErrorState
        icon={<Icon name="alert" size={30} />}
        title={title}
        message={message}
        actionLabel="Home"
        onAction={onHome}
        secondaryLabel="Settings"
        onSecondary={onSettings}
      />
    </FocusBoundary>
  );
}
