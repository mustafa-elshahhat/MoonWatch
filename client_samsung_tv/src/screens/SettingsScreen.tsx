import { useState } from 'react';
import { FocusBoundary, Icon, TvButton, TvInput } from '../components';
import { IptvService } from '../iptv/iptvService';
import type { TvSettings } from '../settings/settings';
import { isDefaultServer, validateSettings } from '../settings/settings';
import { PRODUCTION_SERVER_BASE_URL } from '../config/appConfig';
import { userFacingError } from '../utils/format';

interface SettingsScreenProps {
  settings: TvSettings;
  onSave: (settings: TvSettings) => void;
  onBack: () => void;
}

type TestState =
  | { kind: 'idle' }
  | { kind: 'pending' }
  | { kind: 'ok'; message: string }
  | { kind: 'bad'; message: string };

export function SettingsScreen({ settings, onSave, onBack }: SettingsScreenProps) {
  const [draft, setDraft] = useState<TvSettings>(settings);
  const [errors, setErrors] = useState<string[]>([]);
  const [showAdvanced, setShowAdvanced] = useState(!isDefaultServer(settings));
  const [test, setTest] = useState<TestState>({ kind: 'idle' });

  const update = (field: keyof TvSettings, value: string) => {
    setDraft((current) => ({ ...current, [field]: value }));
    setTest({ kind: 'idle' });
  };

  const save = () => {
    const validation = validateSettings(draft, 'all');
    setErrors(validation);
    if (validation.length === 0) onSave(draft);
  };

  const testConnection = async () => {
    const validation = validateSettings(draft, 'playback');
    if (validation.length > 0) {
      setErrors(validation);
      setTest({ kind: 'bad', message: validation[0] });
      return;
    }
    setErrors([]);
    setTest({ kind: 'pending' });
    try {
      const [iptvOk, serverOk] = await Promise.all([
        new IptvService(draft).verifyCredentials(draft.iptvUsername, draft.iptvPassword),
        pingServer(draft.serverBaseUrl),
      ]);
      if (!iptvOk) {
        setTest({ kind: 'bad', message: 'IPTV authentication failed — check the username and password.' });
        return;
      }
      setTest({
        kind: 'ok',
        message: serverOk ? 'IPTV provider connected · room server reachable.' : 'IPTV provider connected · room server unreachable.',
      });
    } catch (err) {
      setTest({ kind: 'bad', message: userFacingError(err, 'Could not reach the IPTV provider.') });
    }
  };

  return (
    <FocusBoundary className="screen screen--settings">
      <header className="screen__header">
        <div>
          <p className="eyebrow">Device setup</p>
          <h1>Settings</h1>
          <p>Enter your IPTV provider details. The MoonWatch server is already set to the production backend.</p>
        </div>
        <TvButton variant="quiet" onClick={onBack}><Icon name="back" size={26} /> Home</TvButton>
      </header>

      {errors.length > 0 && (
        <div className="validation-panel" role="alert">
          {errors.map((error) => <div key={error}>{error}</div>)}
        </div>
      )}

      <div className="settings-layout">
        <section className="settings-panel settings-panel--accent">
          <h2>IPTV provider</h2>
          <p className="panel-hint">Your credentials stay on this TV (LocalStorage) and are used to browse and resolve playback URLs.</p>
          <TvInput
            label="IPTV Base URL"
            value={draft.iptvBaseUrl}
            placeholder="http://provider.example.com"
            hint="Pre-filled to match the MoonWatch app. Change it if your provider differs."
            onChange={(event) => update('iptvBaseUrl', event.currentTarget.value)}
          />
          <TvInput
            label="IPTV username"
            value={draft.iptvUsername}
            placeholder="username"
            onChange={(event) => update('iptvUsername', event.currentTarget.value)}
          />
          <TvInput
            label="IPTV password"
            type="password"
            value={draft.iptvPassword}
            placeholder="••••••••"
            onChange={(event) => update('iptvPassword', event.currentTarget.value)}
          />
          {test.kind !== 'idle' && (
            <div className={`test-result test-result--${test.kind === 'pending' ? 'pending' : test.kind}`} role="status">
              {test.kind === 'pending' ? (
                <><span className="status-dot status-dot--connecting" /> Testing connection…</>
              ) : test.kind === 'ok' ? (
                <><Icon name="check" size={24} /> {test.message}</>
              ) : (
                <><Icon name="alert" size={24} /> {test.message}</>
              )}
            </div>
          )}
          <TvButton onClick={() => void testConnection()} disabled={test.kind === 'pending'}>
            <Icon name="signal" size={24} /> Test connection
          </TvButton>
        </section>

        <section className="settings-panel">
          <h2>This TV</h2>
          <p className="panel-hint">A friendly name shown on the home screen and in watch-party rooms.</p>
          <TvInput
            label="Device name (optional)"
            value={draft.deviceName}
            placeholder="Living Room TV"
            onChange={(event) => update('deviceName', event.currentTarget.value)}
          />

          <button
            type="button"
            className="advanced-toggle"
            data-tv-focusable="true"
            aria-expanded={showAdvanced}
            onClick={() => setShowAdvanced((value) => !value)}
          >
            <span className="advanced-toggle__chevron"><Icon name="forward" size={22} /></span>
            Advanced server settings
          </button>

          {showAdvanced && (
            <div style={{ marginTop: 22 }}>
              <TvInput
                label="Server Base URL"
                value={draft.serverBaseUrl}
                placeholder={PRODUCTION_SERVER_BASE_URL}
                hint={isDefaultServer(draft) ? 'Using the production backend (default).' : 'Custom server — leave blank to use the production default.'}
                onChange={(event) => update('serverBaseUrl', event.currentTarget.value)}
              />
              {!isDefaultServer(draft) && (
                <TvButton variant="quiet" onClick={() => update('serverBaseUrl', PRODUCTION_SERVER_BASE_URL)}>
                  Reset to production default
                </TvButton>
              )}
            </div>
          )}
        </section>
      </div>

      <div className="screen__actions">
        <TvButton onClick={onBack}>Back</TvButton>
        <TvButton variant="primary" onClick={save}><Icon name="check" size={24} /> Save settings</TvButton>
      </div>
    </FocusBoundary>
  );
}

/** Best-effort reachability probe; opaque (no-cors) so it only tells us up/down. */
async function pingServer(serverBaseUrl: string): Promise<boolean> {
  try {
    await fetch(`${serverBaseUrl.replace(/\/+$/, '')}/api/v1`, { mode: 'no-cors' });
    return true;
  } catch {
    return false;
  }
}
