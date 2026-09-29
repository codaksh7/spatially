# Spatially — Current Project State & Handoff Baseline

> **Snapshot Date:** September 29, 2026  
> **Status:** Mobile & Operational Backend Complete — Ready for Organizer Web Integration  
> **Branch:** `main`

---

## 1. Executive Summary

The **Attendee Mobile** and **Volunteer Mobile** applications, along with the shared **Supabase PostgreSQL Database**, are fully built, unit-tested, and verified on physical Android hardware (Nothing Phone A059P).

The **Organizer Web Platform** (`client/` and `server/`) has a solid foundation created by the Organizer team (React frontend, FastAPI backend, Brevo email invites, and preliminary auth). The immediate next milestone is connecting the Organizer Dashboard to the live operational database and RPCs built during the mobile operational phases.

---

## 2. Completed Milestones

### 2.1 Attendee Mobile (`apps/attendee_mobile`)
- **Ticketing & Admission:** QR ticket presentation with dynamic cryptographic codes, offline caching, and guest-to-account ticket claiming.
- **BLE Telemetry:** Native Android Foreground Service continuously broadcasting a 15-minute rotating ephemeral BLE identifier for privacy-preserving crowd density tracking.
- **Live Event Experience (Phase 7C):** Time-aware session schedules with real-time precedence (`upcoming`, `live`, `completed`), venue maps, booth discovery, and live crowd freshness indicators.
- **Gamification & Passport (Phase 7B):** Passport activity completion, booth check-ins, and reward milestones.
- **Ephemeral Connect (Phase 6B):** Proximity-based attendee discovery, connection requests, and temporary event chat.
- **Test Baseline:** 81/81 unit/integration tests passing. 0 analyzer errors.

### 2.2 Volunteer Mobile (`apps/volunteer_mobile`)
- **Ticket Check-In (Block 1):** Real-time camera QR scanner with offline write queue, duplicate detection, and fast reconciliation.
- **Crowd Scanning (Block 2):** Background BLE scanner service with local SQLite buffering, batch upserts, and stale count pruning.
- **Operational Communications (Block 2.5A):** Broadcast announcements, team messages, zone-filtered chat, direct 1-on-1 threads, and emergency acknowledgment receipts.
- **Incidents & Assistance (Block 2.5B):** Full incident reporting, dispatching, first-responder assignment, status logs, attendee help requests, and Lost & Found custody workflows.
- **Teams, Shifts & Coverage (Block 2.5C):** Active shift tracking, break timer state machine, peer/supervisor coverage requests, task assignment, and shift handoffs.
- **Event Awareness & Attention Engine (Block 2.5D):** Multi-source event normalization, deterministic relevance scoring (`myZone`, `myTeam`, `eventWideUrgent`), SQLite v7 caching, and pocket-friendly waveform haptic alerts.
- **Operational Health & Telemetry (Block 2.5E):** Real-time metrics dashboard, zone health matrix, and response time KPIs.
- **Test Baseline:** 124/124 unit/integration tests passing. 0 analyzer errors.

### 2.3 Shared Database & Backend (`supabase/migrations/`)
- All 19 sequential SQL migrations applied and verified in Supabase (`bajrtiiqwqvblnbtuhvw`).
- Full Row Level Security (RLS) policies implemented and enforced across all operational tables.
- Comprehensive RPC suite implemented:
  - `get_event_operational_health`: Aggregated health index and per-zone metrics.
  - `get_event_operational_timeline`: Unified chronological operational stream.
  - `check_in_ticket`: Atomic admission check-in.
  - Team, shift, break, coverage, task, and message management functions.

---

## 3. Current Organizer Web Platform Status (`client/` and `server/`)

### Frontend (`client/`)
- Vite + React 18 application initialized.
- Authentication pages and contexts implemented.
- Event creation and volunteer invitation screens implemented.
- **Pending Work:**
  - Wire `OrganizerDashboard.jsx` to live `get_event_operational_health` RPC.
  - Wire live crowd heatmap to `volunteer_counts` / `zones` data.
  - Wire incident command table to `operational_incidents` with Supabase Realtime CDC subscription.
  - Wire live activity timeline to `get_event_operational_timeline`.

### Backend API (`server/`)
- FastAPI service with Brevo email invitation system.
- Pydantic models and basic CRUD routes.
- Web authentication system (`web_users` table).
- **Pending Work:**
  - Align `server/database/schema.sql` extensions with `supabase/migrations/` if running migrations from Supabase CLI.
  - Support event metrics endpoints calling the Supabase RPCs.

---

## 4. Test & Verification Baseline

| Test Suite | Tests Run | Passed | Failed | Status |
| :--- | :---: | :---: | :---: | :--- |
| **Attendee Mobile Suite** | 81 | 81 | 0 | **PASS** |
| **Volunteer Mobile Suite** | 124 | 124 | 0 | **PASS** |
| **Flutter Static Analysis** | 2 Apps | 0 Issues | 0 Issues | **CLEAN** |
| **Hardware Verification** | Nothing Phone A059P | Verified | 0 Regressions | **VERIFIED** |

---

## 5. Architectural Boundaries & Conventions

1. **No Application Code Modifications During Handoff:** Mobile apps and migrations are locked at their tested baseline.
2. **Unified Supabase Backend:** Do not spin up separate databases for Organizer Web. Use the existing Supabase instance.
3. **No Direct Attendee Tracking:** Individual attendee locations are never tracked or exposed. Only aggregated zone counts and rotating ephemeral BLE IDs are processed to guarantee user privacy.
4. **Deterministic Status Derivation:** Both mobile apps and the dashboard must derive statuses (e.g., session live state, crowd freshness, attention level) deterministically using canonical timestamps and thresholds rather than arbitrary client timers.

---

## 6. Next Immediate Steps for the Organizer Team

1. Read `ORGANIZER_HANDOFF.md` and `DATABASE_AND_RPC_REFERENCE.md`.
2. Configure local `.env` files in `client/` and `server/` using `.env.example` templates.
3. Start the Vite frontend (`npm run dev`) and test connecting to Supabase using `VITE_SUPABASE_ANON_KEY`.
4. Replace placeholder dashboard metrics in `client/src/pages/OrganizerDashboard.jsx` with live calls to `supabase.rpc('get_event_operational_health', { p_event_id })`.
5. Subscribe to Supabase Realtime events for live incident updates.
