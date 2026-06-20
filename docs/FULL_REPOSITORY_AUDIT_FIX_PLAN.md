# MoonWatch Full Repository Audit & Fix Plan

> Read-only audit. No production code was modified, no behaviour changed, nothing was
> committed. The only artifact created is this document.
> Repository: `D:\projects\MoonWatch` — https://github.com/mustafa-elshahhat/MoonWatch
> Branch audited: `main` @ `ff0862f` (clean working tree). Date: 2026-06-20.

---

## 1. Executive Summary

MoonWatch is a three-part IPTV watch-party product:

| Project | Stack | Maturity |
| --- | --- | --- |
| `server/` | ASP.NET Core (.NET 10) SignalR + REST, in-memory rooms | **Solid.** Clean build (0 warnings), 86 tests passing, well-layered. |
| `client/` | Flutter (Android/Windows/…), `media_kit`, BLoC | **Most mature.** `flutter analyze` clean, large unit/widget/integration suite. |
| `client_samsung_tv/` | React 19 + Vite + TS, Tizen Web App, AVPlay | **Newest / least hardened.** Builds & typechecks, but no tests, not in CI, and has a likely TV-runtime blocker. |
| `shared/` | C#/Dart protocol + TS mirror in TV project | Consistent today, but the TS copy is unguarded against drift. |

**Overall production-readiness:** **Staging-ready.** The backend and Flutter client are close to
production. The Samsung TV client is functional and well-architected but carries at least one
likely-blocking runtime bug (`TV-001`, ES2020 syntax on Tizen 5.5) and one likely-blocking
deployment issue (`XP-002`, production CORS vs. the browser-based TV) that must be cleared on real
hardware before it can be called production-ready.

**Highest-risk areas**

1. **Tizen runtime compatibility (`TV-001`)** — the shipped bundle contains 108 optional-chaining
   and 45 nullish-coalescing operators; `config.xml` targets Tizen 5.5 (≈Chromium 76, which lacks
   both). High chance of a white screen on 2020/2021 Samsung TVs.
2. **Host reconnection / room lifecycle (`BE-001` / `XP-001`)** — the server closes a room
   *immediately* when the host's connection drops (no grace period). With SignalR auto-reconnect
   cycling the connection id, any host network blip permanently ends the party for both users.
3. **Production CORS vs. the TV (`XP-002`)** — the Tizen client is browser-based and subject to
   CORS; the production config ships with an empty allow-list, which will block the TV's REST
   poll and SignalR negotiate.
4. **Public room enumeration (`BE-003` / `BE-004`)** — `GET /api/v1/rooms` is unauthenticated and
   un-rate-limited; any client can enumerate and join active rooms.
5. **TV credential storage & hardcoded provider (`TV-003` / `TV-004`)** — IPTV credentials in
   plaintext `localStorage`; a real third-party provider domain hardcoded (over HTTP) as the
   shipped default.

**Summary counts**

| Severity | Count |
| --- | --- |
| Critical | 1 |
| High | 3 |
| Medium | 11 |
| Low | 13 |
| Nice-to-have | 1 |
| **Total** | **29** |

| Project | Count |
| --- | --- |
| Backend (BE) | 9 |
| Flutter (FL) | 3 |
| Samsung TV (TV) | 11 |
| Shared protocol (SP) | 2 |
| Cross-project (XP) | 4 |

---

## 2. Audit Scope

- **Backend** (`server/WatchParty.Server`, `server/WatchParty.Tests`): `Program.cs`, `RoomHub`,
  `RoomService`, `InMemoryRoomRegistry`, `RoomExpiryService`, `StateSyncTimerService`,
  `RoomsController`, `RoomCodeGenerator`, options, middleware, health check, all config files,
  `web.config`, `launchSettings.json`.
- **Flutter client** (`client/`): config loading, DI, SignalR/HTTP clients, logging/sanitization,
  credential store, IPTV service + URL builder, room repository, sync engine, reconnect bloc,
  constants, `pubspec.yaml`.
- **Samsung TV client** (`client_samsung_tv/`): `App.tsx`, settings/appConfig, IPTV service, room
  client + room API, AVPlay/HTML5 players + factory, paging hooks, Browse/Series/Join/Player
  screens, remote navigation, diagnostics, `config.xml`, `package.json`, `vite.config.ts`,
  `scripts/package-tizen.mjs`, README, built `dist/` bundle.
- **Shared protocol** (`shared/` + `client_samsung_tv/src/protocol/`): event names, hub method
  names, payload shapes, content descriptor — across C#, Dart, and TypeScript.
- **Cross-project compatibility**: base URL, `/api/v1` prefix, `/hubs/room` path, room states,
  room-code format, host/guest permissions, reconnect & buffering/readiness semantics,
  next-episode, active-rooms behaviour, local playback-URL resolution.

---

## 3. Commands Executed

| Project | Command | Result | Notes |
| --- | --- | --- | --- |
| Backend | `dotnet --version` | **10.0.203** | SDK present. |
| Backend | `dotnet build server/WatchParty.slnx -c Debug` | ✅ **Pass** | `Build succeeded. 0 Warning(s), 0 Error(s)`. |
| Backend | `dotnet test WatchParty.Tests.csproj --tl:off --filter "Category!=Performance&Category!=Benchmark"` | ✅ **Pass** | `Passed! Failed: 0, Passed: 86, Skipped: 0`. |
| TV | `npm install` | ✅ **Pass** | 91 packages, `1 low severity vulnerability`. |
| TV | `npm run typecheck` (`tsc -b --noEmit`) | ✅ **Pass** | No type errors. |
| TV | `npm run build` (`tsc -b && vite build`) | ✅ **Pass** | `dist/assets/index-*.js` = 322 KB (95.8 KB gzip). |
| TV | `npm audit` | ⚠️ **1 low** | esbuild dev-server advisory `GHSA-g7r4-m6w7-qqqr` (dev/Windows only). |
| TV | bundle syntax scan (`dist/assets/index-*.js`) | ⚠️ **Finding** | 108 `?.`, 45 `??` present in shipped output (see `TV-001`). |
| TV | `npm run package:tizen` | ⏭️ **Skipped** | Tizen CLI not on PATH — cannot produce/validate the `.wgt` here (see Testing Gaps). |
| Flutter | `flutter pub get` | ✅ **Pass** | `Got dependencies!` (59 transitive deps have newer incompatible versions — informational). |
| Flutter | `flutter analyze` | ✅ **Pass** | `No issues found! (ran in 19.0s)`. |
| Flutter | `flutter test` | ⏭️ **Not run here** | Run in CI (`ci.yml`). Large suite present under `client/test/`. |
| Shared | `dart analyze` / `dart test` | ⏭️ **Not run here** | Run in CI (`ci.yml`). |
| Icons | `System.Drawing` dimension probe | ℹ️ Info | TV `icon.png` = 512×512 (10.5 KB) ✅; Flutter `assets/icon.png` = 1024×1024 (**1.6 MB**, see `FL-002`). |

**Environment:** Windows 11, Node v24.15.0, npm 11.13.0, Flutter at `C:\flutter`, Tizen CLI **not
installed**.

---

## 4. Severity Matrix

| Severity | IDs | Count |
| --- | --- | --- |
| **Critical** | TV-001 | 1 |
| **High** | BE-001, XP-001, XP-002 | 3 |
| **Medium** | BE-002, BE-003, BE-004, BE-007, TV-002, TV-003, TV-004, TV-005, TV-008, SP-002, XP-003 | 11 |
| **Low** | BE-005, BE-006, BE-009, FL-001, FL-002, FL-003, TV-006, TV-007, TV-009, TV-010, TV-011, SP-003, XP-004 | 13 |
| **Nice-to-have** | BE-008 | 1 |

---

## 5. Issues by Project

### 5.1 Backend Issues

---

