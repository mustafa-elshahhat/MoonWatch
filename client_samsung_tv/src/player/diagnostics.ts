/**
 * Lightweight, opt-in player diagnostics.
 *
 * Flip PLAYER_DIAGNOSTICS to `true` to surface AVPlay/HTML5 lifecycle events in
 * the console *and* an on-screen panel inside the player. Diagnostics are off by
 * default so production logs stay quiet.
 *
 * Diagnostics never print full stream URLs or IPTV credentials — only the URL
 * scheme + file extension are exposed (see {@link describeUrl}).
 */
export const PLAYER_DIAGNOSTICS: boolean = false;

/** Console logger that is a no-op unless diagnostics are enabled. */
export function diag(...args: unknown[]): void {
  if (!PLAYER_DIAGNOSTICS) return;
  // eslint-disable-next-line no-console
  console.log('[MoonWatch player]', ...args);
}

/**
 * Reduce a playback URL to a credential-safe descriptor for logs/UI, e.g.
 * "http · *.ts" or "https · *.mp4". Never returns the host, path, username,
 * password, or query string.
 */
export function describeUrl(url: string): string {
  try {
    const parsed = new URL(url);
    const scheme = parsed.protocol.replace(':', '');
    const last = parsed.pathname.split('/').filter(Boolean).pop() ?? '';
    const dot = last.lastIndexOf('.');
    const ext = dot >= 0 ? last.slice(dot + 1).toLowerCase() : '';
    return `${scheme} · ${ext ? `*.${ext}` : '(no ext)'}`;
  } catch {
    return '(unparseable url)';
  }
}
