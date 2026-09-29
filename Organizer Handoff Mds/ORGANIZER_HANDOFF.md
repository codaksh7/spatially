# Spatially — Organizer Web Handoff & Architecture Guide

> **Target Audience:** Organizer Web Engineering Team (`client/`, `server/`)  
> **Status:** Active Shared Baseline  
> **Last Updated:** September 29, 2026  
> **Repository Context:** Root / `Organizer Handoff Mds/`

---

## 1. Project Overview

**Spatially** is an event operations and spatial crowd intelligence platform designed to seamlessly connect three core stakeholders:
1. **Attendees:** Discover events, hold cryptographically signed tickets, navigate venue zones, participate in gamified event passports, chat ephemerally, and broadcast secure, rotating BLE signals.
2. **Volunteers / Event Staff:** Scan QR tickets at gates, continuously collect crowd presence via BLE scans, exchange operational radio-style communications, resolve incidents, handle lost & found items, coordinate shifts/coverage, and monitor real-time event awareness feeds.
3. **Organizers:** Plan and configure events, define venue zones, manage volunteer invitations and assignments, oversee real-time crowd distribution, and monitor operational health across all zones.

The platform is designed around **offline-resilient operations, deterministic operational status derivation, privacy-preserving proximity telemetry, and Supabase as the unified backend & real-time message bus.**

---

## 2. Repository Structure

```
majorProject/
├── apps/
│   ├── attendee_mobile/          # Flutter (Dart) mobile app for event attendees (Android)
│   ├── volunteer_mobile/         # Flutter (Dart) mobile app for staff/volunteers (Android)
│   └── flutter_ble_peripheral_patched/ # Local patched BLE peripheral plugin for Android
├── client/                       # Organizer Web Dashboard (React + Vite)
├── server/                       # Organizer Web Backend API (Python / FastAPI)
├── supabase/
│   └── migrations/               # PostgreSQL DDL migrations, RLS policies, indexes, RPCs
├── Organizer Handoff Mds/        # Curated handoff documentation for Organizer Web
└── README.md                     # Root entrypoint
```

---

## 3. Surface Responsibilities

| Responsibility Area | Attendee Mobile | Volunteer Mobile | Organizer Web / Server |
| :--- | :--- | :--- | :--- |
| **User Authentication** | Supabase Auth (Email + OTP/Password) or Guest Device ID | Supabase Auth (Email/Password, staff roles) | `web_users` table + JWT via FastAPI / Supabase Auth |
| **Ticketing / Admission** | Purchases tickets, presents dynamic QR code | Scans QR, executes `check_in_ticket`, verifies admission | Creates ticket tiers, views check-in stats & velocity |
| **Proximity Telemetry** | Broadcasts rotating ephemeral BLE payload (Foreground Service) | Scans BLE advertisements, buffers in SQLite, flushes to `observations` & `volunteer_counts` | Views zone density, crowd heatmaps, dwell times, and congestion |
| **Zone Context** | Reads zone layouts, booth locations, map pins | Selects active operational zone for duty attribution | Configures event zones, spatial bounds, and capacity limits |
| **Operational Comms** | None (Attendee privacy isolation) | Sends/receives team broadcasts, emergency alerts, direct threads | Can send event-wide organizer broadcasts & emergency alerts |
| **Incidents & Assistance**| May flag lost items or emergency SOS requests | Logs, updates, escalates, and resolves incidents in real time | Monitors active incidents, dispatch logs, and resolution times |
| **Lost & Found** | Views public catalog of found items | Registers found/lost items, tags custody, matches claims | Oversees high-value claims, returns, and inventory audit |
| **Staff & Shifts** | None | Logs shifts, requests breaks, requests coverage, accepts tasks | Invites volunteers via email, views roster, monitors coverage |
| **Operational Health** | None | Views local zone awareness feed, attention cards, and telemetry | Consumes aggregated event health RPCs (`get_event_operational_health`) |

---

## 4. Existing Organizer Codebase (`client/` and `server/`)

The repository already contains initial Organizer Web platform implementations created by the Organizer team:

### Frontend: `client/` (React + Vite)
- **Framework:** React 18 with Vite build tooling, React Router DOM, and Tailwind-based styling in `index.css`.
- **Authentication:** `src/context/AuthContext.jsx` manages user state, tokens, and role routing (`user`, `volunteer`, `organizer`).
- **Pages Implemented:**
  - `Landing.jsx`: Product landing page.
  - `Login.jsx` / `Signup.jsx` / `VerifyEmail.jsx` / `ForgotPassword.jsx` / `ResetPassword.jsx`: Web user auth flows.
  - `OrganizerDashboard.jsx`: High-level organizer home with event overview.
  - `OrganizerEvents.jsx` / `CreateEvent.jsx` / `EventDetail.jsx`: Event creation and management.
  - `InviteVolunteer.jsx` / `VolunteerAssignments.jsx`: Staff invitation and zone assignment interfaces.
  - `UserDashboard.jsx` / `VolunteerDashboard.jsx`: Role-specific landing views.