#### BE-001 — Host disconnect closes the room immediately (no grace period)
- **Severity:** High
- **Category:** Room lifecycle / reconnect / watch-party reliability
- **Files:** `server/WatchParty.Server/Services/RoomService.cs:205-212` (`HandleDisconnected` → host branch → `CloseRoom`); `server/WatchParty.Server/Hubs/RoomHub.cs:528-572` (`OnDisconnectedAsync`).
- **Problem:** When the host's SignalR connection drops, `HandleDisconnected` calls `CloseRoom(...)`, which sets `RoomState.Closed`, unregisters both connections, and `_registry.TryRemove(room.RoomCode)`. The guest gets exactly **30 s** of grace (`StartGuestGracePeriod`), but the host gets **none** — the room is destroyed instantly.
- **Evidence:** `RoomService.cs:205` `if (room.Host?.ConnectionId == connectionId) { var leave = CloseRoom(room, "host_disconnected", "host"); ... }`. Contrast with the guest path `HandleGuestDisconnect` → `StartGuestGracePeriod` (`RoomService.cs:230-297`).
- **Impact:** SignalR `withAutomaticReconnect` (both clients) establishes a *new* connection id on reconnect, which the server cannot map back to the old host slot — and the room is already gone. A transient host network blip (Wi-Fi roam, suspend, mobile handover) **permanently ends the watch party** and kicks the guest with `room:closed`. This is the root cause behind `XP-001`.
- **Recommended fix:** Introduce a host grace period symmetric to the guest's: on host disconnect, mark the host "away", keep the room alive for N seconds, emit a `room:host_away` (or reuse a pause), and let a re-invoked `JoinRoom(code,"host")` rebind the *new* connection id to the existing host slot instead of throwing `RoomFullException`. Only `CloseRoom` if the grace timer expires. Update `HandleHostJoin` to allow rebinding when `room.HostAway`.
- **Estimated effort:** M (server logic + new state flag + tests). 0.5–1 day.
- **Dependencies/blockers:** Client rejoin code already exists (`ReconnectBloc`, `rejoinAfterReconnect`); they must stop treating host rejoin as fatal once the server supports it.
- **Verification:** Host a room, start playback, kill the host's network for <N s, restore. Expect the room to survive and the guest to stay connected. Add a server test mirroring `HandleGuestDisconnect` grace tests.

---

#### BE-002 — Guest grace expiry leaves the room `Active` with no guest and no notification
- **Severity:** Medium
- **Category:** Room lifecycle / state-management
- **Files:** `server/WatchParty.Server/Services/RoomService.cs:251-280` (`StartGuestGracePeriod` expiry task).
- **Problem:** When the 30 s guest grace expires, the task sets `room.Guest = null; room.GuestAway = false;` but does **not** transition the room out of `RoomState.Active`, and emits no event to the host. The host already received `room:guest_left` (with grace seconds) at disconnect time; after expiry it gets nothing further.
- **Evidence:** `RoomService.cs:259-266` clears the guest but never touches `room.State`; only `StartGuestGracePeriod`'s *entry* downgrades `Joined → Waiting` (`:242-245`), not `Active → Waiting`.
- **Impact:** A room can sit in `Active` with one participant indefinitely (until expiry sweep). `StateSyncTimerService` keeps emitting `playback:state_sync` to a group with only the host. Host UI may continue showing "guest away" rather than "guest left for good." Minor, but it muddies room state and wastes broadcasts.
- **Recommended fix:** On grace expiry, transition `Active → Waiting`, stop the state-sync timer for the room if no guest remains, and optionally emit a definitive `room:guest_left` (grace 0) so the host UI settles.
- **Estimated effort:** S. ~1–2 h.
- **Dependencies/blockers:** None.
- **Verification:** Guest disconnect → wait > grace → assert `room.State == Waiting`, no further state-sync broadcasts, host UI updates.

---

#### BE-003 — `GET /api/v1/rooms` has no rate limiting
- **Severity:** Medium
- **Category:** Security / API / DoS surface
- **Files:** `server/WatchParty.Server/Controllers/RoomsController.cs:124-146` (`ListRooms`).
- **Problem:** `CreateRoom`, `JoinRoom`, and `GetStatus` carry `[EnableRateLimiting(...)]`; `ListRooms` does not. Both clients poll it (TV every 12 s — `JoinRoomScreen.tsx:13,53`; Flutter via `room_list_bloc`).
- **Evidence:** Compare `RoomsController.cs:27` (`[EnableRateLimiting("room-creation")]`) with `:124 [HttpGet]` — no attribute.
- **Impact:** Unauthenticated callers can scrape the full active-room list at any rate, enabling cheap enumeration (feeds `BE-004`) and an un-throttled load path.
- **Recommended fix:** Add `[EnableRateLimiting("room-status")]` (or a dedicated `room-list` policy) to `ListRooms`.
- **Estimated effort:** XS. ~10 min + 1 test.
- **Dependencies/blockers:** None.
- **Verification:** Hammer `GET /api/v1/rooms` past the window limit → expect 429 with `Retry-After`.

---

#### BE-004 — Active rooms are publicly enumerable and joinable (no per-room access control)
- **Severity:** Medium
- **Category:** Security / privacy / authorization
- **Files:** `RoomsController.cs:124-146` (`ListRooms`) + `:54-93` (`JoinRoom`); Hub `JoinRoom` (`RoomHub.cs:56`).
- **Problem:** `ListRooms` returns every non-closed room's `roomCode` and joinability with no authentication; `JoinRoom` accepts any valid code as a guest with no secret beyond the (now publicly listed) code. There is no auth layer anywhere in the app.
- **Evidence:** `RoomsController.cs:131-142` selects and returns `roomCode` for all rooms; no `[Authorize]` anywhere in the project (no auth is configured in `Program.cs`).
- **Impact:** Any internet client pointed at the production server can list active rooms and join a stranger's watch party as the guest; the host cannot prevent it. For a "watch with friends" product this is a privacy/abuse gap. (Listing is partly *intentional* — the Join screen advertises rooms — so this is also a product decision, flagged here so it is a conscious one.)
- **Recommended fix (options):** (a) Keep public listing but gate it (e.g. only rooms whose host opted into "discoverable"); (b) require the code AND a short host-issued PIN for join; (c) add minimal auth/token. At minimum, fix `BE-003` so enumeration is throttled. **Needs product decision.**
- **Estimated effort:** M–L depending on option chosen.
- **Dependencies/blockers:** Product owner decision (see Open Questions).
- **Verification:** Confirm a non-listed/private room cannot be joined by a third party.

---

#### BE-007 — In-memory rooms: lost on restart, no scale-out backplane
- **Severity:** Medium
- **Category:** Production config / deployment / scalability
- **Files:** `server/WatchParty.Server/Services/InMemoryRoomRegistry.cs` (`ConcurrentDictionary`); `Program.cs:61-62` (singletons); deploy target `https://moviedate.runasp.net` (free ASP.NET hosting).
- **Problem:** All room state lives in process memory. On app-pool recycle / cold start (common on free shared hosting like runasp.net) every open room is destroyed. There is also no SignalR backplane (Redis/Azure SignalR), so the app cannot run more than one instance — a second instance would not share `_rooms` or SignalR groups.
- **Evidence:** `InMemoryRoomRegistry` + no distributed cache / backplane registration in `Program.cs`; README (TV) §"Known limitations" acknowledges "Rooms are held in server memory."
- **Impact:** Rooms vanish unpredictably in production; horizontal scaling is impossible without code changes. Acceptable for a single small instance; risky as "production."
- **Recommended fix:** Document the single-instance constraint explicitly; for scale, add a backplane (Azure SignalR Service or Redis) and move room state to a distributed store. Verify the host plan keeps the process warm (disable idle shutdown) for the current single-instance model.
- **Estimated effort:** S to document; L to make horizontally scalable.
- **Dependencies/blockers:** Hosting choice.
- **Verification:** Recycle the app pool mid-room and observe room loss; confirm hosting keep-alive settings.

---

#### BE-005 — `PlaybackRate` read outside the room lock in the state-sync timer
- **Severity:** Low
- **Category:** Concurrency / race condition
- **Files:** `server/WatchParty.Server/Services/StateSyncTimerService.cs:101-137`.
- **Problem:** The method snapshots position/seq/timestamp *inside* `room.Lock` (`:101-124`) but then reads `room.PlaybackRate` *after* the lock is released, in the `SendAsync` payload (`:137`).
- **Evidence:** `:137` `room.PlaybackRate` is referenced after `room.Lock.Release()` at `:123`.
- **Impact:** Benign in practice (a `double` read), but it is an unsynchronized read of mutable room state and could momentarily mismatch the snapshotted `estimatedPositionMs` if speed changes mid-emit.
- **Recommended fix:** Capture `var playbackRate = room.PlaybackRate;` inside the lock and use the local in the payload.
- **Estimated effort:** XS.
- **Dependencies/blockers:** None.
- **Verification:** Code review; no behaviour change expected.

