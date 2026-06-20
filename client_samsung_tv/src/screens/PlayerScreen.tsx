import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Icon, PlayerControls, TvButton } from '../components';
import { IptvService } from '../iptv/iptvService';
import type { EpisodeContext } from '../iptv/episodeContext';
import { episodeLabel, nextEpisode } from '../iptv/episodeContext';
import type { IptvContentDescriptor, RoomRole } from '../protocol/payloads';
import { contentKeyOf } from '../protocol/payloads';
import { createTvPlayer, destroyActivePlayer, hasAvPlay } from '../player/createPlayer';
import { describeUrl, PLAYER_DIAGNOSTICS } from '../player/diagnostics';
import type { TvPlayer } from '../player/TvPlayer';
import type { PlaybackCommand } from '../room/playbackCommand';
import { DeferredCommandQueue } from '../room/playbackCommandQueue';
import type { LatencySnapshot, RoomClient, RoomConnectionState } from '../room/roomClient';
import type { TvSettings } from '../settings/settings';
import { formatClock, isLiveDuration, userFacingError } from '../utils/format';

export interface PlayerRemoteHandle {
  play: () => void;
  pause: () => void;
  toggle: () => void;
  seekForward: () => void;
  seekBack: () => void;
  back: () => boolean;
}

interface PlayerScreenProps {
  descriptor: IptvContentDescriptor;
  episodeContext?: EpisodeContext;
  settings: TvSettings;
  mode: 'solo' | 'room';
  role?: RoomRole;
  roomCode?: string;
  connectionState?: RoomConnectionState;
  roomClient?: RoomClient;
  command?: PlaybackCommand;
  latency: LatencySnapshot;
  onExit: () => void;
  onLocalReady?: (contentKey: string) => void;
  onPlayNext?: (descriptor: IptvContentDescriptor, episodeContext: EpisodeContext) => void;
  registerRemoteHandle: (handle: PlayerRemoteHandle | undefined) => void;
}

type PlayerStatus = 'loading' | 'ready' | 'playing' | 'paused' | 'buffering' | 'ended' | 'error';

const SEEK_STEP_MS = 10000;
const DRIFT_THRESHOLD_MS = 400;
const CONTROLS_HIDE_MS = 4500;

