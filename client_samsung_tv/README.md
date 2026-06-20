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

The app ships pointed at the **production MoonWatch backend** so it works out of the box:

| Setting | Default | Source |
| --- | --- | --- |
| Server Base URL | `https://moviedate.runasp.net` | Same backend the Flutter client uses |
| IPTV Base URL | `http://xc.nv2.xyz` | Pre-filled (editable) to match the Flutter app |

These defaults live in [`src/config/appConfig.ts`](src/config/appConfig.ts). The SignalR
hub URL is derived as `${serverBaseUrl}/hubs/room`, matching the server and Flutter client.

- **You do not need to enter the server URL** for normal use. On first run the app opens
  the **Sign in** screen and only asks for your **IPTV username and password**.
- The Server Base URL can still be overridden under **Settings → This TV → Advanced server
  settings** (e.g. to point at a local server). Leave it blank to fall back to the production default.

---

## How settings work

Open **Settings** from the Home screen. Fields are stored in this TV's LocalStorage
(key `moonwatch.tv.settings.v1`).

**IPTV provider (primary):**
- **IPTV Base URL** — pre-filled; change it if your provider differs
- **IPTV username** / **IPTV password** — your provider credentials
- **Test connection** — verifies the IPTV credentials and probes the room server

**This TV:**
- **Device name** (optional) — shown on Home and in watch-party rooms
- **Advanced server settings** — the Server Base URL override (defaults to production)

> IPTV credentials are stored locally in LocalStorage. Samsung TV web apps have no
> secure storage, so treat the device as you would any signed-in TV app.

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

---

## Known limitations

- **AVPlay must be validated on real Samsung hardware.** Browser dev uses the HTML5
  fallback, which does **not** prove AVPlay behavior (codecs, seeking, live streams).
- **IPTV codec/provider support varies.** Some streams or container formats may not play,
  and some providers throttle, expire, or block requests.
- **Browser playback differs from Tizen AVPlay** — treat browser results as UI testing only.
- **Live streams may report no duration** — the player shows a `LIVE` indicator and disables
  seeking in that case.
- **IPTV credentials are stored locally** in the TV's LocalStorage (no secure storage on Tizen).
- Rooms are held in server memory; a server restart closes open rooms, and host reconnect
  depends on the server preserving the SignalR session.

---

## Useful commands

```bash
npm run dev            # browser dev server (HTML5 fallback) on :3000
npm run typecheck      # TypeScript check
npm run build          # production build to dist/
npm run preview        # serve the production build
npm run package:tizen  # build (if needed) + package to dist/MoonWatchTV.wgt
```