---

#### BE-006 — Empty `catch { }` around startup log-file reset
- **Severity:** Low
- **Category:** Exception handling
- **Files:** `server/WatchParty.Server/Program.cs:15-20`.
- **Problem:** `try { Directory.CreateDirectory(...); File.Delete(...) } catch { }` silently swallows every exception (incl. `IOException`, permission errors) before the logger exists.
- **Evidence:** `Program.cs:20` `catch {  }`.
- **Impact:** Minimal — it only guards a best-effort log reset before logging is up. But a fully empty catch hides genuine filesystem/permission problems (e.g. read-only log dir in production) with zero signal.
- **Recommended fix:** Narrow to `catch (Exception)` and write to `Console.Error` so a misconfigured log path is at least visible at boot.
- **Estimated effort:** XS.
- **Dependencies/blockers:** None.
- **Verification:** Point logs at a read-only path; confirm a diagnostic line appears.

---

#### BE-009 — Development CORS allows any origin with credentials
- **Severity:** Low
- **Category:** Security posture (dev only)
- **Files:** `server/WatchParty.Server/Program.cs:94-100`.
- **Problem:** In non-production, the policy is `SetIsOriginAllowed(_ => true).AllowAnyHeader().AllowAnyMethod().AllowCredentials()`.
- **Evidence:** `Program.cs:96-99`.
- **Impact:** Dev-only and gated on `!IsProduction()`, so low risk. Worth noting because "allow all origins + credentials" is the kind of policy that occasionally leaks into prod via a misconfigured environment.
- **Recommended fix:** Keep, but ensure the production path (explicit origins) is always taken in deployed environments and add a startup assertion/log if `IsProduction()` is false on the public host.
- **Estimated effort:** XS.
- **Dependencies/blockers:** None.
- **Verification:** Confirm `ASPNETCORE_ENVIRONMENT=Production` on the deployed host (`web.config:13` sets it for IIS in-process).

---

#### BE-008 — Room-code generator gives up after 3 collisions
- **Severity:** Nice-to-have
- **Category:** Robustness
- **Files:** `server/WatchParty.Server/Services/RoomCodeGenerator.cs:19,27-38`.
- **Problem:** `MaxCollisionRetries = 3`; on 3 collisions it throws and the controller returns 503.
- **Evidence:** `RoomCodeGenerator.cs:29-37`.
- **Impact:** None at realistic scale (32^6 ≈ 1.07 B codes). Only matters at very high concurrent-room counts, which the in-memory model wouldn't reach anyway.
- **Recommended fix:** Bump retries to ~5–8, or lengthen the code if room volume ever grows.
- **Estimated effort:** XS.
- **Dependencies/blockers:** None.
- **Verification:** N/A (defensive).

---

### 5.2 Flutter Client Issues

---

#### FL-001 — Room-server HTTP logging is not sanitized (inconsistent with IPTV logging)
- **Severity:** Low
- **Category:** Logging / security hygiene
- **Files:** `client/lib/core/network/http_client.dart:31,36,42`.
- **Problem:** The `HttpClient` interceptor logs `options.uri` / `requestOptions.uri` verbatim, whereas `IptvApiService` runs every URL through `AppLogger.sanitizeUrl` (`iptv_api_service.dart:48-57,62-64`).
- **Evidence:** `http_client.dart:31` `_logger.d('HTTP ${options.method} ${options.uri}')` — no sanitizer.
- **Impact:** Low — these are room-server URLs (`/api/v1/rooms/{code}/...`) containing only room codes, not credentials. Still, it is an inconsistency and room codes are semi-sensitive (see `BE-004`).
- **Recommended fix:** Route these through `AppLogger.sanitizeUrl(...)` for consistency, or at least redact the room code segment.
- **Estimated effort:** XS.
- **Dependencies/blockers:** None.
- **Verification:** Trigger a room call; inspect the client log file (`Watch Party Logs/log.txt`).

---

#### FL-002 — Oversized 1.6 MB runtime icon asset bundled
- **Severity:** Low
- **Category:** Performance / bundle size
- **Files:** `client/pubspec.yaml:52` (`assets/icon.png`), `client/assets/icon.png` (1024×1024, **1.6 MB**).
- **Problem:** The full-resolution 1024×1024 PNG is both the `flutter_launcher_icons` source *and* a runtime asset. As a runtime asset it is large for what is almost certainly displayed much smaller.
- **Evidence:** `System.Drawing` probe: `client/assets/icon.png => 1024x1024, 1644211 bytes`.
- **Impact:** Adds ~1.6 MB to the app bundle and memory when decoded; minor on modern phones, more noticeable on low-end/older devices.
- **Recommended fix:** Keep a high-res copy only for launcher-icon generation; ship a compressed/optimized (or appropriately sized) runtime asset. Re-encode the PNG (it is likely far heavier than necessary).
- **Estimated effort:** S.
- **Dependencies/blockers:** None.
- **Verification:** Compare bundle size before/after; confirm UI still crisp.

---

#### FL-003 — `signalr_netcore` community dependency + host-reconnect interplay
- **Severity:** Low
- **Category:** Dependency risk / reconnect
- **Files:** `client/pubspec.yaml:22` (`signalr_netcore: ^1.3.0`); `client/lib/core/network/signalr_client.dart`; `client/lib/features/reconnect/reconnect_bloc.dart`.
- **Problem:** `signalr_netcore` is a third-party, comparatively low-traffic package implementing the SignalR protocol for Dart. The reconnect logic (app-layer rejoin) leans on its `withAutomaticReconnect` behaviour, which is the weak point exploited by `XP-001`/`BE-001`.
- **Evidence:** `pubspec.yaml:22`; `signalr_client.dart:31` `withAutomaticReconnect(...)`; `reconnect_bloc.dart:117-122` treats `room_not_found`/`room_full` as fatal (which is exactly what host rejoin currently returns).
- **Impact:** Maintenance/compatibility risk if the package lags behind .NET 10 SignalR; reconnect correctness depends on it.
- **Recommended fix:** Pin/track the dependency; add an integration test that exercises a real reconnect against a running server; revisit once `BE-001` lands so host rejoin is no longer "fatal."
- **Estimated effort:** S (tracking) / M (reconnect test).
- **Dependencies/blockers:** `BE-001`.
- **Verification:** Reconnect integration test green against the live hub.

---

### 5.3 Samsung TV/Tizen Issues

---

#### TV-001 — Vite `build.target: 'es2020'` ships syntax unsupported by Tizen 5.5 (likely white screen)
- **Severity:** Critical
- **Category:** Tizen runtime compatibility / build config
- **Files:** `client_samsung_tv/vite.config.ts:15-19` (`target: 'es2020'`); `client_samsung_tv/config.xml:7` (`required_version="5.5"`); confirmed in `dist/assets/index-*.js`.
- **Problem:** Samsung TVs on **Tizen 5.5** (2020 models — the declared minimum) run roughly **Chromium 76**, which does **not** support optional chaining (`?.`) or nullish coalescing (`??`) — those require Chromium 80. With `build.target: 'es2020'`, esbuild **does not down-level** these operators, so they remain in the shipped bundle. A parse-time `SyntaxError` on the main bundle means the app fails to start (blank screen) on those TVs.
- **Evidence:** Bundle scan of the just-built `dist/assets/index-Xd0FrMSV.js`: **108** occurrences of `?.` and **45** of `??`. `vite.config.ts:16` `target: 'es2020'`. `config.xml:7` `required_version="5.5"`.
- **Impact:** Potentially total failure on a large class of target devices (2020/2021 Samsung TVs). The product README explicitly markets Tizen 5.5 support.
- **Recommended fix:** Lower the build target so esbuild transpiles modern syntax, e.g. `build.target: ['chrome69']` (or `'es2019'` / `'safari11'`), and verify the rebuilt bundle no longer contains `?.`/`??`. Consider raising `required_version` only if you genuinely intend to drop 2020 TVs.
- **Estimated effort:** XS to change; M to validate on emulator/hardware across firmware levels.
- **Dependencies/blockers:** **Needs verification** of the exact lowest target TV's Chromium version (Tizen 5.5 ≈ m76 is well-established) — but lowering the target is a zero-risk change regardless.
- **Verification:** Rebuild; re-scan `dist/assets/*.js` for `?.`/`??` (expect 0); install the `.wgt` on a Tizen 5.5 emulator and confirm the app renders.