export function PlayerScreen({
  descriptor,
  episodeContext,
  settings,
  mode,
  role,
  roomCode,
  connectionState,
  roomClient,
  command,
  latency,
  onExit,
  onLocalReady,
  onPlayNext,
  registerRemoteHandle,
}: PlayerScreenProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const playerRef = useRef<TvPlayer | undefined>(undefined);
  const stallEpisodeRef = useRef(0);
  const activeStallEpisodeRef = useRef<number | undefined>(undefined);
  const lastAppliedSeqRef = useRef(0);
  const driftHitsRef = useRef(0);
  const commandIdRef = useRef(0);
  // Holds the latest sync command that arrived before the player was ready, so
  // it can be replayed on ready instead of being marked-applied-but-dropped.
  const deferredQueueRef = useRef(new DeferredCommandQueue());
  const playerReadyRef = useRef(false);
  const applyCommandRef = useRef<((command: PlaybackCommand) => Promise<void>) | undefined>(undefined);
  const controlsVisibleRef = useRef(true);
  const hideTimerRef = useRef<number | undefined>(undefined);
  const [status, setStatus] = useState<PlayerStatus>('loading');
  const [error, setError] = useState('');
  const [positionMs, setPositionMs] = useState(0);
  const [durationMs, setDurationMs] = useState(0);
  const [controlsVisible, setControlsVisible] = useState(true);
  const [reloadToken, setReloadToken] = useState(0);
  const [playerLabel] = useState(() => (hasAvPlay() ? 'AVPlay' : 'HTML5'));
  const [engineState, setEngineState] = useState('—');
  const [streamKind, setStreamKind] = useState('—');
  const statusRef = useRef<PlayerStatus>('loading');
  const positionRef = useRef(0);
  const latencyRef = useRef(latency);

  const iptv = useMemo(() => new IptvService(settings), [settings]);
  const contentKey = useMemo(() => contentKeyOf(descriptor), [descriptor]);
  const canControl = mode === 'solo' || role === 'host';
  const isLive = isLiveDuration(durationMs);

  // Next Episode is series-only and host/solo-only (guests carry no context).
  const nextEp = useMemo(() => (episodeContext ? nextEpisode(episodeContext) : undefined), [episodeContext]);
  const showNext = descriptor.contentType === 'episode' && canControl && !!episodeContext;
  const upNextLabel = nextEp ? `Up next: ${episodeLabel(nextEp.entry)} — ${nextEp.entry.descriptor.title}` : undefined;
  const playNext = useCallback(() => {
    if (nextEp && onPlayNext) onPlayNext(nextEp.entry.descriptor, nextEp.context);
  }, [nextEp, onPlayNext]);

  useEffect(() => {
    controlsVisibleRef.current = controlsVisible;
  }, [controlsVisible]);

  useEffect(() => {
    statusRef.current = status;
  }, [status]);

  useEffect(() => {
    positionRef.current = positionMs;
  }, [positionMs]);

  useEffect(() => {
    latencyRef.current = latency;
  }, [latency]);

  const showControls = useCallback(() => {
    setControlsVisible(true);
    controlsVisibleRef.current = true;
  }, []);

  const armHide = useCallback(() => {
    window.clearTimeout(hideTimerRef.current);
    if (statusRef.current === 'playing') {
      hideTimerRef.current = window.setTimeout(() => setControlsVisible(false), CONTROLS_HIDE_MS);
    }
  }, []);

  const focusPrimaryControl = useCallback(() => {
    window.setTimeout(() => {
      const primary = document.querySelector<HTMLButtonElement>('.player-btn--primary');
      if (primary && !primary.disabled) primary.focus();
      // Guests (inert controls) and the loading state fall back to the Back button.
      else document.querySelector<HTMLElement>('.player-chrome .player-btn:not([disabled])')?.focus();
    }, 60);
  }, []);

  const revealControls = useCallback(() => {
    showControls();
    focusPrimaryControl();
  }, [focusPrimaryControl, showControls]);

  const safePlayer = useCallback(() => playerRef.current, []);

  const updateClock = useCallback(async () => {
    const player = safePlayer();
    if (!player) return;
    const [position, duration] = await Promise.all([player.getPosition(), player.getDuration()]);
    setPositionMs(position);
    setDurationMs(duration);
    if (PLAYER_DIAGNOSTICS) setEngineState(player.getState?.() ?? '—');
  }, [safePlayer]);

  const invokePlay = useCallback(async () => {
    const player = safePlayer();
    if (!player || !canControl) return;
    const position = await player.getPosition();
    await player.play();
    setStatus('playing');
    if (mode === 'room' && role === 'host') await roomClient?.play(position, Date.now());
    showControls();
  }, [canControl, mode, role, roomClient, safePlayer, showControls]);

  const invokePause = useCallback(async () => {
    const player = safePlayer();
    if (!player || !canControl) return;
    const position = await player.getPosition();
    await player.pause();
    setStatus('paused');
    if (mode === 'room' && role === 'host') await roomClient?.pause(position);
    showControls();
  }, [canControl, mode, role, roomClient, safePlayer, showControls]);

  const invokeToggle = useCallback(() => {
    if (status === 'playing') void invokePause();
    else void invokePlay();
  }, [invokePause, invokePlay, status]);

  const invokeSeekBy = useCallback(async (deltaMs: number) => {
    const player = safePlayer();
    if (!player || !canControl) return;
    const [position, duration] = await Promise.all([player.getPosition(), player.getDuration()]);
    if (isLiveDuration(duration)) return;
    const target = Math.max(0, Math.min(position + deltaMs, duration));
    await player.seek(target);
    setPositionMs(target);
    if (mode === 'room' && role === 'host') await roomClient?.seek(target);
    showControls();
  }, [canControl, mode, role, roomClient, safePlayer, showControls]);

  const handleBack = useCallback(() => {
    if (!controlsVisibleRef.current) {
      revealControls();
      return true;
    }
    onExit();
    return true;
  }, [onExit, revealControls]);

  useEffect(() => {
    registerRemoteHandle({
      play: () => void invokePlay(),
      pause: () => void invokePause(),
      toggle: invokeToggle,
      seekForward: () => void invokeSeekBy(SEEK_STEP_MS),
      seekBack: () => void invokeSeekBy(-SEEK_STEP_MS),
      back: handleBack,
    });
    return () => registerRemoteHandle(undefined);
  }, [handleBack, invokePause, invokePlay, invokeSeekBy, invokeToggle, registerRemoteHandle]);

  // Auto-hide chrome while playing; keep it up when paused/buffering/loading.
  useEffect(() => {
    if (status === 'playing' && controlsVisible) armHide();
    else window.clearTimeout(hideTimerRef.current);
  }, [armHide, controlsVisible, status]);

  // Any remote/keyboard interaction reveals hidden chrome (and re-arms the
  // hide timer when already visible). Back is also handled here as a fallback.
  useEffect(() => {
    const onKey = () => {
      if (!controlsVisibleRef.current) revealControls();
      else armHide();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [armHide, revealControls]);

  // Land focus inside the chrome once it is interactive (and after loading
  // finishes), without stealing focus if the user already moved within it.
  useEffect(() => {
    if (status === 'loading' || status === 'error') return;
    const chrome = document.querySelector('.player-chrome');
    if (controlsVisible && chrome && !chrome.contains(document.activeElement)) {
      focusPrimaryControl();
    }
  }, [controlsVisible, focusPrimaryControl, status]);

  useEffect(() => () => window.clearTimeout(hideTimerRef.current), []);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      if (!containerRef.current) return;
      // Fresh (re)load: the player cannot execute commands until it reports ready.
      playerReadyRef.current = false;
      deferredQueueRef.current.clear();
      setStatus('loading');
      setError('');
      try {
        const url = iptv.resolvePlaybackUrl(descriptor);
        if (PLAYER_DIAGNOSTICS) setStreamKind(describeUrl(url));
        const player = createTvPlayer(containerRef.current, {
          onReady: () => {
            if (cancelled) return;
            playerReadyRef.current = true;
            setStatus('ready');
            onLocalReady?.(contentKey);
            if (mode === 'room') void roomClient?.notifyPlayerReady(contentKey).catch(() => undefined);
            // Replay the latest command that arrived before the player was ready
            // (XP-003/XP-004), now that seek/play/pause will actually execute.
            const deferred = deferredQueueRef.current.take();
            if (deferred) {
              void applyCommandRef.current?.(deferred).catch(() => undefined);
            }
          },
          onPlaying: () => setStatus('playing'),
          onPaused: () => setStatus('paused'),
          onEnded: () => setStatus('ended'),
          onBufferingChange: (buffering) => {
            if (buffering) void notifyBufferingStart();
            else void notifyBufferingEnd();
          },
          onError: (message) => {
            setError(message);
            setStatus('error');
          },
        });
        playerRef.current = player;
        await player.load(url);
        if (cancelled) return;
        await updateClock();
        if (mode === 'solo') {
          await player.play();
          setStatus('playing');
        } else {
          setStatus((current) => current === 'loading' ? 'ready' : current);
        }
      } catch (err) {
        if (!cancelled) {
          setError(userFacingError(err, 'Could not load this stream on the TV.'));
          setStatus('error');
        }
      }
    };

    async function notifyBufferingStart() {
      setStatus('buffering');
      if (mode !== 'room' || !roomClient || activeStallEpisodeRef.current !== undefined) return;
      const player = safePlayer();
      const position = player ? await player.getPosition() : positionRef.current;
      stallEpisodeRef.current += 1;
      activeStallEpisodeRef.current = stallEpisodeRef.current;
      await roomClient.notifyBufferingStall(position, activeStallEpisodeRef.current).catch(() => undefined);
    }

    async function notifyBufferingEnd() {
      if (statusRef.current === 'buffering') setStatus('paused');
      if (mode !== 'room' || !roomClient || activeStallEpisodeRef.current === undefined) return;
      const episode = activeStallEpisodeRef.current;
      activeStallEpisodeRef.current = undefined;
      await roomClient.notifyBufferingReady(episode).catch(() => undefined);
    }

    void load();
    const clockTimer = window.setInterval(() => void updateClock(), 500);
    return () => {
      cancelled = true;
      window.clearInterval(clockTimer);
      playerRef.current?.destroy();
      playerRef.current = undefined;
      destroyActivePlayer();
    };
  }, [contentKey, descriptor, iptv, mode, onLocalReady, reloadToken, roomClient, safePlayer, updateClock]);

  // Applies one room sync command to the player. Reads latency/status via refs so
  // it stays stable while using fresh values. This only runs once the player is
  // ready to execute (the gate effect below defers commands until then), so a
  // command's sequence number is never marked applied unless it can actually
  // take effect (XP-003/XP-004).
  const applyCommand = useCallback(async (command: PlaybackCommand) => {
    const player = playerRef.current;
    if (!player) return;
    if (role === 'host' && command.type !== 'bufferingStall' && command.type !== 'bufferingResume') return;
    const clockOffsetMs = latencyRef.current.clockOffsetMs;

    if (command.type === 'play') {
      const seqNo = command.payload.seqNo ?? 0;
      if (seqNo > 0 && seqNo <= lastAppliedSeqRef.current) return;
      if (seqNo > 0) lastAppliedSeqRef.current = seqNo;
      const rate = command.payload.playbackRate ?? 1;
      const elapsed = Math.max(0, Math.min(Date.now() + clockOffsetMs - command.payload.serverTimestampMs, 30000));
      const adjusted = command.payload.positionMs + Math.round(elapsed * rate) + Math.floor(command.payload.hostRttMs / 2);
      await player.seek(adjusted);
      await player.play();
      setStatus('playing');
      return;
    }

    if (command.type === 'pause') {
      const seqNo = command.payload.seqNo ?? 0;
      if (seqNo > 0 && seqNo <= lastAppliedSeqRef.current) return;
      if (seqNo > 0) lastAppliedSeqRef.current = seqNo;
      await player.pause();
      await player.seek(command.payload.positionMs);
      setStatus('paused');
      return;
    }

    if (command.type === 'seek') {
      const seqNo = command.payload.seqNo ?? 0;
      if (seqNo > 0 && seqNo <= lastAppliedSeqRef.current) return;
      if (seqNo > 0) lastAppliedSeqRef.current = seqNo;
      await player.pause();
      await player.seek(command.payload.targetPositionMs);
      if (command.payload.isPlaying ?? statusRef.current === 'playing') {
        await player.play();
        setStatus('playing');
      } else {
        setStatus('paused');
      }
      return;
    }

    if (command.type === 'stateSync') {
      if (role === 'host' || statusRef.current === 'buffering') return;
      const seqNo = command.payload.seqNo ?? 0;
      if (seqNo > 0 && seqNo < lastAppliedSeqRef.current) return;
      const rate = command.payload.playbackRate ?? 1;
      const elapsed = Math.max(0, Math.min(Date.now() + clockOffsetMs - command.payload.serverTimestampMs, 30000));
      const hostPosition = command.payload.hostPositionMs + Math.round(elapsed * rate);
      const localPosition = await player.getPosition();
      const drift = hostPosition - localPosition;
      if (Math.abs(drift) <= DRIFT_THRESHOLD_MS) {
        driftHitsRef.current = 0;
        return;
      }
      driftHitsRef.current += 1;
      if (driftHitsRef.current < 2) return;
      driftHitsRef.current = 0;
      await player.pause();
      await player.seek(hostPosition);
      if (command.payload.isPlaying) {
        await player.play();
        setStatus('playing');
      } else {
        setStatus('paused');
      }
      return;
    }

    if (command.type === 'bufferingStall') {
      if (command.payload.role === role) return;
      activeStallEpisodeRef.current = command.payload.episodeId ?? 0;
      await player.pause();
      setStatus('buffering');
      return;
    }

    if (command.type === 'bufferingResume') {
      if (activeStallEpisodeRef.current !== undefined && command.payload.episodeId !== activeStallEpisodeRef.current) return;
      activeStallEpisodeRef.current = undefined;
      await player.seek(command.payload.resumePositionMs);
      if (command.payload.isPlaying) {
        await player.play();
        setStatus('playing');
      } else {
        await player.pause();
        setStatus('paused');
      }
    }
  }, [role]);

  useEffect(() => {
    applyCommandRef.current = applyCommand;
  }, [applyCommand]);

  useEffect(() => {
    if (!command || command.id === commandIdRef.current) return;
    commandIdRef.current = command.id;
    if (mode !== 'room') return;

    // If the player can't execute commands yet (still loading), defer the latest
    // intent and replay it on ready — without marking its seq applied. Otherwise
    // apply immediately (XP-003/XP-004).
    if (!playerReadyRef.current || !playerRef.current) {
      deferredQueueRef.current.defer(command);
      return;
    }

    void applyCommand(command).catch((err) => {
      setError(userFacingError(err, 'Could not apply room sync command.'));
      setStatus('error');
    });
  }, [applyCommand, command, mode]);

  const retry = () => {
    setError('');
    setStatus('loading');
    setReloadToken((value) => value + 1);
  };

  return (
    <div className="player-screen" onMouseMove={showControls}>
      <div ref={containerRef} className="player-surface" />

      {PLAYER_DIAGNOSTICS && (
        <div className="player-diag" role="status" aria-hidden="true">
          <div className="player-diag__row"><span className="player-diag__key">Engine</span><span className="player-diag__val">{playerLabel}</span></div>
          <div className="player-diag__row"><span className="player-diag__key">Stream</span><span className="player-diag__val">{streamKind}</span></div>
          <div className="player-diag__row"><span className="player-diag__key">State</span><span className="player-diag__val">{engineState}</span></div>
          <div className="player-diag__row"><span className="player-diag__key">Status</span><span className="player-diag__val">{status}</span></div>
          <div className="player-diag__row"><span className="player-diag__key">Live</span><span className="player-diag__val">{isLive ? 'yes' : 'no'}</span></div>
          <div className="player-diag__row"><span className="player-diag__key">Pos</span><span className="player-diag__val">{formatClock(positionMs)}</span></div>
          <div className="player-diag__row"><span className="player-diag__key">Dur</span><span className="player-diag__val">{isLive ? 'LIVE' : formatClock(durationMs)}</span></div>
        </div>
      )}

      {controlsVisible && status !== 'error' && status !== 'ended' && status !== 'loading' && (
        <div className="player-chrome">
          <div className="player-scrim player-scrim--top" />
          <div className="player-scrim player-scrim--bottom" />
          <PlayerControls
            title={descriptor.title}
            contentType={descriptor.contentType}
            mode={mode}
            role={role}
            roomCode={roomCode}
            connectionState={connectionState}
            playerLabel={playerLabel}
            isPlaying={status === 'playing'}
            isLive={isLive}
            positionMs={positionMs}
            durationMs={durationMs}
            canControl={canControl}
            showNext={showNext}
            canNext={!!nextEp}
            upNextLabel={upNextLabel}
            onPlayPause={invokeToggle}
            onSeekBack={() => void invokeSeekBy(-SEEK_STEP_MS)}
            onSeekForward={() => void invokeSeekBy(SEEK_STEP_MS)}
            onNext={playNext}
            onBack={onExit}
          />
        </div>
      )}

      {status === 'loading' && (
        <div className="player-overlay" role="status">
          <div className="state-view__pulse" />
          <h2>Preparing stream</h2>
          <p>Using {playerLabel === 'AVPlay' ? 'Samsung AVPlay' : 'the HTML5 fallback'}.</p>
        </div>
      )}

      {status === 'buffering' && (
        <div className="player-overlay player-overlay--scrim" role="status">
          <div className="state-view__pulse" />
          <h2>Buffering…</h2>
          <p>{formatClock(positionMs)}</p>
        </div>
      )}

      {status === 'ended' && (
        <div className="player-overlay" role="status">
          <h2>Playback ended</h2>
          {showNext && nextEp ? (
            <>
              <p>{`Up next: ${episodeLabel(nextEp.entry)} — ${nextEp.entry.descriptor.title}`}</p>
              <div className="screen__actions screen__actions--center">
                <TvButton onClick={onExit}>Back to catalog</TvButton>
                <TvButton variant="primary" onClick={playNext}>{`Play next: ${episodeLabel(nextEp.entry)}`}</TvButton>
              </div>
            </>
          ) : (
            <TvButton variant="primary" onClick={onExit}>Back to catalog</TvButton>
          )}
        </div>
      )}

      {status === 'error' && (
        <div className="player-overlay" role="alert">
          <div className="state-view__mark"><Icon name="alert" size={48} /></div>
          <h2>Playback failed</h2>
          <p>{error}</p>
          {playerLabel === 'AVPlay' && (
            <p>Tip: the TV emulator's codec support differs from a real Samsung TV — a stream that fails here may still play on hardware.</p>
          )}
          <div className="screen__actions screen__actions--center">
            <TvButton onClick={onExit}>Back</TvButton>
            <TvButton variant="primary" onClick={retry}>Try again</TvButton>
          </div>
        </div>
      )}
    </div>
  );
}