- **API Utilities:** `src/utils/api.js` points to the Python backend API (`http://localhost:8000/api` or configured base).

### Backend: `server/` (Python + FastAPI)
- **Framework:** FastAPI with Uvicorn, Pydantic data schemas in `models.py`.
- **Database Client:** Supabase Python SDK (`supabase-py`) initialized in `config.py`.
- **Email Service:** `services/email.py` configured with Brevo API for transactional emails (verification, volunteer invitations).
- **Routes:**
  - `routes/auth.py`: Web user signup, login, email verification, password reset, token validation.
  - `routes/events.py`: Create, read, update, delete events.
  - `routes/volunteers.py`: Send volunteer email invitations, handle invitation acceptance/rejection, assign zones.
  - `routes/dashboard.py`: Organizer metrics summary.
- **Web Database Schema:** Initial schema in `server/database/schema.sql` defining `web_users`, `event_invitations`, and `web_volunteer_assignments`.

---

## 5. Shared Supabase Foundation

All three surfaces share a single Supabase project. The database acts as both the authoritative persistence layer and the real-time event broker.

- **Postgres DDL Migrations:** Maintained chronologically in `supabase/migrations/`.
- **Row Level Security (RLS):** All operational tables enforce RLS policies restricting read/write access by role and event scope.
- **Realtime CDC:** PostgreSQL replication is enabled on critical operational tables (`operational_incidents`, `operational_messages`, `supervisor_tasks`, `coverage_requests`, `volunteer_counts`, etc.).

---

## 6. Event & Zone Model

### Events (`events` table)
- Primary Key: `id` (UUID).
- Core fields: `name`, `venue`, `date`, `zones` (JSON/text array), `description`, `capacity`, `organizer_id`, `start_time`, `end_time`, `location_address`.
- Relationships: Parent to all operational tables (`tickets`, `event_teams`, `event_zones`, `operational_incidents`, etc.).

### Zones (`event_zones` table & `events.zones`)
- Defined by the organizer with attributes: `name`, `code`, `capacity_limit`, `is_active`, `sort_order`, `polygon_coordinates` (or bounding box).
- In the mobile apps, volunteers pick an active operational zone (e.g., `Main Gate`, `Hall A`, `Food Court`).
- Attendee BLE observations and incident logs are attributed to the volunteer's active zone.

---

## 7. Crowd & Telemetry System

The crowd telemetry pipeline operates as follows:
```
[Attendee Mobile]
   │  (Passive BLE advertising with 15-min rotating Ephemeral ID)
   ▼
[Volunteer Mobile Scanners]
   │  (Passive BLE scanning in background/foreground service)
   ▼
[Local SQLite Buffer on Volunteer Phone]
   │  (Batched flushes every 15-30s; dedupes device observations)
   ▼
[Supabase: observations & volunteer_counts]
   │  (Active device counts recorded per volunteer, zone, and event)
   ▼
[Organizer Dashboard: Real-time Heatmap / Zone Occupancy]
```

### Key Concept: Deduplicated Real-time Counts
The `volunteer_counts` table stores active counts. For global zone-level aggregations without double-counting volunteers in the same zone, use the database RPC:
- `get_zone_crowd_summary(p_event_id UUID)` or
- `get_event_operational_health(p_event_id UUID) -> jsonb`

---

## 8. Volunteer Staff & Operational Systems

### Teams & Shifts (`event_teams`, `volunteer_shifts`, `volunteer_assignments`)
- Volunteers belong to an `event_team` (e.g., Medical, Security, Ticketing, Logistics, Guest Services).
- Shifts track `status` (`scheduled`, `checked_in`, `on_break`, `completed`, `no_show`), start/end timestamps, assigned zone, and breaks.
- Handoff logs (`shift_handoffs`) allow outgoing volunteers to transfer operational notes, unresolved items, and equipment status to incoming staff.

### Coverage Requests (`coverage_requests`)
- Volunteers needing relief (break, emergency, zone assistance) emit a coverage request with status `pending`, `accepted`, `completed`, or `cancelled`.
- Supervisors or available team members claim coverage.

### Supervisor Tasks (`supervisor_tasks`)
- Organizers or team leads dispatch ad-hoc tasks (e.g., "Replenish water at Booth 4", "Check exit door 3").
- Tasks have priorities (`urgent`, `high`, `normal`, `low`) and statuses (`assigned`, `acknowledged`, `in_progress`, `completed`, `cancelled`).

---

## 9. Communication System (`operational_messages`)