---

#### TV-002 — No React error boundary; any render error white-screens the whole app
- **Severity:** Medium
- **Category:** Reliability / UX
- **Files:** `client_samsung_tv/src/main.tsx:12-16`; `client_samsung_tv/src/App.tsx:304-352`.
- **Problem:** `main.tsx` renders `<App/>` with no error boundary. `App.tsx` wraps the screen-selection in a `try/catch` (`:305,349`), but that only catches errors thrown while *creating* the element object — it does **not** catch errors thrown during a child component's render/commit (React surfaces those to an error boundary, which doesn't exist).
- **Evidence:** `App.tsx:349` `} catch (error) { return <ErrorDisconnectedScreen .../> }` wrapping JSX literals; no `componentDidCatch`/`ErrorBoundary` anywhere; `main.tsx` has no wrapper.
- **Impact:** A render exception in any screen (e.g. malformed IPTV payload reaching a component) crashes the entire TV app to a blank screen with no recovery path on a device with no dev tools.
- **Recommended fix:** Add a class-based `ErrorBoundary` around `<App/>` (or around the `body` switch) that renders `ErrorDisconnectedScreen` and offers "Home"/reload.
- **Estimated effort:** S.
- **Dependencies/blockers:** None.
- **Verification:** Throw inside a screen render in dev; confirm the boundary catches it instead of blanking.

---

#### TV-003 — IPTV credentials stored in plaintext `localStorage`
- **Severity:** Medium
- **Category:** Security / insecure storage
- **Files:** `client_samsung_tv/src/settings/settings.ts:51-55` (`saveSettings` → `localStorage.setItem`); README §"How settings work".
- **Problem:** Username and password are persisted unencrypted under `moonwatch.tv.settings.v1`. The Flutter client uses `flutter_secure_storage` (`client/lib/core/security/credential_store.dart`).
- **Evidence:** `settings.ts:53` `window.localStorage.setItem(SETTINGS_KEY, JSON.stringify(sanitized))` where `sanitized.iptvPassword` is the raw password.
- **Impact:** Any code running in the app's web context (or anyone with device/file access) can read the IPTV password. Tizen offers no secure keystore for web apps, so this is partly unavoidable — but it should be a conscious, documented risk (README does note it).
- **Recommended fix:** Acknowledge as accepted risk in docs; if feasible, scope credentials to memory + re-prompt, or use a lightweight obfuscation at rest (not real security). Long term, consider proxying IPTV auth through the backend so the TV never stores provider credentials.
- **Estimated effort:** S (doc) / L (backend proxy).
- **Dependencies/blockers:** Product decision.
- **Verification:** Inspect `localStorage` on the device; confirm what is stored.

---

#### TV-004 — Real third-party IPTV provider hardcoded (over HTTP) as the shipped default
- **Severity:** Medium
- **Category:** Config / security / data hygiene
- **Files:** `client_samsung_tv/src/config/appConfig.ts:18-21`; README §"Production backend (default)".
- **Problem:** `DEFAULT_IPTV_BASE_URL = 'http://xc.nv2.xyz'` bakes a **real** IPTV provider domain into source, over **cleartext HTTP**, committed to a public repo. The Flutter client deliberately keeps the provider URL out of source (gitignored `appsettings.local.json`, placeholder in `appsettings.example.json`).
- **Evidence:** `appConfig.ts:21`; `.gitignore:124` shows Flutter's `appsettings.local.json` is excluded, while the TV default is committed in `appConfig.ts` and documented in the README table.
- **Impact:** Publishes a specific provider endpoint; HTTP exposes all IPTV traffic (incl. credentials in path/query) to network observers. Also couples the open-source repo to one provider.
- **Recommended fix:** Default to a neutral placeholder (mirroring `appsettings.example.json`) or leave blank and force entry on first run; require HTTPS where the provider supports it. Keep `PRODUCTION_SERVER_BASE_URL` (your own backend) if desired, but de-hardcode the provider.
- **Estimated effort:** XS.
- **Dependencies/blockers:** Product decision on default behaviour.
- **Verification:** Fresh install shows no real provider preset; user must enter their own.

---

#### TV-005 — Spatial navigation forces a full reflow on every arrow keypress
- **Severity:** Medium
- **Category:** Performance / TV remote UX
- **Files:** `client_samsung_tv/src/navigation/remote.ts:145-178` (`moveFocus` → `getFocusable`).
- **Problem:** Each arrow press calls `getFocusable(document)`, which `querySelectorAll('[data-tv-focusable="true"]')` across the whole document and then calls `getBoundingClientRect()` **and** `getComputedStyle()` on every candidate, plus another `getBoundingClientRect()` per candidate in `moveFocus`.
- **Evidence:** `remote.ts:170-177` (rect + computed style per element) called from `:157-162` for all focusables.
- **Impact:** On a Browse/Series page with ~48 cards + nav (~50–60 focusables), every D-pad press triggers dozens of synchronous layout reads — a forced reflow per keypress. On low-powered TV SoCs this manifests as sluggish, laggy focus movement.
- **Recommended fix:** Cache the focusable list per screen and invalidate on DOM changes (MutationObserver or React-driven), or scope the query to the current `FocusBoundary` container; batch rect reads. Avoid `getComputedStyle` in the hot path (rely on `offsetParent`/rect for visibility).
- **Estimated effort:** M.
- **Dependencies/blockers:** None.
- **Verification:** Profile arrow navigation on the largest catalog page on emulator/hardware; confirm reduced scripting/layout time per keypress.

---

#### TV-006 — Remote handlers re-registered on every App render
- **Severity:** Low
- **Category:** Performance / correctness
- **Files:** `client_samsung_tv/src/App.tsx:296-302`; `client_samsung_tv/src/navigation/remote.ts:28-83` (`useRemoteNavigation`, effect deps `[handlers]`).
- **Problem:** `App` passes a fresh object literal to `useRemoteNavigation({...})` each render, so the effect's `[handlers]` dependency changes every render. The `keydown` listener is removed/re-added and `registerTizenRemoteKeys()` re-runs on every render.
- **Evidence:** `App.tsx:296` inline object; `remote.ts:82` `}, [handlers]);`.
- **Impact:** Wasteful; a keypress landing in the brief teardown/re-add window could be missed. Tizen key re-registration is best-effort but repeated needlessly.
- **Recommended fix:** Memoize the handlers object (`useMemo`) or keep handlers in a ref and depend on `[]`; register Tizen keys once on mount.
- **Estimated effort:** S.
- **Dependencies/blockers:** None.
- **Verification:** Add a log in the effect; confirm it runs once per mount, not per render.

---

#### TV-007 — No auto-advance to the next episode when playback ends
- **Severity:** Low
- **Category:** UX / next-episode flow
- **Files:** `client_samsung_tv/src/screens/PlayerScreen.tsx:250-252,479-484,94-96`.
- **Problem:** `onEnded` sets `status='ended'` and shows only a "Back to catalog" button. Even when a next episode exists (`nextEp`), it is not auto-played; the user must have used the manual "Next" control earlier.
- **Evidence:** `PlayerScreen.tsx:479-484` (ended overlay, no "Next"); `:252` `onEnded: () => setStatus('ended')`.
- **Impact:** Binge-watching friction — series don't roll to the next episode automatically; the "ended" screen also doesn't surface the available next episode.
- **Recommended fix:** On `ended`, if `nextEp` exists and `canControl`, either auto-advance (`playNext()`) after a short countdown or render a prominent "Play next: SxxExx" button in the ended overlay.
- **Estimated effort:** S.
- **Dependencies/blockers:** None.
- **Verification:** Play the last seconds of an episode; confirm next-episode prompt/auto-advance.

