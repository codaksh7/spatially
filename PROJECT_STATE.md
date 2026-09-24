# Spatially — Project State (Context Transfer Document)

> Reference document for continuing development in a new session.
> Source of truth for current state of both mobile apps as of 2026-09-24.
> Per-app logs (ATTENDEE_LOG.md, VOLUNTEER_LOG.md) remain authoritative for history.

---

## 1. Repo Structure

```
d:\majorProject\
  README.md                        Quick-start for new contributors
  SYSTEM_OVERVIEW.md               Full technical architecture + plain-words explanation + diagrams
  PROJECT_STATE.md                 This file — dense context-transfer snapshot
  architecture_diagram.jpg
  workflow_diagram.jpg
  .gitignore                       Ignores supabase_config.dart, ATTENDEE_LOG.md, VOLUNTEER_LOG.md, build/

  apps/
    attendee_mobile/               Flutter app — attendee-facing (BLE advertiser + ticketing)
      ATTENDEE_LOG.md              Per-app dev changelog (gitignored)
      pubspec.yaml
      android/app/src/main/AndroidManifest.xml
      lib/
        main.dart                  Entry point + AdvertiserScreen (locked screen after "Reached at Event")
        config/supabase_config.dart  GITIGNORED — must be created locally
        screens/
          battery_check_screen.dart
          event_list_screen.dart
          my_tickets_screen.dart
          ticket_detail_screen.dart
        services/
          attendee_identity.dart   Persistent device UUID via shared_preferences
          ephemeral_id.dart        SHA-256 rotating BLE ID + timer scheduling

    volunteer_mobile/              Flutter app — volunteer-facing (BLE scanner + QR check-in)
      VOLUNTEER_LOG.md             Per-app dev changelog (gitignored)
      pubspec.yaml
      android/app/src/main/AndroidManifest.xml
      supabase/
        schema.sql                 v1: observations table
        schema_v2_volunteer_zone.sql   volunteer_id + zone columns on observations
        schema_v3_volunteer_counts.sql volunteer_counts table
        schema_v4_events_tickets.sql   events, tickets, volunteer_assignments + event_id FKs
      lib/
        main.dart                  Entry point + _AuthGate StreamBuilder
        config/supabase_config.dart  GITIGNORED — must be created locally
        models/ble_observation.dart
        screens/
          battery_check_screen.dart
          login_screen.dart
          event_picker_screen.dart
          zone_selection_screen.dart
          scan_screen.dart
          qr_scanner_screen.dart
        services/
          session_state.dart       In-memory singleton: volunteerId, eventId, zone, syncRateSeconds
          ble_scanner_service.dart BLE scan logic, dedup, expiry, telemetry dispatch
          telemetry_service.dart   Supabase insert wrapper + volunteer_counts upsert
          observation_queue.dart   SQLite offline write-behind queue

    flutter_ble_peripheral_patched/  Local fork of flutter_ble_peripheral 2.1.1
      android/src/main/kotlin/.../
        BleAdvertisingService.kt          Native connectedDevice FGS owning BluetoothLeAdvertiser
        FlutterBlePeripheralPlugin.kt     ble_service MethodChannel + activeAdvertisingSet fix
        PeripheralAdvertisingSetCallback.kt  hasReplied guard (Android 14 crash fix)
```

---

## 2. Tech Stack

### Flutter / Dart
- Flutter SDK: 3.47.x (upgraded from 3.44.3 mid-project to fix CFE crash class)
- Dart SDK: resolved to Dart 3.x post-upgrade
- compileSdk: 37 (both apps)
- Target/min SDK: standard Flutter defaults
- Build system: Gradle with `org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=1G`, `org.gradle.parallel=false` (OOM mitigation)

### attendee_mobile — Pinned Dependencies
```
flutter_ble_peripheral: 2.1.1   (overridden → ../flutter_ble_peripheral_patched)
permission_handler:     13.0.1
flutter_foreground_task: 11.0.1
google_fonts:           8.2.1
battery_plus:           7.1.1
supabase_flutter:       2.17.2
qr_flutter:             4.1.0
uuid:                   4.6.0
shared_preferences:     2.5.5
app_settings:           9.0.0
crypto:                 3.0.7
```
dependency_overrides: `flutter_ble_peripheral` → path `../flutter_ble_peripheral_patched`

