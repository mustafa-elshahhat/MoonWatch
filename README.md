# The Moon / MoonWatch

A synchronized watch-party app for IPTV content. One person hosts a room, everyone else joins — and every playhead stays within milliseconds of the host's.

---

## What it does

MoonWatch lets a small group watch the same IPTV stream together in real time. The host browses their provider's catalog, picks something to watch, and shares a six-letter room code. Guests join, the server coordinates buffering and sync, and everyone sees the same frame at the same moment.

---

## Key features

- **IPTV browsing** — live TV, VOD, and series via the Xtream Codes API
- **Solo playback** — watch anything without a room
- **Watch-party rooms** — create or join a room with a six-letter code
- **Host-controlled sync** — host drives play, pause, and seek; guests follow automatically
- **Guest reconnect** — guests have a 30-second grace window to reconnect without losing the session
- **Buffering coordination** — the server holds both sides until both players signal ready, then resumes together
- **Shared protocol package** — Dart and C# definitions kept in a single canonical location

---

## Tech stack

| Layer | Technology |
|---|---|
| Client | Flutter / Dart |
| Video | media_kit |
| State | flutter_bloc |
| Networking | Dio (REST), signalr_netcore (SignalR) |
| Server | ASP.NET Core 8, SignalR |
| Tests | xUnit (server), flutter_test / test (client) |

---

## Repository structure

```
MoonWatch/
├── client/          # Flutter app (Windows, Android)
│   ├── lib/
│   │   ├── core/        # DI, logging, network, player abstraction, constants
│   │   ├── features/    # iptv, player, room, sync, reconnect, navigation
│   │   └── shared/      # shared widgets
│   └── test/
├── server/
│   ├── WatchParty.Server/   # ASP.NET Core SignalR backend
│   └── WatchParty.Tests/    # xUnit integration and unit tests
└── shared/
    ├── lib/protocol/    # Canonical Dart payload models and event constants
    └── protocol/        # C# mirror (RoomEvents.cs, Payloads.cs)
```

---

## Configuration

All secrets and environment-specific values are supplied at build time. **Nothing sensitive belongs in source control.**

| Variable | Used by | Description |
|---|---|---|
| `SERVER_BASE_URL` | Flutter client | Base URL of the WatchParty server, e.g. `http://192.168.1.10:5000` |
| `IPTV_BASE_URL` | Flutter client | Xtream Codes provider base URL |
| `IPTV_USERNAME` | Flutter client | Provider username |
| `IPTV_PASSWORD` | Flutter client | Provider password |

Pass them at build time via `--dart-define`:

```bash
flutter run \
  --dart-define=SERVER_BASE_URL=http://192.168.1.10:5000 \
  --dart-define=IPTV_BASE_URL=http://your-provider.example \
  --dart-define=IPTV_USERNAME=myuser \
  --dart-define=IPTV_PASSWORD=mypass
```

Server CORS origins are configured in `appsettings.json` (or `appsettings.Development.json` for local dev):

```json
"WatchParty": {
  "Cors": {
    "AllowedOrigins": ["http://your-client-origin"]
  }
}
```

---

## Running the server

```bash
cd server
dotnet restore WatchParty.slnx
dotnet run --project WatchParty.Server
```

The server starts on `http://localhost:5000` by default (see `Properties/launchSettings.json`).

---

## Running the Flutter client

```bash
cd client
flutter pub get
flutter run \
  --dart-define=SERVER_BASE_URL=http://localhost:5000 \
  --dart-define=IPTV_BASE_URL=http://your-provider.example \
  --dart-define=IPTV_USERNAME=myuser \
  --dart-define=IPTV_PASSWORD=mypass
```

---

## Running tests

**Server tests:**

```bash
cd server
dotnet test WatchParty.slnx -c Release
```

**Flutter client tests:**

```bash
cd client
flutter test
```

**Shared protocol tests:**

```bash
cd shared
dart pub get
dart test
```

---

## Build

**Windows desktop:**

```bash
cd client
flutter build windows --release \
  --dart-define=SERVER_BASE_URL=http://your-server \
  --dart-define=IPTV_BASE_URL=http://your-provider \
  --dart-define=IPTV_USERNAME=myuser \
  --dart-define=IPTV_PASSWORD=mypass
```

**Android APK:**

```bash
cd client
flutter build apk --release \
  --dart-define=SERVER_BASE_URL=http://your-server \
  --dart-define=IPTV_BASE_URL=http://your-provider \
  --dart-define=IPTV_USERNAME=myuser \
  --dart-define=IPTV_PASSWORD=mypass
```

Android release builds require a signing key. See the [Flutter documentation](https://docs.flutter.dev/deployment/android) and add your `key.properties` and `.jks` files locally — **never commit them**.

---

## Security notes

- **Never commit** IPTV credentials, signing keys (`.jks`, `.keystore`, `key.properties`), publish profiles (`.pubxml`), `local.properties`, or `appsettings.Production.json`.
- All sensitive values belong in environment variables or build-time `--dart-define` flags.
- The `.gitignore` at the repository root is configured to exclude all of the above.
- If any credentials were present in earlier commits, rotate them.