---

#### TV-008 — TV client has no tests and is excluded from CI (and no ESLint configured)
- **Severity:** Medium
- **Category:** Testing / developer experience
- **Files:** `.github/workflows/ci.yml` (server + Flutter + shared only); `client_samsung_tv/` (no test files); `client_samsung_tv/package.json` (no `test`/`lint` scripts, no eslint dep); `src/player/diagnostics.ts:16` (`// eslint-disable-next-line` with no ESLint present).
- **Problem:** `ci.yml` never runs `npm install`/`typecheck`/`build`/`audit` for the TV client, so type/build regressions land unnoticed. There are zero automated tests for the TV's sync command handling, paging, settings, episode logic, etc. An `eslint-disable` comment exists but ESLint is not installed/configured (dead directive).
- **Evidence:** `ci.yml:1-58` (no TV job); `git ls-files` shows no `client_samsung_tv/**/*test*`; `package.json:6-12` scripts lack `lint`/`test`.
- **Impact:** The least-mature client is the least-verified. Protocol/command-handling bugs (e.g. `XP-003`) would not be caught by CI.
- **Recommended fix:** Add a CI job: `npm ci && npm run typecheck && npm run build && npm audit --audit-level=high`. Add Vitest + tests for `settings`, `episodeContext.nextEpisode`, `iptvService` URL builders, and the `PlayerScreen` command reducer. Add ESLint (or remove the dead directive).
- **Estimated effort:** M.
- **Dependencies/blockers:** None.
- **Verification:** CI runs the TV job; tests execute and pass.

---

#### TV-009 — esbuild dev-server advisory (transitive via Vite)
- **Severity:** Low
- **Category:** Dependency vulnerability (dev-only)
- **Files:** `client_samsung_tv/package-lock.json` (vite → esbuild).
- **Problem:** `npm audit` reports `esbuild 0.27.3–0.28.0` — `GHSA-g7r4-m6w7-qqqr` (arbitrary file read via the dev server on Windows). Affects `vite`/`vite preview` only, **not** the shipped Tizen bundle.
- **Evidence:** `npm audit` output: "1 low severity vulnerability … esbuild … fix available via `npm audit fix`."
- **Impact:** Low; dev-time only and Windows-specific. No exposure in the packaged app.
- **Recommended fix:** `npm audit fix` (or bump Vite) at a convenient time; keep dev servers bound to localhost when possible.
- **Estimated effort:** XS.
- **Dependencies/blockers:** None.
- **Verification:** `npm audit` reports 0 after the fix.

---

#### TV-010 — `config.xml` grants `<access origin="*"/>`
- **Severity:** Low
- **Category:** Security posture (Tizen)
- **Files:** `client_samsung_tv/config.xml:14`.
- **Problem:** The widget can reach any origin. Necessary because IPTV/base URLs are user-configurable, but `*` is the broadest possible grant.
- **Evidence:** `config.xml:14` `<access origin="*" />`.
- **Impact:** Low for a streaming client that must contact arbitrary user-supplied providers; still worth a conscious note (a compromised/embedded resource could exfiltrate anywhere).
- **Recommended fix:** Acceptable as-is given the use case; document the rationale. If the provider set is ever fixed, narrow it.
- **Estimated effort:** XS (doc).
- **Dependencies/blockers:** None.
- **Verification:** N/A.

---

#### TV-011 — "Ended"/overlay states can render on top of the player chrome
- **Severity:** Low
- **Category:** UI/UX
- **Files:** `client_samsung_tv/src/screens/PlayerScreen.tsx:434-499`.
- **Problem:** The `player-chrome` block renders whenever `controlsVisible && status !== 'error'` (`:434`). The `ended` overlay (`:479`) renders when `status === 'ended'`. If controls are visible at that moment, both can show simultaneously, overlapping.
- **Evidence:** `:434` chrome condition does not exclude `ended`/`buffering`/`loading`; overlays at `:463,471,479` are independent.
- **Impact:** Minor visual clutter (e.g. transport controls behind the "Playback ended" card).
- **Recommended fix:** Hide the chrome for terminal/overlay statuses (`loading`/`ended`), or render overlays above with a scrim and suppress chrome.
- **Estimated effort:** XS.
- **Dependencies/blockers:** None.
- **Verification:** Reach `ended` with controls visible; confirm no overlap.

---

### 5.4 Shared Protocol Issues

---

#### SP-002 — TypeScript protocol is a hand-maintained mirror with no drift guard
- **Severity:** Medium
- **Category:** Duplicated protocol / maintainability
- **Files:** `shared/protocol/RoomEvents.cs`, `shared/protocol/payloads/Payloads.cs`, `shared/lib/protocol/*.dart` vs. `client_samsung_tv/src/protocol/roomEvents.ts` + `payloads.ts`.
- **Problem:** The protocol exists three times. C# and Dart live under `shared/` and the C# is compiled into the server (`WatchParty.Server.csproj:21-24`) while the Dart is a pub package consumed by Flutter — so those two are at least co-located and `shared/test/protocol_fields_test.dart` exists. The **TypeScript** copy lives *inside the TV project* and is not generated from, or tested against, the shared source. Nothing prevents silent drift (a renamed event or added field on the server that the TS copy misses).
- **Evidence:** Identical-by-eye but independent files: `roomEvents.ts:1-35` vs `RoomEvents.cs:8-49` vs `room_events.dart:1-37`; `payloads.ts` vs `Payloads.cs` vs `payloads.dart`. No build step ties TS to `shared/`.
- **Impact:** A future protocol change risks a TV/server mismatch that only shows up at runtime (events never received, fields silently `undefined`).
- **Recommended fix:** Generate the TS protocol from the shared source (or add a CI check that diffs event-name/field lists across all three), so drift fails the build. At minimum, add a TS unit test asserting the event-name constants match a checked-in snapshot of `RoomEvents.cs`.
- **Estimated effort:** M.
- **Dependencies/blockers:** Ties into `TV-008` (no TV CI).
- **Verification:** Introduce a deliberate rename in `RoomEvents.cs`; confirm the drift check fails.

---

#### SP-003 — `IptvContentDescriptor.ContentType` is an unvalidated free-form string server-side
- **Severity:** Low
- **Category:** Validation
- **Files:** `shared/protocol/payloads/Payloads.cs:7-14` (`ContentType` is `string`); server `RoomHub.SetContent` (`RoomHub.cs:361`) / `RoomService.HandleSetContent` (`RoomService.cs:446`).
- **Problem:** Clients model `contentType` as a union (`'live'|'movie'|'episode'`), but the server stores/rebroadcasts whatever string a (host) client sends with no validation.
- **Evidence:** `Payloads.cs:8` `string ContentType`; `HandleSetContent` assigns `room.ContentDescriptor = descriptor` with no check.
- **Impact:** Low — a malformed `contentType` only affects that room's own guest, which resolves the URL locally (TV `resolvePlaybackUrl` falls through to the `episode` branch for unknown types). No cross-tenant impact. Still an unvalidated input that is echoed to peers.
- **Recommended fix:** Validate `ContentType` against the known set in `HandleSetContent`; reject or normalize unknown values.
- **Estimated effort:** S.
- **Dependencies/blockers:** None.
- **Verification:** Send a bogus `contentType`; expect a `room:error` or normalization.

---

### 5.5 Cross-Project Compatibility Issues

---

#### XP-001 — Host reconnection is impossible across both clients (client-side manifestation of BE-001)
- **Severity:** High
- **Category:** Reconnect / watch-party reliability
- **Files:** `client_samsung_tv/src/room/roomClient.ts:249-268` (`rejoinAfterReconnect` bails for host); `client/lib/features/reconnect/reconnect_bloc.dart:117-122,151-157` (treats `room_not_found`/`room_full` as fatal); server `RoomService.cs:205-212` (`BE-001`).
- **Problem:** Because the server destroys the room on host disconnect (`BE-001`), neither client can recover the host. The TV explicitly refuses host rejoin (`roomClient.ts:251-258` emits `host_reconnect_limited`). The Flutter `ReconnectBloc` attempts a rejoin but the server returns `room_not_found`/`room_full`, which the bloc classifies as fatal → `ReconnectStateFailed`.
- **Evidence:** `roomClient.ts:251` `if (this.role === 'host') { ... return; }`; `reconnect_bloc.dart:118-122` `_fatalErrorCodes = { 'room_not_found','room_closed','room_full','role_invalid' }`.
- **Impact:** Any host-side transport interruption ends the session permanently for both participants. This is the single biggest reliability gap in the watch-party feature.
- **Recommended fix:** Land `BE-001` (host grace + rebind), then make both clients re-invoke `JoinRoom(code,"host")` on reconnect and stop treating the resulting (now successful) rejoin as fatal. Update `_fatalErrorCodes` handling accordingly.
- **Estimated effort:** Server M (`BE-001`) + client S each.
- **Dependencies/blockers:** `BE-001`.
- **Verification:** Drop and restore the host's network mid-session on both clients; confirm the room and playback survive.

