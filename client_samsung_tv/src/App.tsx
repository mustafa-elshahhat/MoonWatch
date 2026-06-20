import { useCallback, useEffect, useRef, useState } from 'react';
import './styles.css';
import { BrowseScreen } from './screens/BrowseScreen';
import { CreateRoomScreen } from './screens/CreateRoomScreen';
import { ErrorDisconnectedScreen } from './screens/ErrorDisconnectedScreen';
import { HomeScreen } from './screens/HomeScreen';
import { JoinRoomScreen } from './screens/JoinRoomScreen';
import { LoginScreen } from './screens/LoginScreen';
import { PlayerScreen, type PlayerRemoteHandle } from './screens/PlayerScreen';
import { RoomWaitingScreen } from './screens/RoomWaitingScreen';
import { SeriesScreen } from './screens/SeriesScreen';
import { SettingsScreen } from './screens/SettingsScreen';
import { TvModal } from './components';
import type { IptvContentDescriptor, PlayerReadyPayload, RoomJoinedPayload, RoomRole } from './protocol/payloads';
import { contentKeyOf } from './protocol/payloads';
import type { EpisodeContext } from './iptv/episodeContext';
import type { PlaybackCommand } from './room/playbackCommand';
import { RoomClient, type LatencySnapshot, type RoomConnectionState } from './room/roomClient';
import { useRemoteNavigation } from './navigation/remote';
import type { TvSettings } from './settings/settings';
import { hasPlaybackSettings, hasServerSettings, loadSettings, saveSettings, validateSettings } from './settings/settings';
import { userFacingError } from './utils/format';

type Screen = 'settings' | 'login' | 'home' | 'live' | 'vod' | 'series' | 'create-room' | 'join-room' | 'waiting' | 'player' | 'error';

interface RoomSnapshot {
  roomCode: string;
  role: RoomRole;
  guestPresent: boolean;
  contentDescriptor?: IptvContentDescriptor | null;
  peerStatus: 'connected' | 'away' | 'waiting';
  localReady: boolean;
  peerReady: boolean;
  playbackRate: number;
}

interface PlayerIntent {
  descriptor: IptvContentDescriptor;
  mode: 'solo' | 'room';
  previousScreen: Screen;
  /** Client-only series navigation (solo/host); never sent over SignalR. */
  episodeContext?: EpisodeContext;
}

interface ErrorView {
  title: string;
  message: string;
}

function initialScreen(settings: TvSettings): Screen {
  if (!hasPlaybackSettings(settings)) return validateSettings(settings, 'iptv').length === 0 ? 'login' : 'settings';
  return 'home';
}

