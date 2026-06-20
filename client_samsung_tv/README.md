# MoonWatch TV (Samsung Tizen)

A Samsung Smart TV (Tizen Web App) client for **MoonWatch** — browse an Xtream-style
IPTV catalog and host or join synced watch-party rooms, all from the TV remote.

It is the TV companion to the Flutter MoonWatch app and shares the same backend,
SignalR watch-party protocol (`/hubs/room`), and visual identity (cinematic
brown-black surfaces, golden-amber accent, Inter / JetBrains Mono / Instrument
Serif type).

- Built with **React + TypeScript + Vite**
- Plays via **Samsung AVPlay** on real TVs, with an **HTML5 `<video>` fallback** for browser development
- TV-first, remote-only navigation (arrows, OK, Back, Play/Pause/FF/Rewind)

---

## Production backend (default)

The app ships pointed at the **production MoonWatch backend** so the room server works out
of the box. No IPTV provider is bundled — you supply your own on first run:

| Setting | Default | Source |
| --- | --- | --- |
| Server Base URL | `https://moviedate.runasp.net` | Same backend the Flutter client uses |
| IPTV Base URL | _(blank — you must enter your own provider)_ | Entered in Settings on first run |

These defaults live in [`src/config/appConfig.ts`](src/config/appConfig.ts). The SignalR
hub URL is derived as `${serverBaseUrl}/hubs/room`, matching the server and Flutter client.

- **You do not need to enter the server URL** for normal use. On first run the app opens
  the **Sign in** screen and asks for your **IPTV Base URL, username, and password**.
- No real IPTV provider URL is committed to this repo (it mirrors how the Flutter client
  keeps the provider out of source). Prefer an `https://` provider where available.
- The Server Base URL can still be overridden under **Settings → This TV → Advanced server
  settings** (e.g. to point at a local server). Leave it blank to fall back to the production default.

---

## How settings work

Open **Settings** from the Home screen. Fields are stored in this TV's LocalStorage
(key `moonwatch.tv.settings.v1`).

**IPTV provider (primary):**
- **IPTV Base URL** — your provider's base URL (blank by default; required before playback)
- **IPTV username** / **IPTV password** — your provider credentials
- **Test connection** — verifies the IPTV credentials and probes the room server

**This TV:**
- **Device name** (optional) — shown on Home and in watch-party rooms
- **Advanced server settings** — the Server Base URL override (defaults to production)

> **Credential storage (accepted risk — TV-003).** IPTV username/password are stored
> **unencrypted** in LocalStorage (key `moonwatch.tv.settings.v1`). Tizen Web Apps provide
> no secure keystore equivalent to the Flutter client's `flutter_secure_storage`, so this is
> an unavoidable platform limitation. **No fake/obfuscated "encryption" is applied** — that
> would only provide false assurance. Mitigations in place: credentials and full stream URLs
> are **never logged** (player diagnostics are off by default and only ever emit
> `scheme · *.ext`, see [`src/player/diagnostics.ts`](src/player/diagnostics.ts)); playback
> URLs are resolved locally and never sent over SignalR. Treat the device as you would any
> signed-in TV app. Longer term, provider auth could be proxied through the backend so the TV
> never stores credentials.

---

## Features & navigation

Everything is driven by the TV remote — arrows to move focus, **OK** to select, **Back**
to go up a level, and **Play / Pause / FF / Rewind** in the player. The focused element
always shows the golden focus ring; there is no mouse/hover dependency.

**Automatic (infinite) loading — no "Load More".**
Live TV, Movies, Series, and long episode lists render one TV-sized page (~48 items) at a
time and append the next page automatically:
- as the remote focuses near the **end of the current rows**, and
- as the bottom **sentinel** scrolls into view (mouse-wheel / page-down).