### volunteer_mobile — Pinned Dependencies
```
flutter_blue_plus:       2.3.12
permission_handler:      13.0.1
flutter_foreground_task: ^11.0.1  (caret — only one not exact-pinned)
supabase_flutter:        2.17.2
google_fonts:            8.2.1
battery_plus:            7.1.1
app_settings:            9.0.0
mobile_scanner:          7.4.0
sqflite:                 2.4.3
connectivity_plus:       7.3.1
```
No dependency_overrides.

### Supabase Credentials
- Stored in `lib/config/supabase_config.dart` in each app (gitignored).
- Variables: `const String supabaseUrl` and `const String supabaseAnonKey`.
- Values: obtain from Supabase dashboard → Project Settings → API. Do NOT hardcode here.
- Supabase plan: free tier (assumed). Project region: not recorded in logs.

### Branding
- All AppBars: `Text.rich` with "Spatially" in `Audiowide` bold (fontSize 18) + "for Attendee"/"for Volunteer" in `Poppins` w300 (fontSize 14).
- Body headers use same font pair at larger sizes.

---

## 3. Database Schema (Current State)

Source of truth: `apps/volunteer_mobile/supabase/schema*.sql`. Apply in order: v1 → v2 → v3 → v4.
RLS is intentionally DISABLED on all tables (prototype phase).

### observations (v1 base, extended v2 + v4)
```sql
CREATE TABLE observations (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at          TIMESTAMPTZ DEFAULT now(),
    ephemeral_id        TEXT        NOT NULL,
    rssi                INTEGER     NOT NULL,
    scanned_at          TIMESTAMPTZ NOT NULL,
    is_spatially_device BOOLEAN     NOT NULL DEFAULT false,
    volunteer_id        UUID        REFERENCES auth.users(id),   -- added v2
    zone                TEXT,                                    -- added v2
    event_id            UUID        REFERENCES events(id)        -- added v4
);
```

### volunteer_counts (v3 base, extended v4)
```sql
CREATE TABLE volunteer_counts (
    volunteer_id UUID        PRIMARY KEY REFERENCES auth.users(id),
    zone         TEXT,
    active_count INTEGER     NOT NULL DEFAULT 0,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    event_id     UUID        REFERENCES events(id)               -- added v4
);
```

### events (v4)
```sql
CREATE TABLE events (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT        NOT NULL,
    venue      TEXT,
    event_date TIMESTAMPTZ NOT NULL,
    status     TEXT        NOT NULL DEFAULT 'upcoming',  -- 'upcoming' | 'live' | 'ended'
    zones      TEXT[]      NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);
```

### tickets (v4)
```sql
CREATE TABLE tickets (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id       UUID        NOT NULL REFERENCES events(id),
    attendee_id    UUID        NOT NULL,
    ticket_code    TEXT        NOT NULL UNIQUE,
    status         TEXT        NOT NULL DEFAULT 'purchased',  -- 'purchased' | 'checked_in'
    purchased_at   TIMESTAMPTZ DEFAULT now(),
    checked_in_at  TIMESTAMPTZ,
    checked_in_by  UUID        REFERENCES auth.users(id)
);
```

### volunteer_assignments (v4)
```sql
CREATE TABLE volunteer_assignments (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    volunteer_id UUID        NOT NULL REFERENCES auth.users(id),
    event_id     UUID        NOT NULL REFERENCES events(id),
    assigned_at  TIMESTAMPTZ DEFAULT now()
);
```

### Seed Data Summary
- Demo events: at least 1 event seeded manually in Supabase dashboard (used for physical testing).
- volunteer_assignments: at least 1 row linking test volunteer account to test event.
- Exact seed rows are not captured in the logs — check Supabase Table Editor directly.
- Test volunteer accounts exist in Supabase Auth (email/password). Credentials are not stored here.

---

## 4. What Is Built and Confirmed Working

In rough chronological order across both apps:

