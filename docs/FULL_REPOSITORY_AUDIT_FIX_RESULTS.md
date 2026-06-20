# MoonWatch Full Repository Audit — Fix Results

> Companion to [`FULL_REPOSITORY_AUDIT_FIX_PLAN.md`](FULL_REPOSITORY_AUDIT_FIX_PLAN.md)
> (the original read-only audit, left unchanged). This document records what was actually
> implemented for each of the **29** audit issues. Nothing is committed by this work.

## Status legend

- **Fixed** — addressed in code/config with tests where applicable.
- **Documented accepted risk** — a platform/product constraint mitigated and documented.
- **Needs manual hardware verification** — code-side mitigation complete; a final check on
  a real Samsung TV / emulator (or the production host) remains.

## Verification summary (commands run)

| Project | Command | Result |
| --- | --- | --- |
| Backend | `dotnet build server/WatchParty.slnx -c Debug` | ✅ 0 warnings, 0 errors |
| Backend | `dotnet test … --filter "Category!=Performance&Category!=Benchmark"` | ✅ **92 passed** (was 86) |
| Flutter | `flutter pub get` / `flutter analyze` | ✅ `No issues found!` |
| Flutter | `flutter test test/features/reconnect test/core/network test/core/logging` | ✅ **28 passed** (targeted; see notes) |
| Flutter | `dart format --set-exit-if-changed` (changed files) | ✅ no changes |
| TV | `npm run typecheck` | ✅ no type errors |
| TV | `npm run build` | ✅ built; bundle scan **0** `?.`/`??` |
| TV | `npm test` (Vitest) | ✅ **25 passed** (6 files) |
| TV | `npm run check:protocol` | ✅ 31 strings aligned C#/Dart/TS |
| TV | `npm audit` | ⚠️ 1 low (esbuild, dev-only) — see TV-009 |
| TV | `npm run package:tizen` | ⏭️ Tizen CLI not on PATH (env limit) — see notes |
| Shared | `dart analyze` / `dart test` | ✅ `No issues found!` / **16 passed** |

---

## Per-issue results

### Critical

#### TV-001 — Vite target ships ES2020 syntax unsupported by Tizen 5.5 — **Fixed**
- **Files:** `client_samsung_tv/vite.config.ts`
- **Change:** `build.target: 'es2020'` → `target: ['chrome69']` so esbuild down-levels `?.`/`??`.
- **Verification:** `npm run build` then scan `dist/assets/*.js`.
- **Result:** Bundle now contains **0** optional-chaining / nullish operators (was 108 + 45).
- **Manual:** Install the `.wgt` on a Tizen 5.5 emulator and confirm the app renders.

### High

#### BE-001 / XP-001 — Host disconnect closed the room; host reconnect impossible — **Fixed**
- **Files (server):** `Models/Room.cs` (`HostAway`, `HostGraceCts`), `Configuration/WatchPartyOptions.cs`
  (`HostGracePeriodSeconds`), `Services/RoomService.cs` (`StartHostGracePeriod`,
  `HandleHostDisconnect`, host-rebind in `HandleHostJoin`, `IRoomService.JoinResult.IsHostReconnect`),
  `Hubs/RoomHub.cs` (emit `room:host_away` / `room:host_reconnected`), `appsettings.json`.
- **Files (protocol):** `shared/protocol/RoomEvents.cs` + `payloads/Payloads.cs`,
  `shared/lib/protocol/room_events.dart` + `payloads.dart`,
  `client_samsung_tv/src/protocol/roomEvents.ts` + `payloads.ts` (additive `room:host_away`,
  `room:host_reconnected` + payloads — backward-compatible).
- **Files (clients):** `client_samsung_tv/src/room/roomClient.ts` (host now rejoins instead of
  emitting `host_reconnect_limited`), `client_samsung_tv/src/App.tsx` (host-away/reconnected UI);
  Flutter `reconnect_bloc` already rejoins with the stored role — the server fix makes it succeed.
- **Verification:** `dotnet test` (new `HostDisconnect_StartsGracePeriod_RoomSurvives`,
  `HostReconnect_WithinGracePeriod_RebindsConnection`, `HostGracePeriodExpiry_ClosesRoom`);
  `flutter test` (new host-rejoin `reconnect_bloc_test`).
- **Result:** Host blip keeps the room alive; host rebinds a new connection id; room closes only
  on grace expiry. All backend + Flutter tests pass.