---

#### XP-002 — Production CORS will block the browser-based Tizen TV client
- **Severity:** High
- **Category:** CORS / deployment / cross-project
- **Files:** `server/WatchParty.Server/Program.cs:73-102` + `appsettings.json:38-40` (`Cors:AllowedOrigins: []`) + `appsettings.Production.example.json:3-7`; TV `room/roomApi.ts:37` (`fetch ${base}/api/v1/rooms`) and `room/roomClient.ts:158-164` (SignalR negotiate).
- **Problem:** The Tizen TV app is a Chromium web app and is therefore subject to CORS. In production with no `AllowedOrigins`, the policy is `WithOrigins(Array.Empty<string>())` (`Program.cs:90-92`) — no `Access-Control-Allow-Origin` is returned. The TV's `fetchActiveRooms` XHR and the SignalR **negotiate** POST are cross-origin and will be blocked. (The Flutter client is native — `dio`/`signalr_netcore` — and is *not* CORS-bound, so it is unaffected.)
- **Evidence:** `appsettings.json:39` `"AllowedOrigins": []`; `Program.cs:84-92` (empty origins in Production → ACAO not emitted); `appsettings.Production.example.json` only lists `https://your-client-app.example.com`. TV README claims the production server works "out of the box," but the TV's web origin is not in any allow-list.
- **Impact:** On the production backend as configured, the TV's Join screen (rooms list) and SignalR connection likely fail with CORS errors — a deployment blocker for the TV product.
- **Recommended fix:** Determine the `Origin` a packaged Tizen widget sends (often the widget origin or `null`) and add it to `Cors:AllowedOrigins` in production; or, if SignalR is configured to skip negotiation/WebSockets-only, validate that path. **Needs verification** on real hardware/emulator with the production server.
- **Estimated effort:** S (config) once the Tizen origin is known; the verification is the real work.
- **Dependencies/blockers:** Need to observe the Tizen client's actual `Origin` header.
- **Verification:** From a packaged TV build pointed at `https://moviedate.runasp.net`, open the Join screen and create/join a room; inspect for CORS failures; adjust `AllowedOrigins` until both REST and SignalR succeed.

---

#### XP-003 — TV guest has no deferred-command replay (Flutter does)
- **Severity:** Medium
- **Category:** Sync / watch-party correctness
- **Files:** `client_samsung_tv/src/screens/PlayerScreen.tsx:309-410`; contrast `client/lib/features/sync/sync_engine.dart:405-413,894-1012` (`_deferredQueue` + `_flushDeferredQueue`).
- **Problem:** The Flutter sync engine **defers** play/pause/seek/state_sync received before the player is ready and replays the latest intent once ready. The TV applies commands immediately in a `useEffect`. If a `play`/`pause`/`seek` arrives while AVPlay is still loading, the underlying `player.seek()/play()` are no-ops (`AvPlayPlayer` guards on `this.loaded`), yet the TV still advances `lastAppliedSeqRef` (`PlayerScreen.tsx:322,335,345`) and sets `status='playing'` — so the command is *marked applied but dropped*.
- **Evidence:** `PlayerScreen.tsx:319-330` records `lastAppliedSeqRef.current = seqNo` then calls `player.seek/play` (which no-op pre-load); `AvPlayPlayer.ts:80-103` guards `if (!this.loaded) return`. No deferral/replay exists.
- **Impact:** A TV guest joining mid-playback (or after a host episode change) can miss the initial authoritative command and stay at position 0 / wrong play-state until the next periodic `playback:state_sync` (up to ~5 s) corrects it. Worse, marking the seq applied means a re-sent identical seq is ignored. Out-of-sync window on join/episode-change.
- **Recommended fix:** Mirror Flutter: queue commands received before `onReady`, and on `onReady` apply only the newest intent (highest seq); do not advance `lastAppliedSeqRef` for commands that didn't actually execute.
- **Estimated effort:** M.
- **Dependencies/blockers:** Benefits from `TV-008` (tests) to lock behaviour.
- **Verification:** Host plays at t>0; guest joins; confirm the guest seeks to the host position immediately on ready, not after the next 5 s sync.

---

#### XP-004 — Player-ready gate semantics differ between clients
- **Severity:** Low
- **Category:** Sync consistency
- **Files:** `client/lib/features/sync/sync_engine.dart:337-376` (Flutter defers until `_playerReady` and notifies `player:ready`); `client_samsung_tv/src/App.tsx:79-89` + `PlayerScreen.tsx:244-249` (TV treats `player:ready` as informational UI only).
- **Problem:** The server exposes a "both players ready" gate (`RoomService.HandleNotifyPlayerReady`, `RoomHub.NotifyPlayerReady`). Flutter uses readiness to gate command application; the TV uses it only to flip a "ready" badge and otherwise applies commands immediately.
- **Evidence:** Flutter `setPlayerReady`/deferred queue vs. TV `updateReadyState` (badges) + immediate command apply.
- **Impact:** Low and largely masked by periodic state-sync, but in a mixed Flutter-host / TV-guest room the start-of-playback alignment can differ from a Flutter-Flutter room (host could begin before the TV guest is buffered). Relates to `XP-003`.
- **Recommended fix:** Decide on one readiness contract and have the TV honour it (defer until ready), ideally as part of `XP-003`.
- **Estimated effort:** S (folds into `XP-003`).
- **Dependencies/blockers:** `XP-003`.
- **Verification:** Mixed-client room: confirm playback starts only once both report ready.

---

## 6. Security Findings

| ID | Severity | Summary |
| --- | --- | --- |
| BE-004 | Medium | Active rooms publicly enumerable + joinable with no auth — strangers can join any room (`RoomsController.cs:124-146`). **Product decision.** |
| BE-003 | Medium | `GET /api/v1/rooms` not rate-limited → un-throttled enumeration (`RoomsController.cs:124`). |
| TV-003 | Medium | IPTV credentials in plaintext `localStorage` (`settings.ts:51-55`). |
| TV-004 | Medium | Real IPTV provider domain hardcoded over HTTP as default (`appConfig.ts:21`). |
| BE-009 | Low | Dev CORS = allow-any-origin + credentials (gated to non-prod) (`Program.cs:96-99`). |
| TV-010 | Low | Tizen `<access origin="*"/>` (`config.xml:14`) — broad but use-case-justified. |
| FL-001 | Low | Room-server URLs (with room codes) logged unsanitized (`http_client.dart:31`). |
| SP-003 | Low | Unvalidated `contentType` echoed to peers (`Payloads.cs:8`). |
| XP-002 | High | Production CORS likely blocks the TV (CORS is a security control here too) — see §5.5. |

**Positives (good security hygiene observed):**
- Credentials are **not** committed: `appsettings.local.json` and signing keystores are gitignored (`.gitignore:117-131`); IPTV credentials use `flutter_secure_storage` on Flutter.
- IPTV URL logging is sanitized on Flutter (`AppLogger.sanitizeUrl`/`sanitizeMediaLog`, `app_logger.dart:131-199`) and the TV never logs full URLs (`diagnostics.describeUrl` returns scheme+ext only; diagnostics off by default).
- **Playback URLs are never sent over SignalR** — only the `IptvContentDescriptor` (type/streamId/ext/title) crosses the wire; each client resolves the URL locally with its own credentials (`iptvService.resolvePlaybackUrl`, `iptv_config.dart`). This is the correct design and was a stated requirement.
- Room codes use a cryptographic RNG with an ambiguity-free alphabet (`RoomCodeGenerator.cs:15-16,44`).
- No hardcoded secrets/tokens/private keys found in source (scan §9 found only field names and the provider URL above).

