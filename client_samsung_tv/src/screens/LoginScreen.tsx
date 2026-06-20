import { useMemo, useState } from 'react';
import { ErrorState, FocusBoundary, Icon, TvButton, TvInput } from '../components';
import { IptvService } from '../iptv/iptvService';
import type { TvSettings } from '../settings/settings';
import { validateSettings } from '../settings/settings';
import { userFacingError } from '../utils/format';

interface LoginScreenProps {
  settings: TvSettings;
  onSaveCredentials: (username: string, password: string) => void;
  onSettings: () => void;
}

export function LoginScreen({ settings, onSaveCredentials, onSettings }: LoginScreenProps) {
  const [username, setUsername] = useState(settings.iptvUsername);
  const [password, setPassword] = useState(settings.iptvPassword);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const missingBaseUrl = useMemo(() => validateSettings(settings, 'iptv').length > 0, [settings]);

  const submit = async () => {
    const candidate = { ...settings, iptvUsername: username, iptvPassword: password };
    const errors = validateSettings(candidate, 'login');
    if (errors.length > 0) {
      setError(errors[0]);
      return;
    }
    setLoading(true);
    setError('');
    try {
      const ok = await new IptvService(candidate).verifyCredentials(username, password);
      if (!ok) {
        setError('IPTV authentication failed — check your username and password.');
        return;
      }
      onSaveCredentials(username, password);
    } catch (err) {
      setError(userFacingError(err, 'Could not verify IPTV credentials.'));
    } finally {
      setLoading(false);
    }
  };

  if (missingBaseUrl) {
    return (
      <FocusBoundary className="screen screen--center">
        <ErrorState
          icon={<Icon name="alert" size={30} />}
          title="IPTV URL required"
          message="Set the IPTV Base URL before signing in on this TV."
          actionLabel="Open Settings"
          onAction={onSettings}
        />
      </FocusBoundary>
    );
  }

  return (
    <FocusBoundary className="screen screen--center">
      <div className="login-panel" style={{ textAlign: 'center' }}>
        <p className="brand">moon<span className="brand__dot">.</span></p>
        <p className="eyebrow" style={{ marginTop: 18 }}>IPTV sign in</p>
        <p style={{ margin: '0 auto 28px' }}>Enter your provider credentials. They stay on this TV and are used locally to browse and play.</p>
        <div style={{ textAlign: 'left' }}>
          <TvInput label="Username" value={username} placeholder="username" onChange={(event) => setUsername(event.currentTarget.value)} />
          <TvInput label="Password" type="password" value={password} placeholder="••••••••" onChange={(event) => setPassword(event.currentTarget.value)} />
        </div>
        {error && <div className="validation-panel" role="alert">{error}</div>}
        <div className="screen__actions screen__actions--center">
          <TvButton variant="quiet" onClick={onSettings}><Icon name="settings" size={24} /> Settings</TvButton>
          <TvButton variant="primary" disabled={loading} onClick={() => void submit()}>
            {loading ? 'Checking…' : 'Sign in'}
          </TvButton>
        </div>
      </div>
    </FocusBoundary>
  );
}