Focus stays on the item you were on (the list never jumps to the top), a subtle
`Loading more… X of Y` row shows while the next page resolves, and the toolbar shows
`Showing X of Y`. The virtual **All** category is rendered incrementally the same way, so
the focusable DOM stays small even on huge catalogs. Paging resets when you change category.
Implemented in [`src/hooks/useAutoPagedItems.ts`](src/hooks/useAutoPagedItems.ts).

**Join Room — available rooms list.**
The Join screen shows a large **room-code entry** *and* a live list of **active rooms** from
the server, so a guest can join with one click without typing a code. Each room card shows
the code, a coloured status (`Waiting for guest` / `Playing: Live·Movie·Series` / `Room is
full`), age, participant count, and host ping. The list polls every ~12s silently, supports
**manual Refresh**, and stops polling when you leave the screen. It consumes the existing
read-only **`GET /api/v1/rooms`** endpoint (the same one the Flutter client uses) — no
backend change, and it exposes only safe summary data (never IPTV credentials or playback
URLs). See [`src/room/roomApi.ts`](src/room/roomApi.ts) and
[`src/components/RoomCard.tsx`](src/components/RoomCard.tsx).

**Next Episode (series).**
In the player, series episodes show a **Next Episode** control plus an `Up next: SxxExx —
title` hint. It is hidden for Live and Movies, and disabled on the last episode. The next
episode is resolved locally from the series' episode list (rolling into the next season when
a season ends) — only the plain content descriptor crosses SignalR, never a playback URL.
- **Solo:** plays the next episode immediately.
- **Watch-party host:** sets the next episode as room content and syncs it to guests via the
  existing `SetContent` flow.
