# SPATIALLY — ORGANIZER PLATFORM & INTELLIGENCE ENGINE MASTER REQUIREMENTS SPECIFICATION

**Document Reference:** `ORGANIZER_AND_INTELLIGENCE_MASTER_REQUIREMENTS.md`  
**System Classification:** System Architecture, Functional Specification & Data Blueprint  
**Target Repository:** `majorProject` (`aryan-oo9/spatially`)  
**Target Systems:**  
1. **Organizer Platform** (`client/` React/Vite Web Platform & `server/` FastAPI Service Layer)  
2. **Spatially Intelligence Engine** (Cross-System ML/Predictive & Context Analytics Service)  
3. **Attendee & Volunteer Mobile Integration Bridges** (`apps/attendee_mobile` & `apps/volunteer_mobile`)  
**Backend Anchor:** Hosted Supabase PostgreSQL (`bajrtiiqwqvblnbtuhvw.supabase.co`, Region: `ap-south-1`)  
**Document Status:** **FINAL MASTER SPECIFICATION — COMPLETE & LOCKED**  
**Execution Directives:** **FORENSIC AUDIT & ARCHITECTURAL SPECIFICATION ONLY — ZERO APPLICATION CODE MUTATIONS**

---

## TABLE OF CONTENTS

1. [Executive Summary](#1-executive-summary)
2. [Current System Inventory](#2-current-system-inventory)
3. [Existing Attendee Capabilities](#3-existing-attendee-capabilities)
4. [Existing Volunteer Capabilities](#4-existing-volunteer-capabilities)
5. [Existing Backend/Data Capabilities](#5-existing-backenddata-capabilities)
6. [Demo / Hardcoded Data Audit](#6-demo--hardcoded-data-audit)
7. [Production Data Source Mapping](#7-production-data-source-mapping)
8. [Organizer System Overview](#8-organizer-system-overview)
9. [Organizer Dashboard Requirements](#9-organizer-dashboard-requirements)
10. [Event Management](#10-event-management)
11. [Zone Management](#11-zone-management)
12. [Crowd Monitoring](#12-crowd-monitoring)
13. [Volunteer Management](#13-volunteer-management)
14. [Incident Management](#14-incident-management)
15. [Assistance Management](#15-assistance-management)
16. [Task Management](#16-task-management)
17. [Communication](#17-communication)
18. [Notifications & Alerts](#18-notifications--alerts)
19. [Map / Event Awareness](#19-map--event-awareness)
20. [Analytics](#20-analytics)
21. [System Administration](#21-system-administration)
22. [Organizer Intelligence](#22-organizer-intelligence)
23. [Spatially Intelligence Engine Overview](#23-spatially-intelligence-engine-overview)
24. [Intelligence Inputs](#24-intelligence-inputs)
25. [Behavioral Intelligence](#25-behavioral-intelligence)
26. [Personalization](#26-personalization)
27. [Recommendation Engine](#27-recommendation-engine)
28. [Smart Itineraries](#28-smart-itineraries)
29. [Crowd-Aware Intelligence](#29-crowd-aware-intelligence)
30. [Notification Intelligence](#30-notification-intelligence)
31. [Prediction](#31-prediction)
32. [Anomaly Detection](#32-anomaly-detection)
33. [Volunteer Intelligence](#33-volunteer-intelligence)
34. [Organizer Intelligence](#34-organizer-intelligence)
35. [AI Assistant](#35-ai-assistant)
36. [Feedback / NLP](#36-feedback--nlp)
37. [Intelligence Architecture](#37-intelligence-architecture)
38. [Cross-System Data Flow](#38-cross-system-data-flow)
39. [Backend / Database Requirements](#39-backend--database-requirements)
40. [Security & Authorization](#40-security--authorization)
41. [Organizer Screen Inventory](#41-organizer-screen-inventory)
42. [Intelligence Component Inventory](#42-intelligence-component-inventory)
43. [Implementation Phases](#43-implementation-phases)
44. [Current → Target System Mapping](#44-current--target-system-mapping)
45. [Demo → Production Cleanup Checklist](#45-demo--production-cleanup-checklist)
46. [Gap Analysis](#46-gap-analysis)
47. [Dependencies](#47-dependencies)
48. [Risks / Unknowns](#48-risks--unknowns)
49. [Explicitly Out-of-Scope Items](#49-explicitly-out-of-scope-items)
50. [Final Implementation Checklist](#50-final-implementation-checklist)

---

## 1. EXECUTIVE SUMMARY

### 1.1 Document Purpose
This document constitutes the definitive engineering and product specification for the two final core tiers of the Spatially platform:
1. **The Organizer Platform:** A mission-critical command, control, configuration, and monitoring portal for physical event directors, stage managers, crowd safety chiefs, and volunteer coordinators.
2. **The Spatially Intelligence Engine:** A cross-platform, multi-level intelligence service providing privacy-preserving spatial-temporal recommendations, predictive crowd congestion modeling, smart routing, dynamic dispatch, and contextual conversational assistance.

### 1.2 Status of the Existing Codebase
As of October 2026, the Spatially repository has successfully achieved production validation across mobile client tiers:
- **`apps/attendee_mobile` (Phases 1–7C):** 100% production-ready Flutter app featuring anonymous Bluetooth Low Energy (BLE) ephemeral advertising, indoor multi-level vector mapping, live gamification/passport ledger, dynamic schedules, and attendee assistance channels.
- **`apps/volunteer_mobile` (Blocks 1–2.5E):** Production-hardened Flutter app featuring real-time BLE scanning, SQLite durable offline outbox, atomic QR ticket admission, staff operational messaging, incident lifecycle tracking, shift management, and event awareness telemetry.
- **`client/` (Prototype Web Platform):** A React/Vite web application providing early organizer pages (dashboard, event creation, map placement, volunteer invites) but currently relying on a fragmented web-specific user table (`web_users`), static JSON layout files (`venue_layouts.json`), and partial Supabase queries.
- **`server/` (FastAPI Service Layer):** A Python backend with JWT authentication, basic REST routes, and direct Supabase database interactions, which currently mirrors web prototype logic rather than orchestrating the complete production database schema.

### 1.3 Architectural Vision
The Spatially platform transforms physical venues into responsive, intelligent environments. By bridging edge mobile sensing (attendees and volunteers) with real-time operational coordination (organizers) and automated spatial analytics (the Intelligence Engine), Spatially eliminates the chaos of large-scale physical events without compromising user privacy.

```
       ┌────────────────────────────────────────────────────────┐
       │                 HOSTED SUPABASE TIER                   │
       │   27 Production PostgreSQL Tables • RPCs • Realtime    │
       └───────▲──────────────────────▲──────────────────▲──────┘
               │                      │                  │
    ┌──────────┴────────┐   ┌─────────┴─────────┐   ┌────┴───────────────┐
    │  ATTENDEE MOBILE  │   │  VOLUNTEER MOBILE │   │ ORGANIZER PLATFORM │
    │ (Flutter Android) │   │ (Flutter Android) │   │    (React/Vite)    │
    │  BLE Advertiser   │   │    BLE Scanner    │   │  Command & Control │
    │  Indoor Map / QRs │   │  Offline Outbox   │   │  Venue Topologies  │
    └──────────▲────────┘   └─────────▲─────────┘   └────▲───────────────┘
               │                      │                  │
               └──────────────┬───────┴──────────────────┘
                              │
               ┌──────────────▼─────────────────┐
               │  SPATIALLY INTELLIGENCE ENGINE │
               │   (FastAPI / Python Service)   │
               │  Rules → ML Recs → Predictions │
               └────────────────────────────────┘
```

---

## 2. CURRENT SYSTEM INVENTORY

### 2.1 Repository Structure
```
d:\majorProject\
├── apps\
│   ├── attendee_mobile\     [EXISTING] [REAL] Production Flutter app for attendees
│   └── volunteer_mobile\    [EXISTING] [REAL] Production Flutter app for staff/volunteers
├── client\                  [EXISTING] [PARTIAL] React 19 / Vite web client prototype
├── server\                  [EXISTING] [PARTIAL] FastAPI Python server & legacy REST API
├── Required Mds\            [EXISTING] [REAL] Authoritative architectural blueprint library
└── Volunteer SS\            [EXISTING] [REAL] 46 Physical device UI verification screenshots
```

### 2.2 System Component Classification Matrix

| Component | Code Location | Current State | Target State | Primary Dependencies |
|---|---|---|---|---|
| **Attendee Shell & Nav** | `apps/attendee_mobile/lib/` | `[EXISTING]` `[REAL]` | Production Ready | Flutter 3.x, Provider, GoRouter |
| **Attendee Vector Map** | `apps/attendee_mobile/lib/features/map/` | `[EXISTING]` `[REAL]` | Production Ready | `venue_map_repository`, CustomPainter |
| **Attendee Passport** | `apps/attendee_mobile/lib/features/passport/` | `[EXISTING]` `[REAL]` | Production Ready | `attendee_engagements` RPCs |
| **Volunteer Scanner** | `apps/volunteer_mobile/lib/services/` | `[EXISTING]` `[REAL]` | Production Ready | `flutter_blue_plus`, Foreground Task |
| **Volunteer Incidents** | `apps/volunteer_mobile/lib/repositories/` | `[EXISTING]` `[REAL]` | Production Ready | `operational_incidents`, Realtime |
| **Volunteer Shifts** | `apps/volunteer_mobile/lib/repositories/` | `[EXISTING]` `[REAL]` | Production Ready | `volunteer_shifts`, SQLite v7 |
| **Organizer Web Shell** | `client/src/components/DashboardLayout.jsx` | `[EXISTING]` `[PARTIAL]` | Redesign to Command Hub | React 19, Lucide Icons |
| **Organizer Map Canvas** | `client/src/components/VenueMap.jsx` | `[EXISTING]` `[DEMO / HARDCODED]` | Production Multi-Level Editor | SVG Overlay, `stadium_map_bg.png` |
| **Organizer API Routes** | `server/routes/` | `[EXISTING]` `[PARTIAL]` | Full Service Gateway | FastAPI, Pydantic, Supabase-py |
| **Intelligence Engine** | *None* | `[PROPOSED / NEW]` | Multi-Level Python Service | scikit-learn, networkx, PyTorch/Lite |

---

## 3. EXISTING ATTENDEE CAPABILITIES

### 3.1 Implemented & Production-Verified Features
1. **Identity & Ephemeral Privacy:**
   - Client generates a persistent UUID v4 device identity stored in `SharedPreferences` (`AttendeeIdentity.deviceId`).
   - Generates rolling 5-minute SHA-256 rotating ephemeral IDs broadcast as BLE manufacturer data (`0xFFFF`).
   - Guest ticket provisioning allows immediate offline check-in, with atomic account migration via `claim_guest_ticket` RPC.
2. **Interactive Multi-Level Spatial Map:**
   - Multi-floor indoor topology loaded via `SupabaseVenueMapRepositoryImpl` (`venues`, `venue_levels`, `venue_zones`, `venue_pois`).
   - Live crowd congestion heatmaps powered by real-time `volunteer_counts` bridge.
   - Offline fallback caching via `EventCacheManager` with clear visual degradation indicator.
3. **Engagement, Gamification & Passport:**
   - Ledger-backed point economy via `attendee_engagements` table with composite unique constraint `(event_id, attendee_id, engagement_type, reference_id)`.
   - Verified check-ins, booth visits (0 pts), session attendances (0 pts), and interactive challenge verification (`verify_activity_completion` RPC).
4. **Safety & Help Systems:**
   - Attendee assistance dispatch dialog (`AttendeeAssistanceDialog`) invoking `request_attendee_assistance` RPC.
   - Event-scoped Lost & Found feed (`lost_found_reports`) with personal item submission and offline queueing.
5. **Ephemeral Networking (Connect):**
   - Mutual opt-in discovery via `attendee_connections` table.
   - 1000-character bounded real-time chat with physical meeting point selection (`venue_pois`).

---

## 4. EXISTING VOLUNTEER CAPABILITIES

### 4.1 Implemented & Production-Verified Features
1. **Hardware BLE Scanning & Crowd Telemetry:**
   - Foreground-service Android BLE scanning with 10-second deduplication and 45-second device expiry.
   - Privacy gate dropping all non-Spatially ambient devices prior to queueing or cloud sync.
   - Upserting zone crowd density to `volunteer_counts` with automatic server-side staleness purging (`clean_stale_volunteer_counts` RPC).
2. **Offline Outbox & Atomic Ticketing:**
   - SQLite-backed write-behind observation queue (`spatially_queue.db`, schema v7).
   - Atomic QR ticket validation via `check_in_ticket` RPC with PostgreSQL row-level locking (`FOR UPDATE`).
   - Durable offline check-in queue (`pending_ticket_checkins`) with automatic connectivity auto-flush.
3. **Operational Incidents & Lost/Found Management:**
   - Comprehensive incident intake supporting 5 categories and 3 priority tiers.
   - Atomic incident claiming via `assign_operational_incident` RPC with concurrency collision detection.
   - Direct Lost & Found logging and status transitions (`update_lost_found_status` RPC).
4. **Shift, Team & Supervisor Operations:**
   - Authoritative shift state machine (`scheduled`, `active`, `on_break`, `completed`) via `volunteer_shifts`.
   - Station coverage requests with atomic mutual claiming (`accept_shift_coverage` RPC).
   - Shift handoff turnover recording unresolved incidents and tasks (`shift_handoffs`).
5. **Operational Health & Event Awareness Feed:**
   - Multi-source awareness aggregator normalizing broadcasts, crowd surges, incidents, and tasks.
   - Pocket-friendly custom Android waveform haptics (`HapticAttentionService`).
   - Live operational health calculation via `get_event_operational_health` RPC and local deterministic fallbacks.

---

## 5. EXISTING BACKEND/DATA CAPABILITIES

### 5.1 Authoritative Production Supabase Schema (27 Tables)
The hosted Supabase PostgreSQL instance (`bajrtiiqwqvblnbtuhvw`) maintains 27 tables with Row Level Security (RLS) enabled:

```
Core Entities:
├── profiles (Attendee social profiles & server-enforced role)
├── events (Central event registry with venue FK)
├── tickets (Issued passes with device UUID and auth FK)
└── web_users (Web platform auth table [DISCREPANCY TARGET])

Physical Spatial Architecture:
├── venues (Physical building definitions)
├── venue_levels (Architectural floor levels with map assets)
├── venue_zones (Physical structural rooms with polygons)
├── event_zones (Operational zones scoped to specific events)
└── venue_pois (Points of interest with category & coordinates)

Crowd & Volunteer Telemetry:
├── volunteer_counts (Live crowd headcounts per zone)
├── volunteer_assignments (Authorized volunteer event/zone pairs)
├── volunteer_map_positions (Legacy 2D map coordinates [DISCREPANCY TARGET])
└── volunteer_switch_requests (Legacy volunteer swap table [DISCREPANCY TARGET])

Event Content & Agenda:
├── sessions (Keynotes, panels, and presentations)
├── booths (Sponsor, partner, and project exhibition booths)
└── activities (Interactive quests and challenges with verification codes)

Social & Gamification:
├── attendee_connections (Mutual opt-in networking links)
├── temporary_chat_messages (Ephemeral chat linked to meeting POIs)
└── attendee_engagements (Cryptographic immutable passport ledger)

Operational Command & Control:
├── operational_messages (Staff broadcasts, zone alerts, direct comms)
├── operational_message_receipts (Per-volunteer delivery/read/ack receipts)
├── operational_incidents (Issues, medical alerts, attendee assistance)
├── operational_incident_logs (Immutable audit trail of incident state)
├── lost_found_reports (Lost and found item registry)
├── event_teams (Operational squads and squads leads)
├── event_team_members (Team roster associations)
├── volunteer_shifts (Authoritative shift lifecycles)
├── shift_breaks (Break logs with expected return times)
├── coverage_requests (Station relief requests with atomic locks)
├── supervisor_tasks (Floor task assignments and completions)
└── shift_handoffs (Formal shift turnover records)
```

### 5.2 Server-Authoritative PostgreSQL Stored Procedures (RPCs)
- **Admission & Check-In:** `check_in_ticket(p_ticket_code, p_event_id, p_volunteer_id)`
- **Passport & Gamification:** `verify_activity_completion(...)`, `record_booth_visit(...)`, `record_session_attendance(...)`, `get_attendee_passport_summary(...)`
- **Assistance Intake:** `request_attendee_assistance(...)`, `get_attendee_assistance_status(...)`
- **Incident Dispatch:** `report_operational_incident(...)`, `assign_operational_incident(...)`, `update_incident_status(...)`
- **Shift & Relief:** `start_volunteer_shift(...)`, `end_volunteer_shift(...)`, `start_shift_break(...)`, `end_shift_break(...)`, `request_shift_coverage(...)`, `accept_shift_coverage(...)`
- **Operational Health:** `get_event_operational_health(p_event_id)`, `get_event_operational_timeline(p_event_id, p_limit)`

---

## 6. DEMO / HARDCODED DATA AUDIT

An exhaustive audit of the repository identified the following hardcoded fixtures, mock fallbacks, and synthetic behaviors:

### 6.1 Attendee App Hardcoded Fixtures
1. **Safety Resources (`apps/attendee_mobile/lib/features/safety/data/safety_mock_data.dart`):**
   - `[DEMO / HARDCODED]` The entire emergency directory (`SafetyMockData.venueSafetyResources`) is hardcoded in client memory (`res_first_aid`, `res_security`, `res_exit_north`, `res_exit_south`).
   - `[DEMO / HARDCODED]` Emergency contacts (`SafetyMockData.demoEmergencyContacts`) containing static phone numbers and room references.
   - `[DEMO / HARDCODED]` `SafetyRepositoryImpl` directly returns these static in-memory lists without querying any database entity.
2. **Spatial Topology Fallback (`apps/attendee_mobile/lib/features/map/models/venue_mock_data.dart`):**
   - `[MOCK / SIMULATED]` Contains static fallback definitions for 6 rooms (`701`, `702`, `706`, `707`, `711`, `712`) used when network requests fail or before backend migrations were run.
3. **Notification Mock Fixtures (`apps/attendee_mobile/lib/features/notifications/data/notification_mock_data.dart`):**
   - `[MOCK / SIMULATED]` Generates 6 static mock notifications including a fake contextual recommendation (`Booth Showcase: TechExpo Zone B`) and fake schedule reminder.
4. **Hardcoded Presence Zone (`VenueMockData.defaultPresenceZoneId`):**
   - `[DEMO / HARDCODED]` Hardcodes the attendee's simulated location to Room 712 (`Room 712 • Foyer & Registration`) when real indoor location estimation is inactive.

### 6.2 Volunteer App Hardcoded Fixtures
1. **Visual Validation Harness (`apps/volunteer_mobile/lib/visual_validation/mock_data/mock_event_data.dart`):**
   - `[MOCK / SIMULATED]` Isolated mock harness containing synthetic incidents, fake team rosters, simulated BLE telemetry packets (`0xAA11BB22CC33`), and static venue statistics.
2. **Event Summary Start-Time Fallback (`OperationalHealthRepositoryImpl.getEventSummary`):**
   - `[DEMO / HARDCODED]` `operational_health_repository.dart` line 117 contains: `final start = eventStartTime ?? (now.subtract(const Duration(hours: 4)));`. If the event start time is omitted, it arbitrarily assumes the event started exactly 4 hours ago.
3. **Offline Fallback Health State:**
   - `[MOCK / SIMULATED]` If both remote RPC and SQLite cache are missing, returns synthetic `EventOperationalHealth(overallHealth: OperationalHealthState.healthy, healthSummary: 'No operational health data available.')`.

### 6.3 Web Platform & Server Hardcoded Fixtures
1. **Static Stadium Map Background (`client/src/components/VenueMap.jsx`):**
   - `[DEMO / HARDCODED]` Relies on a hardcoded, static circular stadium background image (`/images/stadium_map_bg.png`) rather than dynamically rendering SVG floor plans from `venue_levels.map_asset_url`.
2. **File-Based Venue Layouts (`server/data/venue_layouts.json` & `server/routes/venue_map.py`):**
   - `[DEMO / HARDCODED]` Zone coordinates and bounding boxes are saved and loaded from a local JSON flat file on the server disk (`venue_layouts.json`) instead of querying the authoritative `venue_zones` database table.
3. **Hardcoded User Registration Count:**
   - `[MOCK / SIMULATED]` `server/routes/dashboard.py` falls back to querying `user_event_registrations` which only tracks web signups, completely ignoring mobile attendee tickets issued in `public.tickets`.

---

## 7. PRODUCTION DATA SOURCE MAPPING

Every mock and hardcoded entity discovered in Section 6 must be systematically mapped to authoritative production database tables:

| Hardcoded / Demo Component | Current Source | Production Authoritative Source | Required Schema / Migration Changes |
|---|---|---|---|
| **Venue Safety Resources** | `SafetyMockData.venueSafetyResources` | `public.venue_pois` WHERE `category IN ('first_aid', 'security', 'emergency_exit')` OR new `event_safety_resources` table | Add `is_emergency_resource` BOOLEAN and `guidance_text` to `venue_pois` |
| **Emergency Contacts** | `SafetyMockData.demoEmergencyContacts` | `public.event_emergency_contacts` | Create table `event_emergency_contacts(event_id, title, role, phone, channel)` |
| **Contextual Recommendations** | `notification_mock_data.dart` | `Spatially Intelligence Engine` Recommendation Service | Ingests `profiles.interests`, `attendee_engagements`, outputs to `event_notifications` |
| **Indoor Venue Layouts** | `server/data/venue_layouts.json` | `public.venue_zones` & `public.venue_levels` | Eliminate JSON flat file; query normalized PostgREST spatial tables |
| **Organizer Map Background** | `stadium_map_bg.png` | `public.venue_levels.map_asset_url` | Vector SVG canvas rendering normalized polygon bounds from `venue_zones` |
| **Event Start Timestamp** | Static `Duration(hours: 4)` fallback | `public.events.start_time` / `event_date` | Enforce required start/end timestamps on event creation |
| **Volunteer Position Mapping** | `volunteer_map_positions` (legacy flat coords) | `public.volunteer_shifts.zone_id` & `public.event_zones` | Bind volunteers to structural zones rather than arbitrary uncalibrated percentages |
| **Attendee Headcounts** | `user_event_registrations` | `public.tickets` (issued & checked-in) + `volunteer_counts` (BLE active) | Unified attendee metrics counting both tickets and live BLE observations |

---

## 8. ORGANIZER SYSTEM OVERVIEW

### 8.1 System Role & Target Audience
The **Organizer Platform** is the web-based operational command center of Spatially. It serves:
- **Lead Event Directors:** Requiring real-time operational visibility into attendance, revenue, safety, and venue flow.
- **Crowd Safety & Security Coordinators:** Monitoring live zone capacities, bottleneck alerts, incident reports, and emergency egress corridors.
- **Volunteer & Staff Coordinators:** Managing team shifts, break relief, station coverage, task assignments, and direct broadcast comms.
- **Experience Curators:** Publishing dynamic schedules, configuring exhibition booths, orchestrating gamified quests, and analyzing feedback.

### 8.2 Architectural Principles
1. **Single Source of Truth:** Direct integration with the production Supabase PostgreSQL database, eliminating disparate flat files and web-only tables.
2. **Unified Role-Based Access Control (RBAC):** Shared authentication with the mobile apps via Supabase Auth (`auth.users`) and verified roles in `public.profiles`.
3. **Sub-Second Real-Time Synchronization:** Leveraging Supabase Realtime Change Data Capture (CDC) for live crowd alerts, volunteer check-ins, and incident escalation.
4. **Resilient High-Density Ergonomics:** High-contrast, dense information display optimized for high-stress event environments (control rooms, laptops, field tablets).

---

## 9. ORGANIZER DASHBOARD REQUIREMENTS

### 9.1 Functional Requirements
- `[PROPOSED / NEW]` **Multi-Event Switching:** Dropdown selector allowing organizers to switch between active, upcoming, and archived events without re-authenticating.
- `[PARTIAL]` **Executive Metrics Grid:**
  - Real-time registered attendees vs checked-in attendees (queried from `tickets`).
  - Active volunteers on duty vs scheduled volunteers (queried from `volunteer_shifts`).
  - Active unresolved operational incidents (queried from `operational_incidents`).
  - Current venue-wide BLE ambient device density (aggregated from `volunteer_counts`).
- `[PROPOSED / NEW]` **Operational Health Gauge:** Real-time visual indicator (`Healthy`, `Elevated Attention`, `Critical Action Required`) derived from the `get_event_operational_health` RPC.
- `[PROPOSED / NEW]` **Live Incident Ticker:** Scrolling or card-based feed of active `urgent` and `important` incidents with one-click dispatch actions.
- `[PROPOSED / NEW]` **Zone Capacity Quick-Matrix:** Mini-grid of all configured zones displaying current occupancy percentage, status pill (`Normal`, `Congested`, `Critical`), and volunteer coverage ratio.

### 9.2 Data Requirements & RPC Hooks
- **Query:** `SELECT COUNT(*) FROM tickets WHERE event_id = :id AND status = 'checked_in'`
- **Query:** `SELECT * FROM volunteer_shifts WHERE event_id = :id AND status = 'active'`
- **RPC:** `get_event_operational_health(p_event_id)` returning overall status, active incident counts, and zone capacity warnings.
- **Realtime Listener:** Subscribed to `operational_incidents` and `volunteer_counts` for instant metric recalculation.

---

## 10. EVENT MANAGEMENT

### 10.1 Functional Requirements
- `[EXISTING]` `[PARTIAL]` **Event Lifecycle Management:** Create, view, update, and transition events across states (`draft`, `published`, `live`, `paused`, `ended`, `archived`).
- `[BACKEND REQUIRED]` **Venue Binding:** Link each event to an authoritative physical venue record in `public.venues`.
- `[BACKEND REQUIRED]` **Temporal Boundaries:** Enforce ISO-8601 `start_time` and `end_time` alongside `event_date` to eliminate the 4-hour arbitrary fallback in operational health.
- `[PROPOSED / NEW]` **Agenda & Content Orchestration:**
  - **Sessions Manager:** CRUD interface for keynotes, speaker panels, and workshops, linking each session to a specific `event_zone` and `venue_poi`.
  - **Exhibition Booths Manager:** CRUD interface for partner and project booths, configuring booth numbers, sponsor metadata, and physical map placement.
  - **Gamification & Quests Manager:** Configuration tool for interactive attendee activities, setting verification mechanisms (Secret Code, Volunteer Validation, or Beacon Proximity) and point values in `public.activities`.
- `[PROPOSED / NEW]` **Emergency Action Plan (EAP) Publishing:** Tool for defining venue-specific evacuation corridors, first aid desks, and crisis contacts directly pushed to attendee and volunteer safety views.

---

## 11. ZONE MANAGEMENT

### 11.1 Functional Requirements
- `[PROPOSED / NEW]` **Physical vs Operational Zone Architecture:**
  - Bridge permanent architectural rooms (`public.venue_zones`) with dynamic event operational partitions (`public.event_zones`).
- `[BACKEND REQUIRED]` **Capacity & Threshold Calibration:**
  - Define structural maximum capacity per zone.
  - Configure dynamic threshold percentages:
    - *Advisory Threshold (Yellow):* Typically 70% capacity (triggers volunteer rebalancing notice).
    - *Warning Threshold (Orange):* Typically 85% capacity (triggers attendee flow redirection suggestions).
    - *Critical Threshold (Red):* Typically 95% capacity (triggers safety alerts and security notifications).
- `[PROPOSED / NEW]` **Multi-Floor Level Association:** Group zones by architectural floor (`venue_levels`) to ensure multi-story venues render distinct floor plans.
- `[PROPOSED / NEW]` **Zone Operational Status Toggles:** Manually override zone accessibility states (`open`, `restricted_staff_only`, `temporarily_closed_cleaning`, `emergency_evacuated`).

---

## 12. CROWD MONITORING

### 12.1 Functional Requirements
- `[PROPOSED / NEW]` **Authoritative Crowd Density Ingestion:**
  - Aggregate live crowd telemetry directly from `public.volunteer_counts`, which is populated every 10–30 seconds by volunteer BLE scanners.
- `[PROPOSED / NEW]` **Staleness Visual Indicators:**
  - Distinguish active real-time data (`< 60 seconds old`) from stale data (`> 5 minutes old`) with explicit grey-out indicators so organizers never make safety decisions on phantom data.
- `[PROPOSED / NEW]` **Crowd Velocity & Influx Tracking:**
  - Calculate rate of change ($\Delta \text{devices} / \Delta t$) across 5-minute rolling windows to detect sudden crowd surges before physical crushes occur.
- `[PROPOSED / NEW]` **Dwell Time Analysis:**
  - Compute average attendee dwell duration per zone based on aggregate telemetry, identifying static bottlenecks vs rapid transit corridors.
- `[PROPOSED / NEW]` **Manual Headcount Calibration:**
  - Capability for gate supervisors to submit manual turnstile counts to calibrate or offset BLE attenuation factors.

---

## 13. VOLUNTEER MANAGEMENT

### 13.1 Functional Requirements
- `[PARTIAL]` **Unified Staff Identity & Roster:**
  - Replace legacy `web_users` invitations with standard Supabase Auth invitations linking to `public.profiles` where `role = 'volunteer'`.
- `[BACKEND REQUIRED]` **Team & Squad Configuration:**
  - CRUD interface for `public.event_teams` (e.g., "Registration Squad", "Crowd Safety", "Medical Rapid Response").
  - Assign squad leads (`lead_volunteer_id`) and team color identifiers.
- `[BACKEND REQUIRED]` **Shift Scheduling & Lifecycle Monitor:**
  - Build shift calendar assigning volunteers to specific teams, zones, and scheduled time blocks (`volunteer_shifts`).
  - Real-time monitor displaying active shift states (`scheduled`, `active`, `on_break`, `completed`).
- `[PROPOSED / NEW]` **Break & Coverage Oversight:**
  - Live dashboard tracking volunteers currently on break (`shift_breaks`) and flagging unreturned volunteers past their `expected_return` time.
  - Review and reassign station coverage requests (`coverage_requests`).
- `[PROPOSED / NEW]` **Shift Handoff Review:**
  - View digital turnover logs (`shift_handoffs`) submitted by outgoing volunteers, reviewing open incident checklists and transfer notes.

---

## 14. INCIDENT MANAGEMENT

### 14.1 Functional Requirements
- `[PARTIAL]` **Unified Incident Command Hub:**
  - Real-time incident intake queue displaying reports from volunteers (`reporter_type = 'volunteer'`) and attendees (`reporter_type = 'attendee'`).
- `[PROPOSED / NEW]` **Atomic Dispatch & Triage:**
  - Assign incidents to specific volunteers or squads using the atomic RPC `assign_operational_incident` to guarantee zero duplicate dispatch.
  - Re-prioritize incidents (`low`, `normal`, `important`, `urgent`) with mandatory justification logs.
- `[PROPOSED / NEW]` **Incident Lifecycle Management:**
  - Transition states: `reported` → `acknowledged` → `assigned` → `in_progress` → `resolved` → `closed`.
  - Record private organizer/staff notes (`staff_notes`) shielded from attendee viewing.
- `[PROPOSED / NEW]` **Audit Trail & Evidence Review:**
  - Inspect chronological audit logs (`operational_incident_logs`) tracking exact timestamps of acknowledgments, assignments, and resolution notes.
  - View photo evidence uploaded by volunteers or attendees (`imageUrl`).

---

## 15. ASSISTANCE MANAGEMENT

### 15.1 Functional Requirements
- `[PROPOSED / NEW]` **Attendee Help Desk Queue:**
  - Dedicated triage board for assistance requests generated via attendee mobile devices (`request_attendee_assistance`).
  - Categories: `medical`, `security`, `accessibility`, `lost_item`, `directions`, `general_inquiry`.
- `[PROPOSED / NEW]` **Privacy-Preserving Contact & Resolution:**
  - Review attendee's specific location description and device UUID without exposing private social profiles.
  - Provide resolution status updates that attendees can query via `get_attendee_assistance_status`.
- `[PROPOSED / NEW]` **Escalation to Formal Incident:**
  - One-click promotion converting an attendee help request into an escalated `operational_incidents` record with automated rapid-response dispatch.

---

## 16. TASK MANAGEMENT

### 16.1 Functional Requirements
- `[PROPOSED / NEW]` **Supervisor Task Board (Kanban / List):**
  - Create and delegate operational tasks (`public.supervisor_tasks`) across teams or specific volunteers.
  - Fields: `title`, `description`, `priority`, `due_time`, `zone_id`, `team_id`, `assigned_to_id`.
- `[PROPOSED / NEW]` **Real-Time Task Progression:**
  - Monitor tasks through lifecycle: `pending` → `accepted` → `in_progress` → `completed` → `cancelled`.
  - Review completion timestamps and volunteer verification notes.
- `[PROPOSED / NEW]` **Batch Task Templates:**
  - Pre-configure routine event tasks (e.g., "Morning Turnstile Calibration", "Restock Badge Lanyards", "Pre-Keynote Sound Check", "Post-Session Egress Clear").

---

## 17. COMMUNICATION

### 17.1 Functional Requirements
- `[PROPOSED / NEW]` **Multi-Tier Broadcast Console:**
  - Send authoritative operational messages (`public.operational_messages`) targeted by:
    - *Event-Wide Broadcast:* All active staff and volunteers.
    - *Team Broadcast:* Targeted to specific operational squads (`event_teams`).
    - *Zone Alert:* Targeted to volunteers currently checked into a specific `zone_id`.
    - *Direct Operational Message:* 1-on-1 private dispatch message to an individual volunteer.
- `[PROPOSED / NEW]` **Acknowledgment Tracking:**
  - For `urgent` broadcasts, mandate explicit acknowledgment (`requires_acknowledgment = true`).
  - Real-time audit dashboard showing delivery, read, and acknowledgment timestamps per volunteer (`operational_message_receipts`).
- `[PROPOSED / NEW]` **Canned Emergency Broadcast Templates:**
  - One-click pre-approved emergency broadcasts (e.g., "Severe Weather Protocol", "Medical Rapid Response to Zone B", "Lost Child Protocol").

---

## 18. NOTIFICATIONS & ALERTS

### 18.1 Functional Requirements
- `[PROPOSED / NEW]` **Attendee Announcement Broadcaster:**
  - Author and dispatch official event announcements to attendee mobile devices via `public.event_notifications`.
  - Categories: `announcement`, `safety`, `schedule_update`, `emergency`.
- `[PROPOSED / NEW]` **Targeted Spatial Alerts:**
  - Send announcements targeted to attendees located within or approaching specific physical zones.
- `[PROPOSED / NEW]` **Audible / Critical Alert Toggles:**
  - Configure critical safety alerts that trigger device-level high-priority banners on attendee devices.

---

## 19. MAP / EVENT AWARENESS

### 19.1 Functional Requirements
- `[PROPOSED / NEW]` **Production Vector Venue Map Engine:**
  - Replace the static stadium background image (`stadium_map_bg.png`) with an interactive SVG/Canvas vector engine rendering real floor layouts from `venue_levels` and `venue_zones`.
- `[PROPOSED / NEW]` **Multi-Floor Level Switching:**
  - Floor selector allowing organizers to switch between architectural levels (`Level 1 - Main Floor`, `Level 2 - Balcony & Workshop`, etc.).
- `[PROPOSED / NEW]` **Live Real-Time Spatial Layers:**
  - *Crowd Heatmap Layer:* Dynamic color overlays on zone polygons reflecting live occupancy tiers (Green, Yellow, Orange, Red).
  - *Volunteer Presence Layer:* Real-time markers showing volunteer stations based on active `volunteer_shifts.zone_id`.
  - *Incident Pin Layer:* Interactive visual pins marking active incident locations with priority-coded badges.
  - *POIs & Infrastructure Layer:* Toggleable markers for first aid, exits, stages, restrooms, and info desks.
- `[PROPOSED / NEW]` **Zone Geometry & POI Editor:**
  - Web-based graphical tool for organizers to draw/adjust zone bounding boxes, entrance coordinates, and POI coordinates without writing raw SQL.

---

## 20. ANALYTICS

### 20.1 Functional Requirements
- `[PROPOSED / NEW]` **Post-Event & Real-Time Analytics Suite:**
  - **Attendance & Conversion Curves:** Cumulative and hourly check-in velocity compared to total registrations.
  - **Zone Footfall & Density Timelines:** Historical line charts showing crowd ebb and flow across zones throughout the event day.
  - **Incident Performance Metrics:** Mean Time to Acknowledge (MTTA) and Mean Time to Resolve (MTTR) broken down by incident category and priority.
  - **Session & Booth Popularity:** Aggregate attendance and dwell times for each agenda session and sponsor booth.
  - **Gamification Engagement Funnel:** Quest completion rates, badge distribution, and total passport points issued.
- `[PROPOSED / NEW]` **Export & Reporting:**
  - One-click export of complete operational logs, incident records, and attendance data to CSV and PDF formats for compliance and sponsor reporting.

---

## 21. SYSTEM ADMINISTRATION

### 21.1 Functional Requirements
- `[PROPOSED / NEW]` **Organizer Account & Organization Management:**
  - Multi-user organizer teams with role tiers: `Owner`, `Event Director`, `Safety Officer`, `Staff Coordinator`, `Read-Only Auditor`.
- `[PROPOSED / NEW]` **API & Webhook Configuration:**
  - Manage API keys and outgoing webhooks for external integrations (ticketing providers, external security dispatch).
- `[PROPOSED / NEW]` **Audit Log Inspector:**
  - Complete immutable record of all organizer actions (event status changes, incident re-prioritizations, broadcast dispatches).

---

## 22. ORGANIZER INTELLIGENCE

### 22.1 Functional Requirements
- `[AI/ML REQUIRED]` **Automated Staff Rebalancing Recommendations:**
  - Intelligence layer calculates volunteer-to-attendee ratios per zone; when a zone exceeds safe thresholds while an adjacent zone is quiet, suggests shifting specific volunteers.
- `[AI/ML REQUIRED]` **Early Bottleneck Warning:**
  - Predictive models analyze historical flow and current rate of change to forecast congestion 15–30 minutes before critical thresholds are breached.
- `[AI/ML REQUIRED]` **Incident Anomaly Detection:**
  - Flags abnormal clusters of incidents (e.g., multiple slip-and-fall or heat exhaustion reports in a single sector) indicating localized environmental hazards.

---

## 23. SPATIALLY INTELLIGENCE ENGINE OVERVIEW

### 23.1 Purpose & Role in the Spatially Ecosystem
The **Spatially Intelligence Engine** is the central reasoning and analytics service of the platform. Operating as a specialized backend service, it ingests multi-source event signals, models spatial-temporal dynamics, and delivers context-aware, privacy-preserving intelligence to attendees, volunteers, and organizers.

```
       ┌────────────────────────────────────────────────────────┐
       │                   INTELLIGENCE INPUTS                  │
       │   Interests • Dwell Times • BLE Telemetry • Incidents  │
       └───────────────────────────┬────────────────────────────┘
                                   │
       ┌───────────────────────────▼────────────────────────────┐
       │             SPATIALLY INTELLIGENCE ENGINE              │
       │                                                        │
       │  ┌──────────────────────────────────────────────────┐  │
       │  │ LEVEL 1: Heuristic Rules & Spatial Scoring       │  │
       │  └──────────────────────────┬───────────────────────┘  │
       │                             ▼                          │
       │  ┌──────────────────────────────────────────────────┐  │
       │  │ LEVEL 2: Personalized Recommendation Engine       │  │
       │  └──────────────────────────┬───────────────────────┘  │
       │                             ▼                          │
       │  ┌──────────────────────────────────────────────────┐  │
       │  │ LEVEL 3: Predictive Modeling & Anomaly Detection │  │
       │  └──────────────────────────┬───────────────────────┘  │
       │                             ▼                          │
       │  ┌──────────────────────────────────────────────────┐  │
       │  │ LEVEL 4: Contextual LLM Event Assistant          │  │
       │  └──────────────────────────────────────────────────┘  │
       └───────────────────────────┬────────────────────────────┘
                                   │
       ┌───────────────────────────▼────────────────────────────┐
       │                  INTELLIGENCE OUTPUTS                  │
       │  Smart Agendas • Crowd Routing • Staff Dispatch • QA   │
       └────────────────────────────────────────────────────────┘
```

### 23.2 Core Architectural Principles
1. **Privacy-Preserving Edge Abstraction:** The Intelligence Engine never ingests raw hardware MAC addresses or unhashed personal identifiers. Attendee spatial behavior is analyzed via anonymous, rolling ephemeral tokens and aggregated zone counts.
2. **Progressive Hybrid Architecture (4 Levels):** Avoids deploying heavy ML where deterministic heuristic rules are faster, cheaper, and more reliable:
   - *Level 1:* Deterministic Rules & Weighted Spatial Scoring.
   - *Level 2:* Content-Based & Graph-Aware Recommendation Models.
   - *Level 3:* Predictive Spatial-Temporal & Anomaly Detection Models.
   - *Level 4:* Guardrailed LLM Event Assistant & NLP Sentiment Engine.
3. **Safety Non-Autonomy:** The Intelligence Engine **never** makes autonomous, unreviewed life-safety or security dispatch decisions. All automated safety suggestions require human organizer or coordinator confirmation.

---

## 24. INTELLIGENCE INPUTS

The Intelligence Engine systematically ingests the following multi-modal input streams:

### 24.1 Attendee Signals
- **Explicit Interests:** Selected profile tags (`public.profiles.interests`) e.g., `["AI", "Robotics", "Cloud"]`.
- **Search & Filter Queries:** In-app search queries for sessions, booths, and speakers.
- **Engagement Ledger History:** Completed challenges, booth visits, and session attendances recorded in `public.attendee_engagements`.
- **Opt-In Social Networking Preferences:** Mutual connections and requested meeting points from `public.attendee_connections`.
- **Assistance History:** Categories of past help requests submitted by the device.

### 24.2 Spatial & Crowd Signals
- **Zone Headcounts:** 30-second rolling device counts per zone from `public.volunteer_counts`.
- **Venue Topology Graph:** Distance matrices, entrance/exit coordinates, and transit corridor capacities derived from `venue_zones` and `venue_pois`.
- **Zonal Capacity Limits:** Static structural and operational limits from `event_zones`.

### 24.3 Operational & Temporal Signals
- **Event Schedule & Live Delays:** Dynamic session start/end times and delay notices from `public.sessions`.
- **Active Incident Telemetry:** Open incident categories, severity levels, and geographic locations from `public.operational_incidents`.
- **Volunteer Deployment Matrix:** Current active volunteer assignments and station coverage from `public.volunteer_shifts`.

---

## 25. BEHAVIORAL INTELLIGENCE

### 25.1 Dwell-Time & Engagement Derivation
- Derive implicit attendee interest by correlating presence duration within specific zones against scheduled agenda sessions and sponsor booths.
- Dwell score formulation:
  $$S_{\text{dwell}}(a, z, t) = \min\left(1.0, \frac{\Delta t_{\text{presence}}}{\text{Duration}_{\text{session}}}\right)$$
- Protect against signal distortion caused by structural transit delays or hallway congestion.

### 25.2 Privacy & Data Sanitization
- Spatial behavior is aggregated into anonymized zonal transition probability matrices:
  $$P(Z_j \mid Z_i, t)$$
- Individual attendee path trajectories are never retained in persistent cloud databases; path derivation is computed on-device or discarded post-aggregation.

---

## 26. PERSONALIZATION

### 26.1 Dynamic User Profiles
- Maintain a transient, session-scoped affinity vector for each attendee:
  $$\vec{V}_{\text{user}} = \alpha \vec{V}_{\text{explicit\_interests}} + \beta \vec{V}_{\text{historical\_visits}} + \gamma \vec{V}_{\text{search\_affinity}}$$
  where $\alpha = 0.5$, $\beta = 0.3$, and $\gamma = 0.2$.
- Update weights dynamically as the attendee interacts with booths and sessions throughout the event.

### 26.2 Adaptive Interface Personalization
- Automatically promote relevant sessions to the "Up Next" slot on the Attendee Home Screen (`apps/attendee_mobile/lib/features/home/widgets/home_up_next.dart`).
- Filter the interactive map to highlight POIs matching the user's highest affinity category.

---

## 27. RECOMMENDATION ENGINE

### 27.1 Recommendation Scoring Model (Level 1 & 2 Hybrid)
The engine calculates a composite recommendation score $R(u, i)$ for user $u$ and item $i$ (session, booth, or quest):

$$R(u, i) = w_1 \cdot S_{\text{interest}} + w_2 \cdot S_{\text{proximity}} + w_3 \cdot S_{\text{crowd}} + w_4 \cdot S_{\text{time}} + w_5 \cdot S_{\text{popularity}}$$

Where:
- $S_{\text{interest}} \in [0, 1]$: Cosine similarity between user affinity vector $\vec{V}_{\text{user}}$ and item tag vector $\vec{V}_{\text{item}}$.
- $S_{\text{proximity}} \in [0, 1]$: Inverse spatial distance between user's current zone $Z_u$ and item zone $Z_i$:
  $$S_{\text{proximity}} = \frac{1}{1 + \text{EuclideanDistance}(Z_u, Z_i)}$$
- $S_{\text{crowd}} \in [0, 1]$: Crowd penalty function discounting congested zones:
  $$S_{\text{crowd}} = \max\left(0.0, 1.0 - \frac{\text{CurrentCount}(Z_i)}{\text{CriticalCapacity}(Z_i)}\right)$$
- $S_{\text{time}} \in [0, 1]$: Temporal relevance (penalizes items that have already concluded or start too far in the future):
  $$S_{\text{time}} = \exp\left(-\frac{|\Delta t_{\text{start}} - 15\,\text{min}|}{\sigma_t}\right)$$
- $S_{\text{popularity}} \in [0, 1]$: Normalized global engagement count across all attendees.

### 27.2 Content-Based Recommendation Pipeline
1. Ingest item metadata (session abstract, speaker bios, booth product categories).
2. Generate semantic embeddings via a lightweight embedding model (e.g., `all-MiniLM-L6-v2`).
3. Compute cosine similarity against attendee interest vectors.
4. Apply hard constraints (e.g., discard sessions that conflict with an attendee's bookmarked agenda).

---

## 28. SMART ITINERARIES

### 28.1 Dynamic Itinerary Optimizer
- Solves a multi-objective Traveling Salesperson Problem with Time Windows (TSP-TW):
  - Maximizes total interest score $\sum R(u, i)$.
  - Minimizes transit time and physical walking distance across floors.
  - Guarantees zero schedule overlap between fixed-time keynote sessions.
  - Automatically schedules buffer intervals for meals, transit, and networking.

### 28.2 Real-Time Schedule Adaptation
- If an attendee's current session runs 15 minutes late, the engine automatically adjusts downstream itinerary items.
- If a recommended zone enters `critical` congestion, the itinerary dynamically substitutes an alternate activity or suggests an open exhibition hall.

---

## 29. CROWD-AWARE INTELLIGENCE

### 29.1 Intelligent Navigation & Flow Redirection
- Dynamic routing engine utilizing a weighted graph representation of the venue:
  $$\text{EdgeWeight}(u, v) = \text{PhysicalDistance}(u, v) \times \left(1 + \kappa \cdot \text{CongestionRatio}(v)\right)$$
- Automatically routes attendees away from choked stairwells or jammed entrance corridors toward alternate, lower-density pathways.

### 29.2 Load Balancing Recommendations
- When primary exhibition halls reach high density, the engine boosts the recommendation scores of under-visited booths in secondary halls for attendees with broad interests.

---

## 30. NOTIFICATION INTELLIGENCE

### 30.1 Notification Fatigue Mitigation
- Enforces an adaptive rate limiter:
  - Maximum 1 marketing/recommendation notification per 60 minutes per attendee.
  - Maximum 2 schedule reminders per hour.
  - Zero rate limiting for verified `safety` and `emergency` alerts.

### 30.2 Contextual Delivery Windows
- Evaluates attendee state before dispatching notifications:
  - Suppresses non-urgent notifications while an attendee is actively inside a keynote session.
  - Dispatches recommendations during transition intervals (e.g., 5 minutes after a session concludes).

---

## 31. PREDICTION

### 31.1 Short-Term Crowd Congestion Forecasting
- Spatial-temporal forecasting model predicting zone occupancy 15 to 45 minutes into the future:
  $$\hat{Y}_{z, t+\Delta t} = f\left(Y_{z, t}, Y_{z, t-1}, \text{ScheduledEvents}(z, t+\Delta t), \text{GlobalArrivalRate}\right)$$
- Utilizes an autoregressive gradient-boosted tree (XGBoost/LightGBM) trained on historical event timeline features.

### 31.2 Session Attendance Estimation
- Predicts session room fill rates 2 hours prior to start by analyzing bookmark counts, search frequency, and speaker popularity.
- Alerts organizers if predicted attendance exceeds room seating capacity, enabling proactive room swaps.

---

## 32. ANOMALY DETECTION

### 32.1 Spatial-Temporal Surge Detection
- Evaluates real-time volunteer telemetry against expected baseline distribution using an Isolation Forest or Z-Score threshold:
  $$Z_{\text{score}} = \frac{C_{\text{active}}(z, t) - \mu_z(t)}{\sigma_z(t)}$$
- Flags sudden unpredicted spikes ($Z > 3.0$) as potential bottlenecks or unauthorized crowd gatherings.

### 32.2 Bottleneck & Deadlock Recognition
- Detects transit corridors where crowd velocity drops below $0.2\,\text{m/s}$ while inflow remains positive, indicating a physical crush hazard.

---

## 33. VOLUNTEER INTELLIGENCE

### 33.1 Automated Dispatch & Rebalancing Suggestions
- Computes the Volunteer-to-Crowd Ratio (VCR) per zone:
  $$\text{VCR}(z) = \frac{N_{\text{volunteers}}(z)}{C_{\text{crowd}}(z)}$$
- If $\text{VCR}(z) < \theta_{\text{safe}}$ and an adjacent zone has surplus staff, generates a staff rebalance recommendation for the organizer.

### 33.2 Intelligent Task Prioritization
- Dynamically orders supervisor tasks on the volunteer mobile screen based on:
  - Task priority tier (`urgent` > `important` > `normal`).
  - Spatial proximity between the volunteer's current assigned station and the task location.
  - Elapsed wait time since task creation.

---

## 34. ORGANIZER INTELLIGENCE

### 34.1 Event Operational Risk Index
- Synthesizes venue-wide operational health into a single continuous Risk Score $\Omega \in [0, 100]$:
  $$\Omega = 0.35 \cdot I_{\text{incidents}} + 0.30 \cdot C_{\text{congestion}} + 0.20 \cdot V_{\text{staffing\_deficit}} + 0.15 \cdot A_{\text{assistance\_backlog}}$$
- Color-coded status displayed on the Organizer Dashboard:
  - $0 \le \Omega < 30$: **Normal Operations (Green)**
  - $30 \le \Omega < 70$: **Elevated Operational Strain (Yellow)**
  - $70 \le \Omega \le 100$: **Critical Action Required (Red)**

### 34.2 Root-Cause Diagnostic Engine
- Correlates incident spikes with concurrent event occurrences (e.g., "70% of medical calls in Zone C occurred within 10 minutes of Keynote B dismissing due to exit door obstruction").

---

## 35. AI ASSISTANT

### 35.1 Architecture & Retrieval-Augmented Generation (RAG)
- Specialized conversational assistant scoped strictly to event operations.
- Powered by an LLM backend (e.g., Gemini 1.5 Flash / Claude 3.5 Haiku) integrated with a vector store (e.g., pgvector in Supabase) indexing:
  - Official event agenda, speaker abstracts, and session FAQs.
  - Venue POI directory, restroom locations, and food vendor menus.
  - Public transportation and parking instructions.

### 35.2 Safety Guardrails & Operational Constraints
- **Absolute Safety Non-Autonomy:** The assistant is explicitly prohibited from generating evacuation directions or medical advice.
- When an attendee queries medical or security emergencies, the assistant immediately returns the pre-configured official emergency hotlines and triggers the in-app assistance flow.
- Enforces strict system prompt guardrails preventing hallucination or disclosure of confidential internal staff communications.

---

## 36. FEEDBACK / NLP

### 36.1 Real-Time Attendee Sentiment Ingestion
- Analyzes unstructured text feedback submitted through in-app session ratings and attendee assistance descriptions.
- Performs real-time sentiment scoring ($[-1.0, +1.0]$) and automated topic clustering using an NLP classification pipeline.

### 36.2 Rapid Issue Extraction
- Surfaces negative sentiment spikes to organizers (e.g., "Audio in Room 701 is echoing", "AC is broken in Hall B", "Food line at West Foyer is unmoving").

---

## 37. INTELLIGENCE ARCHITECTURE

### 37.1 Topology & Deployment
- Implemented as a containerized Python service (FastAPI) running alongside the primary backend infrastructure.
- High-frequency spatial operations (Level 1 rules, distance lookups, basic rate limiting) execute in-process with sub-10ms latency.
- Heavy analytical pipelines (Level 2 embeddings, Level 3 predictions) execute asynchronously via a background task queue (Celery or Redis Queue) updating database cache tables.

### 37.2 Data Synchronization & Cache Strategy
- Employs Redis for transient caching of:
  - 30-second rolling crowd density snapshots.
  - Active attendee affinity vectors.
  - Pre-computed shortest path matrices for venue graphs.
- Writes persistent recommendation logs and historical aggregate metrics back to Supabase PostgreSQL.

---

## 38. CROSS-SYSTEM DATA FLOW

```
[Attendee Mobile App]
       │ (1. BLE Advertisements - Ephemeral ID)
       ▼
[Volunteer Mobile App]
       │ (2. BLE Hardware Scans & Ticket Check-Ins)
       ▼
[Supabase Backend (PostgreSQL)]
       │ (3. volunteer_counts & tickets & incidents)
       ├─────────────────────────────────┐
       ▼ (4. Realtime CDC Stream)        ▼ (5. Direct API Sync)
[Spatially Intelligence Engine]    [Organizer Web Platform]
       │ (6. Process ML/Analytics)       │ (7. Operational Action)
       ▼                                 ▼
   Outputs:                         Dispatches:
   - Dynamic Recommendations        - Staff Rebalancing
   - Congestion Predictions         - Emergency Broadcasts
   - Route Adjustments              - Task Assignments
       │                                 │
       └────────────────┬────────────────┘
                        ▼
       [Attendee & Volunteer Apps Updated]
```

1. **Attendee Mobile** continuously broadcasts anonymous rotating ephemeral tokens over BLE.
2. **Volunteer Mobile** scans ambient BLE packets, aggregates counts per station, and flushes to `public.volunteer_counts`.
3. **Supabase Database** commits counts and triggers Realtime change data capture (CDC) events.
4. **Intelligence Engine** ingests live telemetry, updates density matrices, and forecasts congestion.
5. **Organizer Platform** reflects live heatmaps and operational health in real time.
6. **Intelligence Engine** feeds personalized recommendations to Attendee Mobile and dispatch alerts to Organizer Web.
7. **Organizer** confirms and dispatches operational actions, updating staff tasks and attendee notifications.

---

## 39. BACKEND / DATABASE REQUIREMENTS

### 39.1 Schema Additions & Modifications Required

To support the complete Organizer Platform and Intelligence Engine without breaking existing mobile schemas, the following database extensions are specified:

#### 1. Unification of Staff Authentication (`public.profiles`)
- Deprecate isolated `web_users` table.
- Standardize all authentication on Supabase Auth (`auth.users`) with authoritative role checks in `public.profiles`:
  ```sql
  ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS organization_id UUID,
  ADD COLUMN IF NOT EXISTS staff_permissions TEXT[] DEFAULT '{}';
  ```

#### 2. Emergency & Safety Resources Entity
- Replace static `SafetyMockData` with a normalized database table:
  ```sql
  CREATE TABLE IF NOT EXISTS public.event_safety_resources (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
      poi_id UUID REFERENCES public.venue_pois(id) ON DELETE SET NULL,
      title TEXT NOT NULL,
      subtitle TEXT,
      category TEXT NOT NULL CHECK (category IN ('medical', 'security', 'emergency_exit', 'assembly_point', 'help_desk', 'accessibility')),
      availability TEXT NOT NULL DEFAULT 'available',
      guidance TEXT NOT NULL,
      contact_channel TEXT,
      created_at TIMESTAMPTZ DEFAULT now()
  );
  ```

#### 3. Emergency Contacts Registry
- Replace static demo contacts:
  ```sql
  CREATE TABLE IF NOT EXISTS public.event_emergency_contacts (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      role TEXT NOT NULL,
      phone_number TEXT NOT NULL,
      radio_channel TEXT,
      display_order INT DEFAULT 0
  );
  ```

#### 4. Intelligence Recommendations Cache
- Persist personalized recommendations to eliminate repetitive computation:
  ```sql
  CREATE TABLE IF NOT EXISTS public.intelligence_recommendations (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
      attendee_device_id TEXT NOT NULL,
      item_type TEXT NOT NULL CHECK (item_type IN ('session', 'booth', 'activity')),
      item_id UUID NOT NULL,
      score FLOAT NOT NULL,
      reasons TEXT[] DEFAULT '{}',
      generated_at TIMESTAMPTZ DEFAULT now(),
      expires_at TIMESTAMPTZ NOT NULL
  );
  CREATE INDEX IF NOT EXISTS idx_intel_recs_device ON public.intelligence_recommendations(event_id, attendee_device_id);
  ```

#### 5. Spatial-Temporal Forecast Snapshots
- Store historical crowd predictions for post-event analytics:
  ```sql
  CREATE TABLE IF NOT EXISTS public.intelligence_crowd_forecasts (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
      zone_id UUID NOT NULL REFERENCES public.event_zones(id) ON DELETE CASCADE,
      forecast_window_start TIMESTAMPTZ NOT NULL,
      predicted_count INT NOT NULL,
      predicted_congestion_tier TEXT NOT NULL,
      confidence_interval FLOAT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT now()
  );
  ```

---

## 40. SECURITY & AUTHORIZATION

### 40.1 Role-Based Access Control (RBAC) Matrix

| User Role | Manage Events | Edit Venue Maps | View Live Crowd | View Incidents | Claim / Resolve Incidents | Send Staff Broadcasts | Send Attendee Alerts | Access Intelligence Admin |
|---|---|---|---|---|---|---|---|---|
| **Attendee** | Read (Pub) | Read (Pub) | Read (Agg) | None | None | None | None | None |
| **Volunteer** | Read (Assigned) | Read (Assigned) | Read/Write (Zone) | Read/Write (Own/Team) | Yes | Read / Ack | Read | Read (Tasks) |
| **Staff Coordinator** | Read / Update | Read / Assign | Read (All) | Read / Triage | Yes | Yes | None | Read (Staffing) |
| **Safety Chief** | Read / Update | Read / Annotate | Read (All) | Full Command | Yes | Yes (Urgent) | Yes (Safety) | Full (Safety) |
| **Event Organizer / Admin** | Full Control | Full Control | Full Control | Full Control | Yes | Full Control | Full Control | Full Control |

### 40.2 Row Level Security (RLS) Policies
- All new tables must strictly enforce RLS.
- Organizer operations must evaluate `auth.uid()` against `public.profiles.role IN ('organizer', 'admin')` and verify event ownership (`events.organizer_id = auth.uid()` or team authorization).
- Attendee devices querying recommendations must match their device UUID or authenticated user session.

---

## 41. ORGANIZER SCREEN INVENTORY

The Organizer Web Platform shall comprise the following 12 primary application views:

| Screen Identifier | Screen Name | Route | Core Functional Components |
|---|---|---|---|
| **ORG-01** | **Executive Command Center** | `/organizer/dashboard` | Event selector, Operational Health gauge, KPI cards, real-time incident ticker, live crowd mini-map. |
| **ORG-02** | **Event Lifecycle & Settings** | `/organizer/events` | Event creation wizard, date/time boundaries, status controls (`draft` to `ended`), venue binding. |
| **ORG-03** | **Interactive Vector Map Hub** | `/organizer/map` | Multi-floor level selector, SVG/Canvas topology editor, live crowd heatmap layer, volunteer pins. |
| **ORG-04** | **Zone & Capacity Editor** | `/organizer/zones` | Zone boundary polygon editor, capacity/threshold configurator, status overrides. |
| **ORG-05** | **Live Crowd & Flow Analytics** | `/organizer/crowd` | Zonal density matrix, 5-minute surge velocity chart, dwell time analytics, turnstile calibration. |
| **ORG-06** | **Incident Command & Triage** | `/organizer/incidents` | Incident triage queue, priority escalations, atomic assignment modal, audit log inspector. |
| **ORG-07** | **Attendee Assistance Desk** | `/organizer/assistance` | Help request stream, location tracker, one-click escalation to incident, resolution messenger. |
| **ORG-08** | **Volunteer Roster & Shifts** | `/organizer/volunteers` | Squad builder, shift scheduling calendar, active duty tracker, break/relief monitor. |
| **ORG-09** | **Floor Task Delegator** | `/organizer/tasks` | Task creation modal, supervisor task board (Kanban), priority sorter, completion reviewer. |
| **ORG-10** | **Operational Comms Console** | `/organizer/comms` | Multi-tier broadcast composer, urgent alert trigger, receipt & acknowledgment audit dashboard. |
| **ORG-11** | **Agenda & Content Manager** | `/organizer/content` | Sessions schedule editor, exhibition booth locator, gamified activity/quest configurator. |
| **ORG-12** | **Intelligence & Risk Center** | `/organizer/intelligence` | Predictive crowd forecasts, automated staff rebalancing alerts, attendee sentiment analysis. |

---

## 42. INTELLIGENCE COMPONENT INVENTORY

The Spatially Intelligence Engine shall comprise the following 10 modular services:

| Component ID | Component Name | Technology Stack | Execution Tier | Core Responsibility |
|---|---|---|---|---|
| **INT-01** | **Spatial Topology Engine** | Python / NetworkX | Core In-Memory | Builds venue graph, computes shortest paths, evaluates transit capacities. |
| **INT-02** | **Heuristic Scoring Engine** | Python / NumPy | Synchronous API | Computes Level 1 recommendation scores based on distance, time, and crowd penalty. |
| **INT-03** | **Personalization Profiler** | Python / Redis | Asynchronous Worker | Derives and caches attendee affinity vectors from interests and engagement ledger. |
| **INT-04** | **Semantic Embedding Engine** | PyTorch / Sentence-Transformers | Batch Worker | Generates dense vector embeddings for sessions, booths, and attendee search queries. |
| **INT-05** | **Smart Itinerary Optimizer** | Python / SciPy / OR-Tools | On-Demand API | Solves TSP-TW to generate conflict-free personalized event agendas. |
| **INT-06** | **Crowd Forecasting Engine** | Python / LightGBM | 5-Minute Cron | Predicts 15–45 minute zone crowd densities from historical and live telemetry. |
| **INT-07** | **Spatial Anomaly Detector** | Python / Scikit-Learn | 1-Minute Cron | Detects unpredicted crowd surges and stationary transit corridor deadlocks. |
| **INT-08** | **Staff Dispatch Rebalancer** | Python / Optimization | 2-Minute Cron | Recommends volunteer shifts between over-capacity and under-utilized zones. |
| **INT-09** | **Contextual Event Assistant** | FastAPI / LangChain / Gemini | Streaming API | RAG-powered conversational assistant for event FAQs, navigation, and schedules. |
| **INT-10** | **Sentiment & NLP Analyzer** | Python / HuggingFace Transformers | Asynchronous Worker | Analyzes attendee feedback and assistance descriptions to flag emerging venue issues. |

---

## 43. IMPLEMENTATION PHASES

To maintain architectural stability and ensure zero regression across existing mobile applications, execution is strictly phased across 5 logical milestones:

```
[Phase 8A: Data Model Unification & Database Foundations]
  ├── Deprecate web_users; migrate to Supabase Auth & public.profiles
  ├── Create event_safety_resources & event_emergency_contacts tables
  └── Create intelligence_recommendations & forecast tables
                       ↓
[Phase 8B: Organizer Core Command Platform (Web)]
  ├── Build high-density Organizer Dashboard, Event Manager & Zone Editor
  ├── Implement real-time Incident Command Hub & Assistance Desk
  └── Deliver Volunteer Shift Scheduler & Multi-Tier Broadcast Console
                       ↓
[Phase 8C: Interactive Vector Map & Dynamic Content]
  ├── Implement multi-floor SVG vector map canvas using venue_levels
  ├── Build graphical zone polygon & POI drag-and-drop editor
  └── Deploy Agenda Session, Booth, and Gamification Quest managers
                       ↓
[Phase 9A: Spatially Intelligence Engine (Levels 1–3)]
  ├── Deploy FastAPI Intelligence service with spatial topology engine
  ├── Implement Level 1 heuristic scoring & Level 2 personalized recommendations
  └── Deploy Level 3 crowd forecasting, surge anomaly detection & staff rebalancer
                       ↓
[Phase 9B: Contextual AI Assistant & NLP Analytics (Level 4)]
  ├── Build pgvector RAG pipeline for guardrailed conversational event assistant
  ├── Deploy real-time NLP sentiment analysis on attendee feedback
  └── Deliver end-to-end device validation across all 3 client platforms
```

---

## 44. CURRENT → TARGET SYSTEM MAPPING

| Dimension | Current State | Target State | Key Migration Action |
|---|---|---|---|
| **Web Authentication** | Custom bcrypt + `web_users` table with JWT tokens | Native Supabase Auth (`auth.users`) + `public.profiles.role` | Migrate web login to Supabase SDK; update `AuthContext.jsx` |
| **Volunteer Assignments** | Split between `web_volunteer_assignments` and `volunteer_assignments` | Single authoritative `public.volunteer_assignments` table | Drop `web_volunteer_assignments`; reconcile foreign keys |
| **Venue Layouts** | Static disk JSON (`server/data/venue_layouts.json`) | Normalized database tables (`venue_zones`, `venue_levels`) | Retire JSON file; route all geometry through PostgREST |
| **Map Visualization** | Static circular stadium bitmap (`stadium_map_bg.png`) | Dynamic multi-level SVG vector canvas | Render SVG polylines from `venue_zones.polygon` |
| **Safety Directory** | Static in-memory mock lists (`SafetyMockData.dart`) | Database table `public.event_safety_resources` | Wire `SafetyRepositoryImpl` to query Supabase PostgREST |
| **Operational Health** | Fallback to `DateTime.now() - 4 hours` start time | Authoritative `events.start_time` / `event_date` | Require start/end timestamps in event creation wizard |
| **Recommendations** | Static mock notification card (`notification_mock_data.dart`) | Real-time ML scores from `intelligence_recommendations` | Connect Attendee Home and Explore screens to Intelligence API |
| **Attendee Assistance** | Volunteer app claims via RPC; web has no visibility | Dedicated Assistance Triage Board on Organizer Web | Add `AttendeeAssistancePanel` to Organizer Command Center |

---

## 45. DEMO → PRODUCTION CLEANUP CHECKLIST

Before deploying the Organizer Platform and Intelligence Engine to production, the following mandatory forensic cleanup items must be resolved:

- [ ] **Purge `SafetyMockData` Dependency:** Refactor `apps/attendee_mobile/lib/features/safety/data/safety_repository.dart` to fetch live records from `public.event_safety_resources`.
- [ ] **Deprecate `VenueMockData`:** Update `apps/attendee_mobile/lib/features/map/data/supabase_venue_map_repository_impl.dart` to remove hardcoded room references (`701`, `702`, etc.) in production mode.
- [ ] **Eliminate 4-Hour Event Start Fallback:** In `apps/volunteer_mobile/lib/repositories/operational_health_repository.dart` (line 117), replace `now.subtract(Duration(hours: 4))` with strict validation of `events.start_time`.
- [ ] **Remove `server/data/venue_layouts.json`:** Delete the local JSON flat file and update `server/routes/venue_map.py` to query `public.venue_zones`.
- [ ] **Drop Legacy Web Tables:** Remove `web_users`, `web_volunteer_assignments`, and `volunteer_map_positions` following schema unification.
- [ ] **Retire Static Stadium Graphic:** Remove reliance on `/images/stadium_map_bg.png` in `client/src/components/VenueMap.jsx` in favor of dynamic SVG vector paths.
- [ ] **Eliminate Mock Notification Fixtures:** Remove static fixtures from `apps/attendee_mobile/lib/features/notifications/data/notification_mock_data.dart`.

---

## 46. GAP ANALYSIS

### 46.1 Identified Architectural Gaps
1. **User Identity Bifurcation:** The existing web platform was built with a standalone `web_users` table using bcrypt password hashing, while the mobile apps use Supabase Auth JWTs. This prevents an organizer from logging into mobile or a volunteer coordinator from managing staff seamlessly.
2. **Missing Spatial Editing Surface:** The database contains normalized spatial schema (`venue_zones`, `venue_levels`, `venue_pois`), but there is currently no graphical user interface to draw, calibrate, or update these polygons without manual SQL inserts.
3. **Absence of Real-Time Assistance Dashboard:** While attendees can submit help requests and volunteers can view them as incidents, the web client lacks a dedicated real-time triage desk for event directors.
4. **Intelligence Infrastructure Void:** Currently, no predictive intelligence, dynamic routing, or personalized recommendation logic exists beyond static mock strings.

---

## 47. DEPENDENCIES

### 47.1 External Libraries & Infrastructure
- **Hosted Supabase:** PostgreSQL 17, PostgREST, GoTrue Auth, Realtime CDC engine, Storage buckets (`incident_evidence`, `venue_maps`).
- **Web Frontend:** React 19, Vite, React Router v7, Recharts, Lucide Icons, Canvas / SVG rendering libraries.
- **Intelligence Backend:** Python 3.11+, FastAPI, NumPy, Pandas, Scikit-Learn, LightGBM, NetworkX, PyTorch / OnnxRuntime.
- **LLM Infrastructure:** Google Gemini API (or Claude API) via LangChain / LiteLLM for guardrailed conversational assistant.

---

## 48. RISKS / UNKNOWNS

| Risk Item | Severity | Mitigation Strategy |
|---|---|---|
| **BLE Signal Attenuation & Inaccurate Crowd Headcounts** | **HIGH** | Physical barriers, human bodies, and device pockets cause RF attenuation. Implement rolling averages, calibration multiplier inputs for organizers, and cross-reference with ticket turnstile counts. |
| **High Realtime CDC WebSocket Load during Surges** | **MEDIUM** | In high-density events with thousands of state changes, direct client CDC can saturate browsers. Use the Intelligence Engine to aggregate and throttle real-time broadcasts to 5-second windowed batches. |
| **Offline Divergence during Extended Network Loss** | **HIGH** | If staff phones operate offline for hours, large queues accumulate. The existing SQLite outbox and atomic RPCs handle idempotency, but the Organizer UI must clearly display "Last Seen" timestamps for all telemetry. |
| **LLM Hallucination during Emergency Situations** | **CRITICAL** | Strict system-level prompt guardrails and deterministic regex interceptors. The AI Assistant is hardcoded to never answer life-safety questions autonomously, redirecting immediately to human safety desks. |

---

## 49. EXPLICITLY OUT-OF-SCOPE ITEMS

To ensure project feasibility and maintain focus on core platform objectives, the following items are declared strictly **OUT OF SCOPE**:

1. **Hardware Beacon Firmware Flashing:** Spatially uses standard BLE advertisements emitted from smartphones; creating or flashing custom beacon hardware firmware is out of scope.
2. **Autonomous Physical Security Dispatch:** Automated dispatch of emergency services (police, municipal fire, ambulance) without human coordinator validation is strictly prohibited.
3. **Complex Turnstile Hardware Interfacing:** Direct serial/relay hardware wiring to physical electronic turnstile gates is excluded; check-in relies on mobile camera optical QR scanning.
4. **Payment Gateway Processing:** Processing ticket purchases or handling financial credit card transactions is out of scope; Spatially ingests issued ticket codes.
5. **Non-Event General Chat:** Social networking is strictly ephemeral, event-scoped, and capped at 1000 characters; general social media feeds or persistent direct messaging are out of scope.

---

## 50. FINAL IMPLEMENTATION CHECKLIST

Use this checklist to govern the development of the Organizer Platform and Spatially Intelligence Engine:

### Phase 8A: Data Model Unification & Database Foundations
- [ ] Migrate web authentication from `web_users` to Supabase Auth (`auth.users`) and link to `public.profiles`.
- [ ] Unify `web_volunteer_assignments` into canonical `public.volunteer_assignments`.
- [ ] Execute migration script creating `event_safety_resources` and `event_emergency_contacts`.
- [ ] Create `intelligence_recommendations` and `intelligence_crowd_forecasts` tables.
- [ ] Add `is_emergency_resource` and `guidance_text` columns to `public.venue_pois`.
- [ ] Enforce mandatory `start_time` and `end_time` columns on `public.events`.
- [ ] Verify that all 27+ tables have hardened Row Level Security (RLS) policies enabled.

### Phase 8B: Organizer Core Command Platform (Web)
- [ ] Rebuild `DashboardLayout.jsx` with a dense, high-contrast operational aesthetic.
- [ ] Implement `OrganizerDashboard.jsx` (ORG-01) with live KPI cards, health gauge, and incident ticker.
- [ ] Implement `OrganizerEvents.jsx` & `CreateEvent.jsx` (ORG-02) with strict date/time validation.
- [ ] Build `IncidentCommandPanel.jsx` (ORG-06) with atomic volunteer dispatch and audit trail.
- [ ] Build `AttendeeAssistancePanel.jsx` (ORG-07) with location tracking and escalation flows.
- [ ] Implement `VolunteerManagement.jsx` (ORG-08) supporting squads, shifts, and relief monitoring.
- [ ] Implement `SupervisorTasksPanel.jsx` (ORG-09) with Kanban progression.
- [ ] Implement `CommsCenterPanel.jsx` (ORG-10) with multi-tier broadcasting and receipt tracking.

### Phase 8C: Interactive Vector Map & Dynamic Content
- [ ] Build interactive SVG vector canvas in `VenueMap.jsx` (ORG-03) rendering `venue_zones.polygon`.
- [ ] Add multi-floor architectural level selector driven by `venue_levels`.
- [ ] Build drag-and-drop POI and station placer replacing arbitrary percentage coordinates.
- [ ] Implement `ZoneManagement.jsx` (ORG-04) with dynamic advisory, warning, and critical thresholds.
- [ ] Implement `EventContentManager.jsx` (ORG-11) for sessions, booths, and gamified challenges.
- [ ] Retire `server/data/venue_layouts.json` and static `/images/stadium_map_bg.png`.

### Phase 9A: Spatially Intelligence Engine (Levels 1–3)
- [ ] Initialize specialized FastAPI microservice in `server/intelligence/`.
- [ ] Implement `SpatialTopologyEngine` (INT-01) building NetworkX venue graphs from `venue_zones`.
- [ ] Implement Level 1 `HeuristicScoringEngine` (INT-02) computing distance, crowd, and time penalties.
- [ ] Implement Level 2 `PersonalizationProfiler` (INT-03) maintaining attendee interest affinity vectors.
- [ ] Build `SemanticEmbeddingEngine` (INT-04) indexing sessions and booth abstracts.
- [ ] Implement `SmartItineraryOptimizer` (INT-05) solving TSP-TW for attendee agendas.
- [ ] Deploy Level 3 `CrowdForecastingEngine` (INT-06) generating 15–45 minute occupancy predictions.
- [ ] Deploy `SpatialAnomalyDetector` (INT-07) flagging rapid crowd surges and transit deadlocks.
- [ ] Implement `StaffDispatchRebalancer` (INT-08) generating volunteer rebalancing suggestions.

### Phase 9B: Contextual AI Assistant & NLP Analytics (Level 4)
- [ ] Deploy RAG pipeline in `ContextualEventAssistant` (INT-09) using Supabase pgvector and LLM APIs.
- [ ] Enforce strict safety guardrails preventing autonomous life-safety advice.
- [ ] Build `SentimentAnalyzer` (INT-10) extracting attendee sentiment and issue clusters from feedback.
- [ ] Wire Attendee Mobile to consume live recommendations from `intelligence_recommendations`.
- [ ] Wire Volunteer Mobile to receive intelligent task orderings and crowd warning notifications.
- [ ] Execute comprehensive end-to-end integration tests across Web, Intelligence, and Mobile tiers.

---

**END OF MASTER SPECIFICATION**  
*Document verified and locked for Spatially repository architecture handoff.*