| # | Feature | App | Confirmed Via |
|---|---|---|---|
| 1 | BLE peripheral advertising (basic toggle) | attendee | Physical device, logcat |
| 2 | Android 14 native callback crash fix (hasReplied guard) | attendee | Physical device, no more IllegalStateException |
| 3 | Hardware radio teardown fix (explicit enableAdvertising(false)) | attendee | Logcat STOP_DEBUG logs |
| 4 | Screen-lock advertising persistence (native BleAdvertisingService FGS) | attendee | Physical screen-lock test |
| 5 | BLE scanner with flutter_blue_plus, UUID filtering | volunteer | Physical cross-device test |
| 6 | Sticky Spatially UUID classification (confirmed Spatially set) | volunteer | Cross-device test, scan result inspection |
| 7 | 10s dedup window + 45s presence expiry | volunteer | Logcat, UI counter decrease after device moved away |
| 8 | 30s hardware scan restart (OS cache flush) | volunteer | Logcat timer fires, stale device drops within 45s |
| 9 | Android foreground service for background scanning | volunteer | Screen-lock test, scanning continued |
| 10 | Supabase telemetry — observations INSERT | volunteer | Supabase Table Editor row confirmed |
| 11 | scheduleMicrotask deferral (scan callback latency fix) | volunteer | No perceived scan slowdown post-supabase integration |
| 12 | volunteer_id + zone written to observations | volunteer | Supabase Table Editor |
| 13 | volunteer_counts UPSERT (live active count) | volunteer | Supabase Table Editor, one row per volunteer updating |
| 14 | Supabase Auth — email/password login/logout | volunteer | Physical login test, signOut triggers AuthGate re-route |
| 15 | Zone selection (hardcoded → dynamic from event zones[]) | volunteer | Physical test with event having zones array |
| 16 | Battery gate (50% check, blocking screen) | both | Physical test on low-battery device |
| 17 | Bluetooth gate (non-dismissable overlay, auto-dismiss on BT on) | both | Physical BT toggle test |
| 18 | Attendee persistent device UUID (shared_preferences) | attendee | Logcat UUID stable across app restarts |
| 19 | EventListScreen — Supabase fetch + ticket INSERT | attendee | Physical test, Supabase Table Editor |
| 20 | MyTicketsScreen — ticket list + event join | attendee | Physical test |
| 21 | TicketDetailScreen — QR code render (qr_flutter) | attendee | Visual confirmation on physical device |
| 22 | pushAndRemoveUntil lock to AdvertiserScreen | attendee | Back button confirmed non-functional on AdvertiserScreen |
| 23 | Rotating ephemeral ID (sha256 + 5-min window, native Intent extra) | attendee | Logcat: "Ephemeral ID rotation scheduled in Xs" |
| 24 | Volunteer extracts ephemeral ID from manufacturer data | volunteer | Logcat, observations.ephemeral_id matches expected hex |
| 25 | MAC address fallback if mfr data missing | volunteer | Code path confirmed, logged warning in logcat |
| 26 | Multi-event support (EventPickerScreen, volunteer_assignments join) | volunteer | Physical test with multiple events in DB |
| 27 | QR scanner check-in (mobile_scanner, ticket status UPDATE) | volunteer | Cross-device physical scan test, DB status confirmed |
| 28 | event_id propagated to observations + volunteer_counts | volunteer | Supabase Table Editor |
| 29 | SQLite offline queue (ObservationQueue) | volunteer | Airplane mode test — rows queued, flushed on reconnect |
| 30 | Connectivity_plus flush on regain | volunteer | Airplane mode toggle test |
| 31 | Configurable sync rate (10/30/60s dropdown, mid-scan change) | volunteer | Logcat timer interval change confirmed |
| 32 | Branded AppBars on all screens (Audiowide + Poppins) | both | Visual confirmation on physical devices |
| 33 | INTERNET permission in release manifest | attendee | Release APK connects to Supabase (was missing, fixed) |
| 34 | Release APKs built (flutter build apk --release) | both | APK installed and tested on physical device |

---

## 5. Architecture Decisions and Why