- **Guests:** the control is hidden (guests don't control room content); they receive the new
  episode automatically.

---

## Requirements

- **Node.js 20+** and **npm 10+**
- For packaging/installing on a TV or emulator: **Samsung Tizen Studio** with the **TV
  Extension** and a **Samsung certificate profile** (e.g. `moonwatch_tv_emulator`)

---

## Run in the browser (dev mode)

```bash
cd client_samsung_tv
npm install
npm run dev          # http://localhost:3000
```

Browser dev mode uses the **HTML5 `<video>` fallback** (AVPlay only exists on real Tizen
hardware). Desktop codec support varies and some IPTV providers block browser requests /
require CORS — so browser playback is for UI/flow testing, not a substitute for validating
real AVPlay on a TV.

To use a **local server** instead of production, set Server Base URL under
**Settings → Advanced server settings** (e.g. `http://192.168.1.20:5035`) and run the
backend from `../server`.

---

## Build

```bash
cd client_samsung_tv
npm run typecheck     # tsc -b --noEmit
npm run build         # tsc -b && vite build  ->  dist/
```

The Vite build copies `public/config.xml` and `public/icon.png` into `dist/` alongside the
bundled `index.html` and `assets/`.

---

## Package as a Tizen `.wgt`

The widget name in `config.xml` is **`MoonWatchTV`** (no space), so packaging produces a
**space-free** filename — `MoonWatchTV.wgt` — with **no manual rename**.

### Option A — one command (recommended)

```bash
cd client_samsung_tv
npm run build
npm run package:tizen
# -> dist/MoonWatchTV.wgt

# choose a different certificate profile:
npm run package:tizen -- --profile YOUR_PROFILE_NAME
# or:  TIZEN_PROFILE=YOUR_PROFILE_NAME npm run package:tizen
```

`package:tizen` runs `tizen package` inside `dist/` using the certificate profile
(`moonwatch_tv_emulator` by default), and guarantees the output is `dist/MoonWatchTV.wgt`.
If the Tizen CLI is not on your PATH it prints the manual steps below and exits.

### Option B — manual Tizen CLI

```bash
cd client_samsung_tv
npm run build
cd dist
tizen package -t wgt -s moonwatch_tv_emulator -- .
tizen install -n MoonWatchTV.wgt
# the produced filename has no spaces now, so no rename is needed
```

---

## Install & run on the Samsung TV Emulator

1. Open **Tizen Studio**, install a **Samsung TV** emulator image, and start the emulator.
2. Build and package (see above) — you get `dist/MoonWatchTV.wgt`.
3. Install and launch:

```bash
cd client_samsung_tv\dist
tizen install -n MoonWatchTV.wgt -t <EMULATOR_TARGET>
tizen run -p MWATCHTV01.MoonWatchTV -t <EMULATOR_TARGET>
```

> Note: the app installs cleanly only when the `.wgt` filename has no spaces — which is now
> the default. (`tizen list-target` shows your target name.)

---

## Install on a real Samsung TV

1. Enable **Developer Mode** on the TV (Apps → enter `12345`) and set the host PC IP.
2. Connect with SDB: `sdb connect <TV_IP>:26101`
3. Build, package, then:

```bash
tizen install -n MoonWatchTV.wgt -t <TV_TARGET>
tizen run -p MWATCHTV01.MoonWatchTV -t <TV_TARGET>
```

---

## Tizen configuration

`config.xml` / `public/config.xml` declare the minimum needed for a TV streaming app:

- Profile `tv-samsung`, `required_version="5.5"`
- App id `MWATCHTV01.MoonWatchTV`, package `MWATCHTV01`
- `<content src="index.html">`, `<icon src="icon.png">`
- Internet privilege (`http://tizen.org/privilege/internet`) — the only privilege
- `hwkey-event="enable"` — required for TV remote hardware keys
- Landscape orientation, `<access origin="*">`

The app icon is a lightweight 512×512 PNG (`icon.png`).

### Build target & Tizen 5.5 (TV-001)

Tizen 5.5 (2020 Samsung TVs — the declared minimum) runs ~Chromium 76, which does **not**
support optional chaining (`?.`) or nullish coalescing (`??`). The Vite build target is set
to **`chrome69`** in [`vite.config.ts`](vite.config.ts) so esbuild down-levels that syntax;
the shipped `dist/assets/*.js` therefore contains **zero** `?.`/`??` operators (verify after
a build by scanning the bundle). If you raise `required_version`, you may relax the target —
but re-scan the bundle to confirm what ships.

### `<access origin="*">` rationale (TV-010)

The widget grants `<access origin="*">` because users supply **arbitrary** IPTV provider
URLs (and an overridable room-server URL), so the set of origins the app must reach is not
known ahead of time. This is the intended, use-case-justified grant for a streaming client.
If the provider set ever becomes fixed, narrow it to those origins.

### Production CORS for the TV (XP-002)

The TV app is a Chromium web app and is therefore subject to CORS (the native Flutter client
is not). The production backend must allow the TV's web origin via
`WatchParty:Cors:AllowedOrigins`. A packaged Tizen widget sends a fixed widget `Origin` (or
the literal `null`); capture it on hardware/emulator against the production server and add it
to the allow-list. See [`../docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md).

---

## Known limitations

- **AVPlay must be validated on real Samsung hardware.** Browser dev uses the HTML5
  fallback, which does **not** prove AVPlay behavior (codecs, seeking, live streams).
- **IPTV codec/provider support varies.** Some streams or container formats may not play,
  and some providers throttle, expire, or block requests.
- **Browser playback differs from Tizen AVPlay** — treat browser results as UI testing only.
- **Live streams may report no duration** — the player shows a `LIVE` indicator and disables
  seeking in that case.
- **IPTV credentials are stored unencrypted in LocalStorage** — accepted risk (TV-003); see
  the "Credential storage" note under [How settings work](#how-settings-work).
- Rooms are held in server memory; a server restart closes open rooms. The host now has a
  reconnect **grace period** (the server keeps the room alive and rebinds the host's new
  SignalR connection), so brief host network blips no longer end the party.

---

## Useful commands

```bash
npm run dev            # browser dev server (HTML5 fallback) on :3000
npm run typecheck      # TypeScript check
npm run build          # production build to dist/
npm run preview        # serve the production build
npm run package:tizen  # build (if needed) + package to dist/MoonWatchTV.wgt
```
