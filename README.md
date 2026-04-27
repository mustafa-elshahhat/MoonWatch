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
| Server | ASP.NET Core 10 (.NET 10), SignalR |
| Tests | xUnit (server), flutter_test / test (client) |

---

## Repository structure

```
MoonWatch/
├── client/          # Flutter app (Windows, Android)
│   ├── assets/config/   # App configuration (appsettings.local.json)
│   ├── lib/
│   │   ├── core/        # DI, config, logging, security, network, player, constants
│   │   ├── features/    # auth, iptv, player, room, sync, reconnect, navigation
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

MoonWatch uses a local configuration file for infrastructure URLs and secure storage for user credentials.

### 1. Setup Infrastructure URLs

Create a local configuration file for the Flutter client:
`client/assets/config/appsettings.local.json`

You can use the template provided:
```bash
# Windows PowerShell
Copy-Item client/assets/config/appsettings.example.json client/assets/config/appsettings.local.json

# Linux/macOS
cp client/assets/config/appsettings.example.json client/assets/config/appsettings.local.json
```

Edit `client/assets/config/appsettings.local.json`:
```json
{
  "serverBaseUrl": "https://moviedate.runasp.net",
  "iptvBaseUrl": "http://xc.nv2.xyz"
}
```

**Security Note:** `appsettings.local.json` is ignored by Git. Do not commit your real URLs.

### 2. IPTV Credentials

IPTV username and password are entered directly in the app during the first launch and are stored securely on the device using `flutter_secure_storage`.

---

## Running the server

```bash
cd server
dotnet restore WatchParty.slnx
dotnet run --project WatchParty.Server
```

The server starts on `http://localhost:5035` by default (see `Properties/launchSettings.json`).

---

## Running the Flutter client

1. Ensure `client/assets/config/appsettings.local.json` exists.
2. Run:
```bash
cd client
flutter pub get
flutter run
```

The app will prompt for your IPTV username and password on the first launch.

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

**Windows desktop / Android APK:**
```bash
cd client
flutter build windows --release
flutter build apk --release
```

Android release builds require a signing key. See the [Flutter documentation](https://docs.flutter.dev/deployment/android) and add your `key.properties` and `.jks` files locally — **never commit them**.

---

## Security notes

- **Never commit** real `appsettings.local.json`, signing keys (`.jks`, `.keystore`, `key.properties`), publish profiles (`.pubxml`), `local.properties`, or `appsettings.Production.json`.
- IPTV credentials are never logged or hardcoded.
- The `.gitignore` at the repository root is configured to exclude all of the above.
