import { FocusBoundary, Icon, TvCard, TvGrid } from '../components';
import type { RoomConnectionState } from '../room/roomClient';
import type { TvSettings } from '../settings/settings';

interface HomeScreenProps {
  settings: TvSettings;
  connectionState: RoomConnectionState;
  roomCode?: string;
  role?: string;
  onNavigate: (screen: 'live' | 'vod' | 'series' | 'create-room' | 'join-room' | 'settings' | 'login') => void;
}

const CONNECTION_LABEL: Record<RoomConnectionState, string> = {
  disconnected: 'Server offline',
  connecting: 'Connecting…',
  connected: 'Server ready',
  reconnecting: 'Reconnecting…',
};

export function HomeScreen({ settings, connectionState, roomCode, role, onNavigate }: HomeScreenProps) {
  return (
    <FocusBoundary className="screen screen--home">
      <header className="home-hero">
        <div>
          <p className="brand brand--sm">moon<span className="brand__dot">.</span></p>
          <h1>{settings.deviceName || 'MoonWatch TV'}</h1>
          <p>Browse live channels, movies, and series — or host a synced watch party with friends.</p>
        </div>
        <div className="conn-pill">
          <span className={`status-dot status-dot--${connectionState}`} aria-hidden="true" />
          {roomCode ? `Room ${roomCode} · ${role === 'host' ? 'Host' : 'Guest'}` : CONNECTION_LABEL[connectionState]}
        </div>
      </header>

      <section className="home-section">
        <p className="section-label">Watch</p>
        <TvGrid wide>
          <TvCard
            variant="feature"
            icon={<Icon name="live" size={58} />}
            eyebrow="Channels"
            title="Live TV"
            subtitle="Live channels and events"
            onClick={() => onNavigate('live')}
          />
          <TvCard
            variant="feature"
            icon={<Icon name="movie" size={58} />}
            eyebrow="Movies"
            title="VOD"
            subtitle="On-demand film library"
            onClick={() => onNavigate('vod')}
          />
          <TvCard
            variant="feature"
            icon={<Icon name="series" size={58} />}
            eyebrow="Episodes"
            title="Series"
            subtitle="Seasons and episodes"
            onClick={() => onNavigate('series')}
          />
        </TvGrid>
      </section>

      <section className="home-section">
        <p className="section-label">Watch party &amp; device</p>
        <TvGrid wide>
          <TvCard
            variant="feature"
            icon={<Icon name="create" size={58} />}
            eyebrow="Host"
            title="Create Room"
            subtitle="Share a six-character code"
            onClick={() => onNavigate('create-room')}
          />
          <TvCard
            variant="feature"
            icon={<Icon name="join" size={58} />}
            eyebrow="Guest"
            title="Join Room"
            subtitle="Enter a host's room code"
            onClick={() => onNavigate('join-room')}
          />
          <TvCard
            variant="feature"
            icon={<Icon name="settings" size={58} />}
            eyebrow="Device"
            title="Settings"
            subtitle="IPTV provider and server"
            onClick={() => onNavigate('settings')}
          />
        </TvGrid>
      </section>
    </FocusBoundary>
  );
}
