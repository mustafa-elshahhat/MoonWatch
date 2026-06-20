# MoonWatch Backend — Deployment & Operations

Operational notes for running the `server/WatchParty.Server` (ASP.NET Core / .NET 10
SignalR) backend in production (e.g. `https://moviedate.runasp.net`). Configuration keys
live under the `WatchParty` section of `appsettings*.json` and bind to
`Configuration/WatchPartyOptions.cs`.

---

## 1. Environment

- **Always run deployed instances as `ASPNETCORE_ENVIRONMENT=Production`.** For IIS
  in-process hosting this is set in `web.config`. In Production the permissive
  development CORS policy (allow-any-origin + credentials) is **never** used (BE-009).
- Target framework is **.NET 10**; the host must support it.

On startup the server logs the active CORS posture. If it is running in Production with an
empty `Cors:AllowedOrigins`, it logs a **warning** that browser clients (the Samsung TV
app) will be blocked — treat that warning as a misconfiguration to fix.

---

## 2. CORS (required for the Samsung TV / browser client) — XP-002

The Tizen TV client is a Chromium web app and is **subject to CORS**. The native Flutter
client uses `dio`/`signalr_netcore` and is **not** CORS-bound, so it is unaffected.

Configure the browser origins that may call the REST API and negotiate SignalR:

```jsonc
// appsettings.Production.json
{
  "WatchParty": {
    "Cors": {
      // Every browser origin that must reach the API + SignalR.
      "AllowedOrigins": [ "https://your-client-app.example.com" ],
      // Access-Control-Allow-Credentials. Auto-suppressed for "*"/"null" origins.
      "AllowCredentials": true
    }
  }
}
```

**Packaged Tizen widget origin.** A packaged Tizen widget sends a *fixed* `Origin` header
(or the literal string `null`). Its exact value must be captured on hardware/emulator
against the production server, then added to `AllowedOrigins`:

- If the widget sends a concrete origin (e.g. a widget URL), add that string.
- If it sends `Origin: null`, add the literal `"null"` to `AllowedOrigins`. The server
  supports this, and **automatically disables `Allow-Credentials`** whenever a `*` or
  `null` origin is present, since credentials + wildcard/null is unsafe. The TV client uses
  no cookies, so dropping credentials for it is fine.

> Manual hardware step: from a packaged TV build pointed at production, open the Join
> screen (REST `GET /api/v1/rooms`) and create/join a room (SignalR negotiate). If either
> fails with a CORS error, add the observed `Origin` to `AllowedOrigins` until both succeed.

The API prefix (`/api/v1`) and SignalR hub path (`/hubs/room`) are unchanged.

---

## 3. In-memory rooms & single-instance constraint — BE-007

All room state lives in process memory (`InMemoryRoomRegistry`, a `ConcurrentDictionary`),
and SignalR uses no backplane. This has hard operational consequences:

- **Rooms are lost on app restart / app-pool recycle / cold start.** On free or
  idle-recycling hosting this can happen unpredictably. Configure the host to **keep the
  process warm** (disable idle shutdown) for the current single-instance model.
- **No horizontal scale-out.** A second instance would not share `_rooms` or SignalR
  groups. Running more than one instance requires a distributed store for room state **and**
  a SignalR backplane (Azure SignalR Service or Redis). That is a deliberate future change,
  not introduced here (no Redis/paid infra is added).
- **Diagnostics.** `GET /health` returns `{ status, activeRooms, version, uptimeSeconds }`.
  A drop in `uptimeSeconds` (or a `version` change) indicates a process recycle — i.e. the
  moment in-memory rooms were lost. Use it for keep-alive monitoring.

This model is acceptable for a single small instance; treat it as a known limitation when
calling the deployment "production".

---

## 4. Public room listing & privacy — BE-003 / BE-004

`GET /api/v1/rooms` powers the Samsung TV **Join Room** screen, so it is intentionally a
public endpoint. It is hardened as follows:

- **Rate limited** via the `room-list` policy (`WatchParty:RoomListRateLimit`, default
  30 requests / 60 s per IP). Exceeding it returns **429** with a `Retry-After` header.
- **Returns only safe public summaries**: room code, state, host-connected, has-guest,
  is-joinable, content-set, content type, created-at. It contains **no IPTV credentials, no
  playback URLs, and no internal latency/connection state** (the internal `hostRtt` was
  removed from the response).
- **Can be disabled in production** without removing the endpoint:

  ```jsonc
  "WatchParty": { "PublicRoomListing": { "Enabled": false } }
  ```

  When disabled, the endpoint stays available but returns an empty list, so the TV Join
  screen simply shows no discoverable rooms (code-entry join still works).

**Tradeoff.** With listing enabled, any client can enumerate active room codes and join an
open room as the guest. This is by design for "discover a room to watch with" but is a
privacy/abuse surface; disable public listing (and rely on shared codes) if that tradeoff
is unacceptable for a given deployment.

---

## 5. Room lifecycle / reconnect — BE-001 / BE-002

- **Host disconnect grace (`WatchParty:Room:HostGracePeriodSeconds`, default 30).** A host
  network blip no longer destroys the room. The server keeps the room alive, emits
  `room:host_away` to the guest, and **rebinds** the host's new SignalR connection id on
  rejoin (emitting `room:host_reconnected`). The room is closed only if the grace timer
  expires (then the guest gets `room:closed`).
- **Guest disconnect grace (`WatchParty:Room:GuestGracePeriodSeconds`, default 30).** On
  expiry the room transitions `Active → Waiting`, the state-sync timer stops, and the host
  is notified with a definitive `room:guest_left` (grace 0).

---

## 6. Configuration reference (selected)

| Key | Default | Purpose |
| --- | --- | --- |
| `Cors:AllowedOrigins` | `[]` | Browser origins allowed (REST + SignalR). Add the TV origin. |
| `Cors:AllowCredentials` | `true` | Send `Allow-Credentials` (auto-off for `*`/`null`). |
| `PublicRoomListing:Enabled` | `true` | Public `GET /api/v1/rooms` discovery on/off. |
| `Room:HostGracePeriodSeconds` | `30` | Host reconnect grace before the room closes. |
| `Room:GuestGracePeriodSeconds` | `30` | Guest reconnect grace before the slot frees. |
| `RoomListRateLimit` | `30 / 60s` | Throttle for the rooms list endpoint. |
| `RoomCreationRateLimit` | `10 / 60s` | Throttle for room creation. |
| `RoomJoinRateLimit` | `30 / 60s` | Throttle for room join. |
| `RoomStatusRateLimit` | `60 / 60s` | Throttle for room status polls. |

See [`appsettings.Production.example.json`](../server/WatchParty.Server/appsettings.Production.example.json)
for a copy-paste starting point.