### BLE Manufacturer Data for Ephemeral ID
- **Decision:** Embed the 6-byte ephemeral ID as manufacturer-specific data (company ID 0xFFFF), not as a service data UUID or additional service UUID.
- **Why:** The BLE advertisement payload has a hard byte budget (~31 bytes). The 128-bit service UUID already consumes ~18 bytes of that budget. Adding another UUID would leave no room and can cause advertising to fail. Manufacturer-specific data is the standard extension slot for custom payloads and is reliable across Android versions.
- **Company ID 0xFFFF:** This is the Bluetooth SIG's reserved "test/prototype" company ID. Not registered to any real company. Appropriate for a prototype; a production system should use a registered company ID.
- **6 bytes:** First 6 bytes of SHA-256 output. 48 bits = ~281 trillion unique values per 5-minute window per device. Sufficient for uniqueness within a physical event venue. Longer truncation would eat more advertisement budget.
- **5-minute rotation window:** windowStart = UTC timestamp rounded DOWN to 5-minute boundary (e.g. 14:00:00, 14:05:00). Chosen as a balance between privacy (short enough to prevent long-term tracking) and stability (long enough that a volunteer scanner deduplicates the same device correctly within a window).

### Attendee Identity: Local UUID Not Real Auth
- **Decision:** AttendeeIdentity.deviceId is a UUID v4 generated on first launch and stored in shared_preferences. Attendees have no login.
- **Why:** Adding Supabase Auth for attendees adds friction (email, password, verification) that is inappropriate for a ticketing POC. The device UUID is sufficient to prevent duplicate ticket purchases within a single device lifecycle. The tradeoff (reinstall = orphaned tickets) is accepted for POC scope.
- **tickets.attendee_id has no FK to auth.users:** Intentional — attendees are not auth users.

### Offline Queue: Observations Only, Not volunteer_counts
- **Decision:** ObservationQueue buffers observation writes to SQLite when offline. volunteer_counts upserts are NOT queued — they are simply skipped when offline.
- **Why:** Observations are historical event data — each one is a distinct data point that should eventually reach the DB. Dropping them means permanent data loss. volunteer_counts is a current-state snapshot — if the device is offline, the organizer dashboard already shows stale data for that volunteer. Queuing and replaying old counts would write incorrect "current" state into the table, corrupting the live view. The count will self-heal on the next successful upsert when connectivity returns.

### Native Foreground Service for BLE Advertising
- **Decision:** BluetoothLeAdvertiser is owned and driven by native Kotlin BleAdvertisingService.kt, not by the Flutter Dart layer.
- **Why:** Android 14 aggressively kills Flutter activity processes when the screen is locked or the app is backgrounded. Any Dart-managed advertising stops within seconds of screen lock. A native connectedDevice FGS is protected by the OS from this lifecycle and persists indefinitely with a visible notification.

### scheduleMicrotask for Telemetry Dispatch
- **Decision:** BleScannerService calls telemetry via scheduleMicrotask(), not directly and not via async/await.
- **Why:** Dart async functions execute their synchronous preamble inline on the main isolate before yielding. Even a fire-and-forget await adds latency to each BLE scan callback turn. scheduleMicrotask defers the entire telemetry work to after the current event loop turn, keeping the scan callback lean. unawaited(Future.microtask()) was tried first but crashed the Dart CFE on Windows; scheduleMicrotask from dart:async bypasses the problematic generic type inference.

### Dart CFE Workaround Pattern (Windows-Specific)
- **Decision:** Throughout the codebase, chained property/method expressions are broken into intermediate local variables.
- **Why:** The Dart compiler on Windows (Dart 3.12.2 / SDK 3.44.3) had a class of STATUS_ACCESS_VIOLATION crashes in the CFE frontend during type inference on deeply chained expressions (e.g. Supabase.instance.client.from('x').insert(map)). Breaking chains into typed local variables gives the inferencer a clean stepwise path. Upgrading to Flutter SDK 3.47.x resolved the crash class, but the defensive pattern was left in place in existing code.

---

## 6. Known Issues / Deferred Items