---

## 7. Performance Findings

| ID | Severity | Summary |
| --- | --- | --- |
| TV-005 | Medium | Full-document focusable re-query + reflow on every D-pad press (`remote.ts:145-178`). |
| BE-007 | Medium | In-memory rooms; per-room `Timer` for state sync — fine at small scale, no scale-out. |
| TV-006 | Low | Remote handler effect re-runs every App render (`App.tsx:296`, `remote.ts:82`). |
| FL-002 | Low | 1.6 MB runtime icon asset (`client/assets/icon.png`). |
| TV-009 | Low | (Dev only) esbuild advisory. |

**Positives:**
- **Catalog paging is well-designed.** `usePagedItems`/`useAutoPagedItems` render one ~48-item page and lazy-append on focus-near-end + IntersectionObserver, keeping the focusable DOM small even on huge "All" categories (`hooks/*`, `BrowseScreen.tsx`, `SeriesScreen.tsx`). This pre-empts the classic "render thousands of focusable nodes" TV bug.
- IPTV responses are cached in-memory per category/series (`iptvService.ts:24-26,63-104`), avoiding refetch storms.
- TV production bundle is reasonable: 322 KB JS (95.8 KB gzip) + self-hosted fonts.
- Server uses `SemaphoreSlim` per-room locking with snapshot-then-send patterns; expiry sweep is a single 60 s loop.
- State-sync timer is started only while playing and stopped on pause/buffering/content-change, limiting broadcast volume.

---

## 8. UI/UX & Design Findings

| ID | Severity | Area | Problem | Fix |
| --- | --- | --- | --- | --- |
| TV-002 | Medium | Whole app | No error boundary → render errors white-screen the TV with no recovery | Add `ErrorBoundary` around `<App/>`. |
| TV-005 | Medium | Remote nav | Focus movement can feel laggy on big pages (reflow per press) | Cache/scope focusables. |
| TV-007 | Low | Player (series) | No next-episode prompt/auto-advance on `ended` | Add "Play next SxxExx" to the ended overlay or auto-advance. |
| TV-011 | Low | Player | Ended/overlay can overlap transport chrome | Suppress chrome for terminal statuses. |