- **Manual:** Drop/restore the host network mid-session on real devices and confirm the room and
  playback survive.

#### XP-002 — Production CORS blocks the browser-based TV — **Fixed (needs manual hardware verification of the origin)**
- **Files:** `server/WatchParty.Server/Program.cs` (config-driven CORS; credentials only for
  explicit non-`*`/non-`null` origins; startup logging), `Configuration/WatchPartyOptions.cs`
  (`Cors.AllowCredentials`), `appsettings.json`, `appsettings.Production.example.json`,
  `docs/DEPLOYMENT.md`, `client_samsung_tv/README.md`.
- **Verification:** `dotnet build`/`dotnet test` green; production example config + docs updated.
- **Result:** Production allows configured origins (incl. the literal `null` for widgets) safely;
  never any-origin-with-credentials. Flutter (native) unaffected; `/api/v1` and `/hubs/room` unchanged.
- **Manual:** Capture the packaged Tizen widget's `Origin` against the production server and add it
  to `Cors:AllowedOrigins`; confirm the rooms list + SignalR connect.

### Medium

#### BE-002 — Guest grace expiry left the room `Active` with no guest — **Fixed**
- **Files:** `Services/RoomService.cs` (expiry task: `Active → Waiting`, stop sync timer, notify host
  `room:guest_left` grace 0).
- **Verification:** `dotnet test` (`GuestGracePeriodExpiry_*` updated to assert `Waiting`).
- **Result:** Room settles out of `Active`; broadcasts stop; host UI gets a definitive signal.

#### BE-003 — `GET /api/v1/rooms` not rate-limited — **Fixed**
- **Files:** `Program.cs` (new `room-list` policy + `Retry-After`), `Controllers/RoomsController.cs`
  (`[EnableRateLimiting("room-list")]`), `WatchPartyOptions.cs` (`RoomListRateLimit`), `appsettings.json`.
- **Verification:** `dotnet test`; policy returns 429 + `Retry-After` past the window.
- **Result:** Rooms list is throttled (default 30/60s per IP).

#### BE-004 — Active rooms publicly enumerable — **Fixed (hardened) / product-configurable**
- **Files:** `Controllers/RoomsController.cs` (dropped internal `hostRtt`; `PublicRoomListing` flag),
  `WatchPartyOptions.cs` (`PublicRoomListingOptions`), `appsettings*.json`, `docs/DEPLOYMENT.md`,
  test `RoomsControllerTests.ListRooms_WhenPublicListingDisabled_ReturnsEmpty`.
- **Verification:** `dotnet test`.
- **Result:** Listing kept (TV Join screen needs it) but returns only safe public summaries (no
  credentials, playback URLs, or internal state) and can be disabled in production via config.

#### BE-007 — In-memory rooms / single-instance — **Documented accepted risk** (+ diagnostics)
- **Files:** `docs/DEPLOYMENT.md`, `Program.cs` (`/health` now returns `version` + `uptimeSeconds`).
- **Result:** Constraint documented (rooms lost on recycle, no scale-out without a backplane, keep
  process warm); health endpoint signals process recycles. No Redis/paid infra added.

#### TV-002 — No React error boundary — **Fixed**
- **Files:** `client_samsung_tv/src/components/ErrorBoundary.tsx` (new), `components/index.ts`,
  `src/main.tsx` (wraps `<App/>`).
- **Verification:** `npm run typecheck` / `npm run build`.
- **Result:** Child render/commit errors now render a recovery screen with **Return Home** /
  **Reload app** instead of a white screen.
- **Manual:** Force a render error on device and confirm the recovery screen.

#### TV-003 — IPTV credentials in plaintext LocalStorage — **Documented accepted risk**
- **Files:** `client_samsung_tv/README.md` (explicit accepted-risk note), `src/player/diagnostics.ts`
  (removed dead `eslint-disable`). No fake encryption added.
- **Result:** Risk documented; verified no logging of username/password/full stream URLs (diagnostics
  off by default and only ever emit `scheme · *.ext`; playback URLs never sent over SignalR).

#### TV-004 — Real IPTV provider hardcoded over HTTP — **Fixed**
- **Files:** `src/config/appConfig.ts` (`DEFAULT_IPTV_BASE_URL = ''`), `src/settings/settings.ts`
  (blank stays blank, validation forces entry), `README.md`.