| Issue | Severity | Status | Notes |
|---|---|---|---|
| RLS disabled on all Supabase tables | HIGH | Deliberately deferred | Supabase security scanner flags this. Intentional for prototype — must be addressed before organizer web goes live. All tables currently allow full anon read/write. |
| App icon (both apps) | LOW | Not done | Still using Flutter default blue icon. Swap for Spatially brand asset before any demo/handoff. No code change needed — just replace ic_launcher assets. |
| KGP warning (Kotlin Gradle Plugin) | LOW | Deliberately not fixed | Emitted for app_settings, mobile_scanner (volunteer) and flutter_ble_peripheral (attendee). Non-blocking. Third-party packages need to migrate to Built-in Kotlin — not our change to make. Will fail in a future Flutter version. |
| Attendee identity wipes on reinstall | MEDIUM | Accepted for POC | shared_preferences is cleared on uninstall. Tickets linked to old UUID are orphaned. Fix requires proper attendee auth or cloud-persisted identity. |
| Bluetooth overlay edge case | LOW | Accepted for POC | If OS kills backgrounded volunteer app under memory pressure, scan does not auto-restart on resume. User must tap Start Scan again. |
| No event management UI | LOW | Deferred | Events and volunteer_assignments must be created/edited manually in Supabase Table Editor or SQL Editor. Organizer web will solve this. |
| No real payment for tickets | LOW | Deferred | Ticket "purchase" is free and instant — no payment gateway. Out of scope for Phase 1. |
| volunteer_foreground_task caret version | LOW | Noted | volunteer_mobile has flutter_foreground_task: ^11.0.1 (caret), while attendee_mobile has it exact-pinned at 11.0.1. Minor inconsistency — should be pinned for build reproducibility. |

---

## 7. File Map (Consolidated)

### attendee_mobile

| File | Purpose |
|---|---|
| `lib/main.dart` | App entry point. Initialises Supabase + AttendeeIdentity. Routes BatteryCheckScreen → EventListScreen → (TicketDetailScreen) → AdvertiserScreen. Contains AdvertiserScreen widget with BLE start/stop logic, BT gate overlay, and ephemeral ID rotation timer. |
| `lib/config/supabase_config.dart` | GITIGNORED. Holds supabaseUrl and supabaseAnonKey constants. |
| `lib/services/attendee_identity.dart` | Static class. Reads or generates a UUID v4 from shared_preferences on init. Exposes AttendeeIdentity.deviceId. |
| `lib/services/ephemeral_id.dart` | Computes ephemeralId = sha256(deviceId + windowStartMillis)[0:6]. Exposes secondsUntilNextWindow() for precise rotation timer. |
| `lib/screens/battery_check_screen.dart` | Checks battery_plus level. Blocks if < 50%. Navigates via pushReplacement to EventListScreen. |
| `lib/screens/event_list_screen.dart` | Fetches events (status=upcoming/live) from Supabase. Handles ticket INSERT with duplicate check. AppBar has My Tickets icon. |
| `lib/screens/my_tickets_screen.dart` | Fetches tickets for current attendee_id joined with event data. Lists tickets. Tapping navigates to TicketDetailScreen. |
| `lib/screens/ticket_detail_screen.dart` | Renders ticket_code as QR via qr_flutter. Shows event details and ticket status. Reached at Event button triggers pushAndRemoveUntil to AdvertiserScreen. |
| `android/app/src/main/AndroidManifest.xml` | BLE permissions (BLUETOOTH_ADVERTISE, BLUETOOTH_CONNECT), FOREGROUND_SERVICE_CONNECTED_DEVICE, POST_NOTIFICATIONS, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, INTERNET. Declares BleAdvertisingService with foregroundServiceType=connectedDevice. |

### volunteer_mobile