The communication system provides radio-style broadcast and targeted messaging across operational staff:
- **Channels:**
  - `all`: Event-wide broadcast.
  - `team`: Scoped to a specific `team_id`.
  - `zone`: Scoped to volunteers active in a `zone_id`.
  - `direct`: 1-on-1 direct thread between two volunteers.
  - `emergency`: Highest priority broadcast requiring mandatory staff acknowledgment.
- **Priority:** `routine`, `important`, `urgent`.
- **Deduplication & Realtime:** Subscribed to via Supabase Realtime channel `volunteer_messages_{eventId}`.

---

## 10. Incidents & Attendee Assistance

### Operational Incidents (`operational_incidents`)
- Represents operational, safety, medical, or crowd issues.
- Fields: `id`, `event_id`, `zone`, `category` (`medical`, `security`, `crowd`, `infrastructure`, `lost_person`, `other`), `severity` (`low`, `medium`, `high`, `critical`), `status` (`reported`, `dispatched`, `in_progress`, `resolved`, `cancelled`), `reported_by`, `assigned_to`, `title`, `description`.
- Real-time updates trigger awareness items and attention alerts across volunteer devices.

### Lost & Found (`lost_found_items`)
- Manages misplaced attendee property and custody.
- Fields: `item_type`, `category`, `description`, `color`, `location_found`, `status` (`registered`, `in_custody`, `matched`, `claimed`, `disposed`), `custody_holder_id`, `claimed_by_name`, `claimed_by_contact`.

---

## 11. Operational Health & Analytics for Organizer Web

The database includes pre-built operational rollup RPCs designed specifically for Organizer Web consumption:

### `get_event_operational_health(p_event_id UUID) -> JSONB`
Returns a unified operational health snapshot in a single round-trip:
- `summary`: Overall health index (`good`, `warning`, `critical`), active volunteers count, total active incidents, open coverage requests.
- `zones`: Array of zone statistics (zone name, active volunteer count, crowd density status, active incident count).
- `incidents`: Breakdown by severity and category.
- `shifts`: Breakdown by shift status (`checked_in`, `on_break`, etc.).
- `tasks`: Pending vs completed tasks count.

### `get_event_operational_timeline(p_event_id UUID, p_limit INT) -> JSONB`
Returns a chronological stream of operational events across all subsystems (incidents, shift changes, coverage claims, emergency broadcasts) suitable for an Organizer Live Activity Feed.

---

## 12. Security & RLS Expectations

1. **Service Role Key:** Kept strictly server-side in `server/.env`. Never expose `SUPABASE_SERVICE_KEY` in frontend bundles.
2. **Frontend Client:** Uses `VITE_SUPABASE_ANON_KEY`. Read operations and user-authorized mutations execute under RLS.
3. **Database Roles:**
   - Public/Anon: Ticket purchase, public event details, found item inquiry.
   - Authenticated User: Attendee tickets, gamification passport, Connect profile.
   - Volunteer / Staff: Operational tables (`observations`, `incidents`, `shifts`, `messages`, `tasks`).
   - Organizer / Service Role: Full administrative write access across events, teams, and analytics.

---

## 13. What Organizer Web Should Consume vs NOT Duplicate

### DO CONSUME:
- Use `supabase/migrations/` as the single authoritative database schema.
- Call pre-built database functions: `get_event_operational_health`, `get_event_operational_timeline`, `get_zone_crowd_summary`.
- Subscribe to Supabase Realtime CDC channels for live dashboard widgets (`operational_incidents`, `volunteer_counts`, `operational_messages`).
- Query `events`, `event_zones`, `event_teams`, `volunteer_shifts`, `tickets`, `operational_incidents`.

### DO NOT DUPLICATE:
- Do NOT write custom background polling workers to recalculate crowd densities or incident tallies; use the Postgres RPCs.
- Do NOT create a separate parallel ticketing or incident database; all data resides in the shared Postgres database.
- Do NOT reinvent BLE telemetry models; consume the aggregated `volunteer_counts` and RPC rollups.

---

## 14. Development Guidelines & Next Steps for Organizer Web

1. **Configure Environment:**
   - Copy `client/.env.example` to `client/.env` and supply `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
   - Copy `server/.env.example` to `server/.env` and supply `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, and email API keys.
2. **Review Database Reference:**
   - Read `DATABASE_AND_RPC_REFERENCE.md` for full schema signatures and parameter definitions.
3. **Connect Dashboard to Live Health RPCs:**
   - Replace any mock data in `OrganizerDashboard.jsx` with calls to `supabase.rpc('get_event_operational_health', { p_event_id: currentEventId })`.
4. **Subscribe to Realtime Events:**
   - Wire Supabase Realtime listeners on `operational_incidents` to auto-update incident feeds without manual refresh.