**Cross-client design parity (needs manual verification on hardware):** The TV client deliberately
mirrors the Flutter visual identity (Inter / JetBrains Mono / Instrument Serif fonts self-hosted
in `main.tsx`; cinematic palette in `styles.css`; `TvCard`/`TvButton`/`Badge`/focus-ring design
system; `RoomCard.tsx` mirrors Flutter's `room_card.dart`). The component structure and stated
intent are consistent, but true 10-foot readability, focus-ring visibility, spacing, and parity
with the Flutter screens can only be confirmed by running both on real devices — see Open
Questions. Loading/empty/error states are implemented consistently on the TV via shared
`LoadingState`/`EmptyState`/`ErrorState`/`SkeletonGrid` components and are present on every data
screen (Browse/Series/Join/Player), which is a strength.

**Good UX observed:** every data screen has explicit loading + empty + error + retry states; the
Join screen offers both code entry and a live rooms list with silent polling and manual refresh;
"Up next" hint + disabled-on-last-episode handling; live streams correctly disable seeking and
show a LIVE indicator (`isLiveDuration`); auto-hiding player chrome with focus restoration.

---

## 9. Testing Gaps

| Gap | Severity | Recommendation |
| --- | --- | --- |
| **TV client: zero automated tests** and excluded from CI (`TV-008`) | High (for the TV) | Add Vitest; add a TV CI job (`npm ci && typecheck && build && audit`). |
| TV: no tests for `episodeContext.nextEpisode` (season rollover, last-episode) | Medium | Unit tests with multi-season fixtures incl. boundary cases. |
| TV: no tests for `iptvService` URL builders / `resolvePlaybackUrl` | Medium | Assert live/movie/episode URL shapes + encoding. |
| TV: no tests for the `PlayerScreen` command reducer (play/pause/seek/stateSync/buffering, seq dedupe, `XP-003` deferral) | Medium | Extract the reducer and unit-test it. |
| TV: no test for `settings` load/save/validate/sanitize + default fallbacks | Low | Cover blank-value fallback and validation scopes. |
| Server: **no test for host-disconnect grace** (because there is none — `BE-001`) | High | Add once `BE-001` lands: host blip → room survives → rebind. |
| Server: guest-grace-expiry state (`BE-002`) not asserted | Medium | Assert `Active → Waiting` and timer stop on expiry. |
| Protocol drift: no guard tying the TS copy to `shared/` (`SP-002`) | Medium | CI diff/snapshot of event names + fields across C#/Dart/TS. |
| Cross-client reconnect (`XP-001`) / CORS (`XP-002`) | High | Manual/integration validation on hardware against the production server. |

**Strengths:** the server has 86 passing tests (unit + integration + SignalR session + health +
a separate performance workflow); Flutter has a broad suite (`client/test/` incl. sync engine,
reconnect, buffering integration tests, watch screen, room blocs) and passes `flutter analyze`
cleanly; `shared` has a protocol-fields test.

---

## 10. Documentation Gaps

- **`TV-001` not documented and contradicts shipping target.** The README markets Tizen 5.5 while
  the build emits ES2020 syntax those TVs can't parse. Document the supported firmware range and
  the required Vite `build.target`.
- **`XP-002` (CORS for the TV) undocumented.** The TV README says the production backend works
  "out of the box," but does not mention that the server must allow the TV's web origin. Add a
  production setup note (server `Cors:AllowedOrigins` must include the TV origin).
- **`BE-007` deployment constraints** (single-instance, rooms lost on recycle, keep-alive needed)
  should be in a deployment/ops note, not only in the TV "Known limitations" list.
- **Backend has no top-level deployment doc** for `moviedate.runasp.net` (env vars, setting
  `Cors:AllowedOrigins`, ensuring `ASPNETCORE_ENVIRONMENT=Production`, .NET 10 host support).
- **`docs/` did not previously exist** — this is the first file in it. Consider an index/README.
- **Accurate today:** the TV README's descriptions of paging, Join-room list, Next-Episode flow,
  packaging, and known limitations match the code. The Flutter `appsettings.example.json` +
  README config story is clear and correct.

---

## 11. Prioritized Fix Roadmap

### Phase 0 — Critical safety / production-blocking
- **Goals:** Make the TV app actually run on target hardware and not leak/over-expose; unblock TV deployment.
- **Issues:** `TV-001`, `XP-002`, `TV-004`, (`TV-003` doc-accept).
- **Steps:**
  1. `TV-001`: set `vite.config.ts` `build.target` to `['chrome69']` (or `'es2019'`); `npm run build`; **re-scan `dist/assets/*.js` for `?.`/`??` (expect 0)**; install the `.wgt` on a Tizen 5.5 emulator and confirm render.
  2. `XP-002`: package a TV build pointed at the production server; observe the `Origin` it sends; add it to `Cors:AllowedOrigins` (production config/env); confirm rooms list + SignalR connect.
  3. `TV-004`: replace `DEFAULT_IPTV_BASE_URL` with a neutral placeholder/blank; prefer HTTPS.
  4. `TV-003`: document the plaintext-credential limitation as an accepted risk (already partly in README); decide on backend-proxy follow-up.
- **Files:** `client_samsung_tv/vite.config.ts`, `src/config/appConfig.ts`, server prod config/env, README(s).
- **Validation:** `npm run build` + bundle re-scan; emulator/hardware smoke test; CORS check against prod.
- **Manual checklist:** App opens on Tizen 5.5 emulator; Join screen lists rooms from prod; create/join a room; play a stream.

### Phase 1 — Correctness & compatibility
- **Goals:** Fix room-lifecycle and protocol-safety gaps.
- **Issues:** `BE-001`/`XP-001`, `BE-002`, `BE-003`, `BE-004` (decision), `SP-002`, `SP-003`.
- **Steps:** Implement host grace + rebind (`BE-001`); update both clients' host-rejoin handling (`XP-001`); fix guest-grace-expiry state transition (`BE-002`); add rate limiting to `ListRooms` (`BE-003`); decide and implement room access policy (`BE-004`); add a protocol drift guard in CI (`SP-002`); validate `contentType` (`SP-003`).
- **Files:** `RoomService.cs`, `RoomHub.cs`, `roomClient.ts`, `reconnect_bloc.dart`, `RoomsController.cs`, CI, `HandleSetContent`.
- **Validation:** New/updated server tests; reconnect integration test; `dotnet test`.
- **Manual checklist:** Host network blip survives; guest-left settles room state; rooms-list throttles; protocol rename fails CI.

### Phase 2 — Player & watch-party reliability
- **Goals:** Tight, consistent sync across clients.
- **Issues:** `XP-003`, `XP-004`, `TV-007`, `BE-005`.
- **Steps:** Add deferred-command replay on the TV and stop marking unexecuted commands applied (`XP-003`); align readiness-gate semantics (`XP-004`); next-episode auto-advance/prompt on `ended` (`TV-007`); snapshot `PlaybackRate` under lock (`BE-005`).
- **Files:** `PlayerScreen.tsx`, `App.tsx`, `StateSyncTimerService.cs`.
- **Validation:** TV reducer unit tests; mixed-client manual sync test.
- **Manual checklist:** TV guest catches up immediately on join/episode change; playback starts only when both ready; series rolls to next episode.

### Phase 3 — Performance & scalability
- **Goals:** Smooth TV navigation; clarify scale limits.
- **Issues:** `TV-005`, `TV-006`, `FL-002`, `BE-007`.
- **Steps:** Cache/scope focusables + drop `getComputedStyle` from the hot path (`TV-005`); memoize remote handlers (`TV-006`); compress/resize the Flutter runtime icon (`FL-002`); document single-instance limits and (optionally) add a SignalR backplane (`BE-007`).
- **Files:** `remote.ts`, `App.tsx`, `client/assets/icon.png` + `pubspec.yaml`, deployment docs.
- **Validation:** Profile D-pad latency on emulator; bundle-size diff.
- **Manual checklist:** Snappy focus on the largest catalog page.

### Phase 4 — UI/UX polish
- **Goals:** Robust, consistent TV UX.
- **Issues:** `TV-002`, `TV-011`, `TV-010`, `BE-006`, `BE-009`.
- **Steps:** Add `ErrorBoundary` (`TV-002`); fix overlay/chrome overlap (`TV-011`); document `access origin` rationale (`TV-010`); narrow startup catch (`BE-006`); assert prod CORS path (`BE-009`).
- **Files:** `main.tsx`/new `ErrorBoundary.tsx`, `PlayerScreen.tsx`, `config.xml` docs, `Program.cs`.
- **Validation:** Force a render error; confirm recovery screen.
- **Manual checklist:** No blank screens on simulated component failure.

### Phase 5 — Testing & documentation
- **Goals:** Cover the least-tested client; document deployment.
- **Issues:** `TV-008`, `TV-009`, `FL-003`, plus docs from §10.
- **Steps:** Add Vitest + TV CI job (`TV-008`); `npm audit fix` (`TV-009`); reconnect integration test + dep tracking (`FL-003`); write deployment/ops + Tizen-support docs.
- **Files:** `ci.yml`, `client_samsung_tv/` test files + config, docs.
- **Validation:** CI runs and passes the new TV job + tests.
- **Manual checklist:** Green CI across all four projects.

---

## 12. Non-Issues / Confirmed Safe Areas

- **Protocol consistency (event names, hub methods, payload field names)** is currently **identical**
  across C# (`shared/protocol/RoomEvents.cs`, `Payloads.cs`), Dart (`shared/lib/protocol/*`), and
  TS (`client_samsung_tv/src/protocol/*`): same event strings (`room:joined`, `playback:play`, …),
  same hub method names (`CreateRoom`, `Play`, …), same JSON field names. (Drift *prevention* is the
  only gap — `SP-002`.) `XP-005` (compatibility of base URL `/`, API prefix `/api/v1`, hub path
  `/hubs/room`, 6-char room code A–Z(no I/O/0/1)+2–9, room states) is **confirmed aligned** across
  all three: `app_constants.dart:4`, `appConfig.ts:24-27`, `http_client.dart:23`, `Program.cs:182`,
  `RoomsController.cs:11`.
- **No playback URLs over the wire** — only `IptvContentDescriptor` is synced; URLs resolve locally
  (correct design; see §6).
- **`BufferingStallBroadcastPayload` field ordering** differs cosmetically across languages but is
  JSON name-keyed, so it is interoperable (not an issue).
- **Server build/tests** clean: 0 warnings, 86 tests passing.
- **`flutter analyze`** clean; Flutter sync engine has thorough seq-dedup, drift-throttling,
  deferred-queue, and cooldown logic plus matching tests.
- **Secrets management:** local config + keystores gitignored; no committed secrets, keys, or
  certificates found.
- **Catalog paging / focusable-DOM size** on the TV is already solved (the exact class of bug the
  audit brief called out) — `useAutoPagedItems`.
- **Rate limiting** exists for create/join/status with `Retry-After` and a clean 429 body (only the
  list endpoint is missing it — `BE-003`).
- **Health/version:** `/health` endpoint returns status + active room count; `RoomHealthCheck`
  wired up.

---

## 13. Open Questions

1. **Room privacy model (`BE-004`):** Is publicly listing every active room code and allowing any
   client to join as guest the intended product behaviour, or should rooms be private/PIN-gated /
   "discoverable opt-in"? This changes the fix.
2. **Tizen support floor (`TV-001`):** What is the lowest Samsung TV firmware you must support? If
   genuinely Tizen 5.5 (2020), the build target must down-level; confirm on a 5.5 emulator.
3. **TV production `Origin` (`XP-002`):** What `Origin` does the packaged Tizen widget send to the
   backend? Needed to set `Cors:AllowedOrigins` correctly. (Requires a hardware/emulator capture.)
4. **Hosting (`BE-007`):** Does `moviedate.runasp.net` (a) support .NET 10 in production and
   (b) keep the process warm (no idle recycle)? If not, in-memory rooms will drop frequently.
5. **TV credentials (`TV-003`):** Acceptable to keep IPTV credentials in `localStorage`, or should
   provider auth be proxied through the backend so the TV never stores them?

---

## 14. Final Recommendation

**Status: Staging-ready (not yet production-ready as a whole).**

- **Backend** — *Near production-ready.* Clean build, 86 passing tests, sound architecture and
  security hygiene. Blocking items before "production": host-grace/reconnect (`BE-001`), rate-limit
  the rooms list (`BE-003`), decide the room-privacy model (`BE-004`), and document the
  single-instance/in-memory deployment constraints (`BE-007`).
- **Flutter client** — *Closest to production-ready.* Analyzer-clean, well-tested, good security
  hygiene. Only low-severity items (`FL-001..003`), most of which resolve alongside the server's
  reconnect fix.
- **Samsung TV client** — *Prototype-to-staging.* Well-structured and feature-complete on paper, but
  it must clear two likely blockers before it can be trusted in production: the **ES2020/Tizen 5.5
  syntax issue (`TV-001`)** and the **production CORS issue (`XP-002`)**, both of which require
  validation on real Samsung hardware/emulator. It also needs an error boundary (`TV-002`),
  de-hardcoded provider (`TV-004`), sync deferral parity (`XP-003`), and at least smoke-level tests
  + CI (`TV-008`).

**Why:** the watch-party core (protocol, sync engine, buffering gate, paging, server reliability at
small scale) is genuinely solid and well-tested on the server and Flutter side. The risk is
concentrated in (1) host reconnection being structurally impossible (a server lifecycle decision
that affects every client) and (2) the newest client (TV) carrying unverified runtime/deployment
assumptions for Samsung hardware. None of these are deep architectural flaws — they are bounded,
well-understood fixes.

**Exact next action:** Execute **Phase 0** — flip the Vite build target and re-scan the bundle
(`TV-001`), then validate a packaged TV build against the production server for both rendering and
CORS (`XP-002`) on a Tizen 5.5 emulator. Those two results determine whether the TV client is a
quick config fix away from staging or needs deeper hardware work.