| File | Purpose |
|---|---|
| `lib/main.dart` | App entry point. Initialises Supabase via TelemetryService.init(). Root widget is _AuthGate (StreamBuilder on auth state) routing between Login/Battery/EventPicker/ZoneSelection/Scan. |
| `lib/config/supabase_config.dart` | GITIGNORED. Holds supabaseUrl and supabaseAnonKey constants. |
| `lib/models/ble_observation.dart` | BleObservation data class with fields: ephemeralId, rssi, isSpatiallyDevice, volunteerId, zone, eventId, scannedAt. toMap() for Supabase insert. |
| `lib/services/session_state.dart` | Singleton. In-memory store for volunteerId, eventId, zone, batteryChecked, syncRateSeconds. Cleared on logout. |
| `lib/services/ble_scanner_service.dart` | Core scan logic. Manages FlutterBluePlus stream, UUID filter, sticky classification, ephemeral ID extraction from manufacturer data (0xFFFF), 10s dedup, 45s expiry, 30s hardware restart timer, observation dispatch via scheduleMicrotask, volunteer_counts timer. |
| `lib/services/telemetry_service.dart` | Supabase client wrapper. sendObservation() delegates to ObservationQueue.sendOrQueue(). updateVolunteerCount() upserts volunteer_counts. Initialised as singleton. |
| `lib/services/observation_queue.dart` | SQLite-backed write-behind queue (spatially_queue.db, table pending_observations). sendOrQueue() tries direct Supabase insert, falls back to local INSERT on failure. Flush triggered on startup and connectivity regain via connectivity_plus. |
| `lib/screens/battery_check_screen.dart` | Same pattern as attendee — 50% gate, pushReplacement to EventPickerScreen. |
| `lib/screens/login_screen.dart` | Email/password form. Supabase signInWithPassword. Password visibility toggle. On success, AuthGate routes to BatteryCheckScreen. |
| `lib/screens/event_picker_screen.dart` | Queries volunteer_assignments JOIN events for logged-in user. Lists events. On tap, sets SessionState.eventId and navigates to ZoneSelectionScreen. |
| `lib/screens/zone_selection_screen.dart` | Fetches selected event zones TEXT[] from Supabase. Lists zones. On tap, sets SessionState.zone and navigates to ScanScreen. |
| `lib/screens/scan_screen.dart` | Main scan UI. Start/Stop scan control, BT gate overlay, live dual counters (active Spatially / total unique), configurable sync rate dropdown, scrollable observation list (capped 50), QR scanner AppBar button, logout. |
| `lib/screens/qr_scanner_screen.dart` | Camera QR scanner via mobile_scanner. On decode, queries tickets by ticket_code + event_id, validates status=purchased, UPDATEs to checked_in. |
| `android/app/src/main/AndroidManifest.xml` | BLE permissions (BLUETOOTH_SCAN neverForLocation, BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION), FOREGROUND_SERVICE_CONNECTED_DEVICE, POST_NOTIFICATIONS, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, INTERNET. Declares ForegroundService. |

### flutter_ble_peripheral_patched (attendee only)

| File | Purpose |
|---|---|
| `BleAdvertisingService.kt` | Native Android connectedDevice FGS. Owns BluetoothLeAdvertiser. Reads EPHEMERAL_ID from Intent extra (12-char hex string), builds AdvertiseData with service UUID f47ac10b-... and manufacturer data (company 0xFFFF + 6 bytes). Persists through screen lock. |
| `FlutterBlePeripheralPlugin.kt` | Adds ble_service MethodChannel for startBleAdvertisingService / stopBleAdvertisingService. Stores activeAdvertisingSet; on stop calls enableAdvertising(false, 0, 0) before stopAdvertisingSet(). Nulls callback reference on stop. |
| `PeripheralAdvertisingSetCallback.kt` | hasReplied: Boolean guard added to onAdvertisingSetStarted to prevent Reply already submitted IllegalStateException on Android 14. |

### supabase/ (inside volunteer_mobile)

| File | Purpose |
|---|---|
| `schema.sql` | v1: Creates observations table (id, created_at, ephemeral_id, rssi, scanned_at, is_spatially_device). |
| `schema_v2_volunteer_zone.sql` | Adds volunteer_id (FK auth.users) and zone TEXT to observations. |
| `schema_v3_volunteer_counts.sql` | Creates volunteer_counts table (volunteer_id PK, zone, active_count, updated_at). |
| `schema_v4_events_tickets.sql` | Creates events, tickets, volunteer_assignments. Adds event_id FK to observations and volunteer_counts. |

---

## 8. Spatially Service UUID

Custom BLE service UUID used by both apps:
`f47ac10b-58cc-4372-a567-0e02b2c3d479`

This UUID is hardcoded in:
- attendee_mobile: BleAdvertisingService.kt (advertised)
- volunteer_mobile: ble_scanner_service.dart (filter for classification)

If changed, must be updated in both places simultaneously.