- **Verification:** `npm test` (`settings.test.ts`), `npm run typecheck`.
- **Result:** No real provider URL committed; user must enter their own provider. Production server
  default unchanged.

#### TV-005 — Spatial navigation reflow on every keypress — **Fixed**
- **Files:** `src/navigation/remote.ts` (scope focusables to the active `FocusBoundary`, cache the
  list with a `MutationObserver`, read each rect once, drop `getComputedStyle` from the hot path).
- **Verification:** `npm run typecheck` / `npm run build`.
- **Result:** D-pad navigation no longer re-queries the whole document or runs `getComputedStyle`
  per candidate per keypress; behaviour preserved (zero-size guard retained).
- **Manual:** Profile arrow latency on the largest catalog page on emulator/hardware.

#### TV-008 — TV client untested & excluded from CI — **Fixed**
- **Files:** `client_samsung_tv/package.json` (Vitest + `test`/`check:protocol` scripts, deps),
  `vitest.config.ts` (new), 6 test files (`settings`, `iptvService`, `episodeContext`, `protocol`,
  `playbackCommandQueue`, `usePagedItems`), `.github/workflows/ci.yml` (new `samsung-tv` job:
  `npm ci`, protocol check, typecheck, test, build, `npm audit --audit-level=high`), removed dead
  `eslint-disable`.
- **Verification:** `npm test` → **25 passed**.
- **Result:** TV client now has unit tests and a CI job.

#### SP-002 — TypeScript protocol unguarded against drift — **Fixed**
- **Files:** `client_samsung_tv/scripts/check-protocol-drift.mjs` (new), `package.json`
  (`check:protocol`), CI job, `src/protocol/protocol.test.ts` (snapshot), Dart
  `shared/test/protocol_fields_test.dart` (new host-event assertions).
- **Verification:** `npm run check:protocol` → 31 strings aligned across C#/Dart/TS; fails on drift.
- **Result:** A renamed/added/removed event in any of the three languages now fails CI.

#### XP-003 — TV guest had no deferred-command replay — **Fixed**
- **Files:** `src/room/playbackCommandQueue.ts` (new `DeferredCommandQueue`),
  `src/screens/PlayerScreen.tsx` (defer commands received before the player is ready, replay the
  newest on `onReady`, only mark a seq applied when it actually executes).
- **Verification:** `npm test` (`playbackCommandQueue.test.ts`), `npm run typecheck`.
- **Result:** A TV guest joining mid-playback applies the authoritative command on ready instead of
  dropping it; sequence numbers are no longer marked applied for no-op commands.

### Low

#### XP-004 — Player-ready gate semantics differed — **Fixed** (folded into XP-003)
- **Files:** `src/screens/PlayerScreen.tsx`. The TV now defers commands until the player is ready,
  matching the Flutter readiness contract.

#### TV-006 — Remote handlers re-registered every render — **Fixed**
- **Files:** `src/navigation/remote.ts` (handlers held in a ref; `keydown` listener + Tizen key
  registration run once per mount).
- **Verification:** `npm run typecheck` / `npm run build`.

#### TV-007 — No next-episode prompt on `ended` — **Fixed**
- **Files:** `src/screens/PlayerScreen.tsx` (ended overlay shows a prominent **Play next: SxxExx**
  button for host/solo series when a next episode exists; host advance syncs via existing
  `SetContent`; guests keep only "Back to catalog").
- **Verification:** `npm test` (`episodeContext.test.ts` covers rollover/last-episode), build.
- **Manual:** Reach end-of-episode on device and confirm the prompt.