export default function App() {
  const [settings, setSettings] = useState<TvSettings>(() => loadSettings());
  const [screen, setScreen] = useState<Screen>(() => initialScreen(loadSettings()));
  const [room, setRoom] = useState<RoomSnapshot | undefined>();
  const [connectionState, setConnectionState] = useState<RoomConnectionState>('disconnected');
  const [latency, setLatency] = useState<LatencySnapshot>({ rttMs: 100, clockOffsetMs: 0 });
  const [playerIntent, setPlayerIntent] = useState<PlayerIntent | undefined>();
  const [playbackCommand, setPlaybackCommand] = useState<PlaybackCommand | undefined>();
  const [errorView, setErrorView] = useState<ErrorView>({ title: 'Disconnected', message: '' });
  const [exitHint, setExitHint] = useState(false);
  const roomClientRef = useRef<RoomClient | undefined>(undefined);
  const playerRemoteRef = useRef<PlayerRemoteHandle | undefined>(undefined);
  const commandSeqRef = useRef(0);
  const screenRef = useRef(screen);

  useEffect(() => {
    screenRef.current = screen;
  }, [screen]);

  const emitCommand = useCallback((command: Omit<PlaybackCommand, 'id'>) => {
    commandSeqRef.current += 1;
    setPlaybackCommand({ ...command, id: commandSeqRef.current } as PlaybackCommand);
  }, []);

  const updateReadyState = useCallback((payload: PlayerReadyPayload) => {
    setRoom((current) => {
      if (!current?.contentDescriptor || contentKeyOf(current.contentDescriptor) !== payload.contentKey) return current;
      const isLocal = current.role === payload.readyRole;
      return {
        ...current,
        localReady: payload.bothReady || (isLocal ? true : current.localReady),
        peerReady: payload.bothReady || (!isLocal ? true : current.peerReady),
      };
    });
  }, []);

  useEffect(() => {
    if (!hasServerSettings(settings)) {
      void roomClientRef.current?.dispose();
      roomClientRef.current = undefined;
      setConnectionState('disconnected');
      return;
    }

    const client = new RoomClient(settings.serverBaseUrl, {
      onConnectionState: setConnectionState,
      onLatency: setLatency,
      onRoomJoined: (payload) => {
        const snapshot = roomFromPayload(payload);
        setRoom(snapshot);
        if (payload.contentDescriptor) {
          setPlayerIntent({ descriptor: payload.contentDescriptor, mode: 'room', previousScreen: 'waiting' });
          setScreen('player');
        } else {
          setScreen('waiting');
        }
      },
      onGuestJoined: () => setRoom((current) => current ? { ...current, guestPresent: true, peerStatus: 'connected' } : current),
      onGuestLeft: () => setRoom((current) => current ? { ...current, guestPresent: false, peerStatus: 'away', peerReady: false } : current),
      onGuestReconnected: () => setRoom((current) => current ? { ...current, guestPresent: true, peerStatus: 'connected' } : current),
      onRoomClosed: (payload) => {
        setRoom(undefined);
        setPlayerIntent(undefined);
        setErrorView({ title: 'Room closed', message: `The room closed: ${payload.reason}.` });
        setScreen('error');
      },
      onContentSet: (payload) => {
        setRoom((current) => current ? {
          ...current,
          contentDescriptor: payload.descriptor,
          localReady: false,
          peerReady: false,
        } : current);
        setPlayerIntent({ descriptor: payload.descriptor, mode: 'room', previousScreen: 'waiting' });
        setScreen('player');
      },
      onRoomError: (payload) => {
        setErrorView({ title: 'Room error', message: payload.message || payload.code });
        if (payload.code === 'room_closed' || payload.code === 'room_not_found' || payload.code === 'reconnect_failed') setScreen('error');
      },
      onPlayerReady: updateReadyState,
      onPlaybackPlay: (payload) => emitCommand({ type: 'play', payload }),
      onPlaybackPause: (payload) => emitCommand({ type: 'pause', payload }),
      onPlaybackSeek: (payload) => emitCommand({ type: 'seek', payload }),
      onPlaybackStateSync: (payload) => emitCommand({ type: 'stateSync', payload }),
      onPlaybackSpeed: (payload) => emitCommand({ type: 'speed', payload }),
      onBufferingStall: (payload) => emitCommand({ type: 'bufferingStall', payload }),
      onBufferingResume: (payload) => emitCommand({ type: 'bufferingResume', payload }),
    });

    roomClientRef.current = client;
    return () => {
      void client.dispose();
      if (roomClientRef.current === client) roomClientRef.current = undefined;
    };
  }, [emitCommand, settings, updateReadyState]);

  const registerRemoteHandle = useCallback((handle: PlayerRemoteHandle | undefined) => {
    playerRemoteRef.current = handle;
  }, []);

  const goHome = useCallback(() => {
    setExitHint(false);
    setScreen('home');
  }, []);

  const goSettings = useCallback(() => {
    setExitHint(false);
    setScreen('settings');
  }, []);

  const goLogin = useCallback(() => {
    setExitHint(false);
    setScreen('login');
  }, []);

  const openPlayerForRoomContent = useCallback(() => {
    if (!room?.contentDescriptor) return;
    setPlayerIntent({ descriptor: room.contentDescriptor, mode: 'room', previousScreen: 'waiting' });
    setScreen('player');
  }, [room]);

  const validateOrRoute = useCallback((scope: 'server' | 'playback'): boolean => {
    const errors = validateSettings(settings, scope);
    if (errors.length === 0) return true;
    setErrorView({ title: 'Configuration required', message: errors[0] });
    setScreen(scope === 'server' ? 'settings' : 'login');
    return false;
  }, [settings]);

  const navigate = useCallback((target: 'live' | 'vod' | 'series' | 'create-room' | 'join-room' | 'settings' | 'login') => {
    setExitHint(false);
    if ((target === 'live' || target === 'vod' || target === 'series') && !validateOrRoute('playback')) return;
    if ((target === 'create-room' || target === 'join-room') && !validateOrRoute('server')) return;
    setScreen(target);
  }, [validateOrRoute]);

  const handleSelectContent = useCallback(async (descriptor: IptvContentDescriptor, episodeContext?: EpisodeContext) => {
    if (!validateOrRoute('playback')) return;
    if (room?.role === 'guest') {
      setErrorView({ title: 'Host controls content', message: 'Guests cannot change room content. Wait for the host to choose what to watch.' });
      setScreen('error');
      return;
    }

    if (room?.role === 'host') {
      const client = roomClientRef.current;
      if (!client) throw new Error('Room connection is not ready.');
      await client.setContent(descriptor);
      setRoom((current) => current ? { ...current, contentDescriptor: descriptor, localReady: false, peerReady: false } : current);
      setPlayerIntent({ descriptor, mode: 'room', previousScreen: screenRef.current, episodeContext });
      setScreen('player');
      return;
    }

    setPlayerIntent({ descriptor, mode: 'solo', previousScreen: screenRef.current, episodeContext });
    setScreen('player');
  }, [room, validateOrRoute]);

  // Advance to the next episode from inside the player (solo & host). The host
  // re-uses the existing SetContent sync so guests follow via room:content_set;
  // only the plain descriptor crosses the wire — the episode context is local.
  const advanceEpisode = useCallback(async (descriptor: IptvContentDescriptor, episodeContext: EpisodeContext) => {
    if (room?.role === 'host') {
      await roomClientRef.current?.setContent(descriptor);
      setRoom((current) => current ? { ...current, contentDescriptor: descriptor, localReady: false, peerReady: false } : current);
    }
    setPlayerIntent((current) => current ? { ...current, descriptor, episodeContext } : current);
  }, [room]);

  const createRoom = useCallback(async () => {
    if (!validateOrRoute('server')) return;
    const client = roomClientRef.current;
    if (!client) throw new Error('Room client is not configured.');
    await client.createRoom();
  }, [validateOrRoute]);

  const joinRoom = useCallback(async (code: string) => {
    if (!validateOrRoute('server')) return;
    const client = roomClientRef.current;
    if (!client) throw new Error('Room client is not configured.');
    await client.joinRoom(code, 'guest');
  }, [validateOrRoute]);

  const leaveRoom = useCallback(async () => {
    await roomClientRef.current?.leaveRoom().catch(() => undefined);
    setRoom(undefined);
    setPlayerIntent(undefined);
    setPlaybackCommand(undefined);
    setScreen('home');
  }, []);

  const saveAllSettings = useCallback((next: TvSettings) => {
    const saved = saveSettings(next);
    setSettings(saved);
    setScreen(hasPlaybackSettings(saved) ? 'home' : 'login');
  }, []);

  const saveCredentials = useCallback((username: string, password: string) => {
    const saved = saveSettings({ ...settings, iptvUsername: username, iptvPassword: password });
    setSettings(saved);
    setScreen('home');
  }, [settings]);

  const markLocalReady = useCallback((readyContentKey: string) => {
    setRoom((current) => {
      if (!current?.contentDescriptor || contentKeyOf(current.contentDescriptor) !== readyContentKey) return current;
      return { ...current, localReady: true };
    });
  }, []);

  const exitPlayer = useCallback(() => {
    const previous = playerIntent?.previousScreen;
    if (playerIntent?.mode === 'room') {
      setScreen(previous && previous !== 'player' ? previous : 'waiting');
    } else {
      setScreen(previous && previous !== 'player' ? previous : 'home');
    }
  }, [playerIntent]);

  const handleBack = useCallback(() => {
    if (screen === 'player') {
      if (playerRemoteRef.current?.back()) return;
      exitPlayer();
      return;
    }
    if (screen === 'live' || screen === 'vod' || screen === 'series' || screen === 'create-room' || screen === 'join-room' || screen === 'error') {
      goHome();
      return;
    }
    if (screen === 'settings' || screen === 'login') {
      setScreen(hasPlaybackSettings(settings) ? 'home' : 'settings');
      return;
    }
    if (screen === 'waiting') {
      goHome();
      return;
    }
    setExitHint(true);
  }, [exitPlayer, goHome, screen, settings]);

  useRemoteNavigation({
    onBack: handleBack,
    onPlay: () => playerRemoteRef.current?.play(),
    onPause: () => playerRemoteRef.current?.pause(),
    onFastForward: () => playerRemoteRef.current?.seekForward(),
    onRewind: () => playerRemoteRef.current?.seekBack(),
  });

  const body = (() => {
    try {
      if (screen === 'settings') return <SettingsScreen settings={settings} onSave={saveAllSettings} onBack={goHome} />;
      if (screen === 'login') return <LoginScreen settings={settings} onSaveCredentials={saveCredentials} onSettings={goSettings} />;
      if (screen === 'live') return <BrowseScreen kind="live" settings={settings} roomRole={room?.role} onSelect={handleSelectContent} onBack={goHome} onSettings={goSettings} />;
      if (screen === 'vod') return <BrowseScreen kind="movie" settings={settings} roomRole={room?.role} onSelect={handleSelectContent} onBack={goHome} onSettings={goSettings} />;
      if (screen === 'series') return <SeriesScreen settings={settings} roomRole={room?.role} onSelect={handleSelectContent} onBack={goHome} onSettings={goSettings} />;
      if (screen === 'create-room') return <CreateRoomScreen onCreate={createRoom} onBack={goHome} />;
      if (screen === 'join-room') return <JoinRoomScreen settings={settings} onJoin={joinRoom} onBack={goHome} />;
      if (screen === 'waiting' && room) {
        return (
          <RoomWaitingScreen
            roomCode={room.roomCode}
            role={room.role}
            guestPresent={room.guestPresent}
            connectionState={connectionState}
            descriptor={room.contentDescriptor}
            onBrowse={(kind) => navigate(kind)}
            onStartContent={openPlayerForRoomContent}
            onLeave={leaveRoom}
          />
        );
      }
      if (screen === 'player' && playerIntent) {
        return (
          <PlayerScreen
            descriptor={playerIntent.descriptor}
            episodeContext={playerIntent.episodeContext}
            settings={settings}
            mode={playerIntent.mode}
            role={room?.role}
            roomCode={room?.roomCode}
            connectionState={connectionState}
            roomClient={roomClientRef.current}
            command={playbackCommand}
            latency={latency}
            onExit={exitPlayer}
            onLocalReady={markLocalReady}
            onPlayNext={advanceEpisode}
            registerRemoteHandle={registerRemoteHandle}
          />
        );
      }
      if (screen === 'error') return <ErrorDisconnectedScreen title={errorView.title} message={errorView.message} onHome={goHome} onSettings={goSettings} />;
      return <HomeScreen settings={settings} connectionState={connectionState} roomCode={room?.roomCode} role={room?.role} onNavigate={navigate} />;
    } catch (error) {
      return <ErrorDisconnectedScreen title="Application error" message={userFacingError(error)} onHome={goHome} onSettings={goSettings} />;
    }
  })();

  return (
    <div className="app-shell">
      {body}
      {connectionState === 'reconnecting' && (
        <div className="connection-banner">
          <span className="status-dot status-dot--reconnecting" aria-hidden="true" />
          Reconnecting to room server…
        </div>
      )}
      {exitHint && (
        <TvModal title="MoonWatch TV" confirmLabel="Stay on Home" onConfirm={() => setExitHint(false)}>
          <p>Use the TV remote Home or Exit key to close the app.</p>
        </TvModal>
      )}
    </div>
  );
}

function roomFromPayload(payload: RoomJoinedPayload): RoomSnapshot {
  return {
    roomCode: payload.roomCode,
    role: payload.role,
    guestPresent: payload.guestPresent,
    contentDescriptor: payload.contentDescriptor,
    peerStatus: payload.guestPresent ? 'connected' : 'waiting',
    localReady: false,
    peerReady: false,
    playbackRate: payload.playbackRate ?? 1,
  };
}