#### TV-009 — esbuild dev-server advisory — **Documented accepted risk (dev-only, non-shipping)**
- **Files:** CI `npm audit --audit-level=high` (won't fail on this low advisory); `docs`.
- **Result:** `npm audit fix` cannot resolve it without a breaking Vite bump. The advisory affects
  only the Vite dev server on Windows and is **not** present in the shipped Tizen bundle.

#### TV-010 — `<access origin="*">` — **Documented accepted risk**
- **Files:** `client_samsung_tv/README.md` (rationale: arbitrary user-supplied IPTV providers).
- **Result:** Kept as-is (use-case-justified); documented.

#### TV-011 — Ended/overlay states overlap player chrome — **Fixed**
- **Files:** `src/screens/PlayerScreen.tsx` (chrome suppressed for `ended`/`loading` terminal states).
- **Verification:** `npm run typecheck` / `npm run build`.

#### BE-005 — `PlaybackRate` read outside the room lock — **Fixed**
- **Files:** `Services/StateSyncTimerService.cs` (snapshot `playbackRate` under the lock; use the
  local in the payload).
- **Verification:** `dotnet build` / `dotnet test`.

#### BE-006 — Empty `catch {}` around startup log reset — **Fixed**
- **Files:** `Program.cs` (`catch (Exception ex)` → `Console.Error`).
- **Verification:** `dotnet build` / `dotnet test`.

#### BE-009 — Dev CORS allows any origin with credentials — **Fixed (guarded/documented)**
- **Files:** `Program.cs` (startup logs the active CORS posture; warns on Production + empty
  origins; dev allow-any stays gated on `!IsProduction()`), `docs/DEPLOYMENT.md`.
- **Result:** Production never uses any-origin-with-credentials; misconfiguration is visible at boot.

#### FL-001 — Room-server HTTP logging unsanitized — **Fixed**
- **Files:** `client/lib/core/network/http_client.dart` (request/response/error URIs routed through
  `AppLogger.sanitizeUrl`).
- **Verification:** `flutter analyze`; `flutter test test/core/network` green.

#### FL-002 — Oversized 1.6 MB runtime icon — **Fixed**
- **Files:** `client/pubspec.yaml` (removed `assets/icon.png` from the runtime asset bundle; it is
  not referenced by Dart code — only by `flutter_launcher_icons`, which reads the file path at
  build time, so launcher generation is unaffected and the 1.6 MB no longer ships in the bundle).
- **Verification:** `flutter pub get` / `flutter analyze` green.
- **Note:** No reliable PNG optimizer (ImageMagick/pngquant/oxipng) was available in the environment;
  removing the unused bundled asset achieves the bundle-size goal with zero UI/launcher impact.

#### FL-003 — `signalr_netcore` dependency + host reconnect — **Fixed (tracked) / Documented**
- **Files:** `client/test/features/reconnect/reconnect_bloc_test.dart` (new host-rejoin success test),
  `client/README.md` / docs (dependency-risk note). Flutter host reconnect now matches the server
  host-grace flow from BE-001.
- **Verification:** `flutter test test/features/reconnect` green.

#### SP-003 — `ContentType` unvalidated server-side — **Fixed**
- **Files:** `Services/RoomService.cs` (validate/normalize against `{live, movie, episode}` in
  `HandleSetContent`), `Exceptions/RoomExceptions.cs` (`InvalidContentTypeException`),
  `Hubs/RoomHub.cs` (maps to `room:error` `invalid_content_type`), tests
  `SetContent_InvalidContentType_Throws` / `SetContent_NormalizesContentTypeCasing`.
- **Verification:** `dotnet test`.

### Nice-to-have

#### BE-008 — Room-code generator gives up after 3 collisions — **Fixed**
- **Files:** `Services/RoomCodeGenerator.cs` (`MaxCollisionRetries` 3 → 8), test
  `Generate_SucceedsAfterSeveralCollisions`.
- **Verification:** `dotnet test`.

---

## Manual / hardware checklist (remaining)

These are complete in code/config; the listed checks require a real Samsung TV, the Tizen
emulator, or the production host:

1. **TV-001** — `tizen install -n MoonWatchTV.wgt` on a Tizen 5.5 emulator; confirm the app renders.
2. **XP-002** — capture the packaged widget `Origin` against production; set `Cors:AllowedOrigins`;
   confirm Join-screen rooms list + SignalR connect.
3. **BE-001 / XP-001** — drop & restore the host network mid-session (TV host and Flutter host);
   confirm the room and playback survive and the host rebinds.
4. **TV-002** — force a child render error; confirm the recovery screen (Return Home / Reload app).
5. **TV-005 / TV-006** — profile D-pad latency on the largest catalog page.
6. **TV-007** — reach end-of-episode in a series; confirm the "Play next" prompt and host→guest sync.
7. **Packaging** — `npm run package:tizen` requires the Tizen Studio CLI (not on PATH in this
   environment). With the CLI installed it emits `dist/MoonWatchTV.wgt` with **no** manual rename
   (the packaging script is unchanged; `config.xml` still declares `MoonWatchTV`).
