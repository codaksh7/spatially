# Spatially — Operational Systems Architecture

> **Target Audience:** Organizer Web Engineering Team  
> **Status:** Architecture & Subsystem Integration Manual  
> **Last Updated:** September 29, 2026  
> **Repository Context:** `Organizer Handoff Mds/OPERATIONAL_SYSTEMS.md`

---

## 1. Operational Data Flow & Attention Architecture

The operational subsystems within Spatially follow a strictly unidirectional and deduplicated data progression:

```
[Raw Field Data]
  - BLE Scanner RSSI
  - QR Scanner check-ins
  - Staff issue reports
  - Attendee assistance tickets
        │
        ▼
[Operational Subsystems (PostgreSQL Tables & Triggers)]
  - observations & volunteer_counts
  - operational_incidents
  - operational_messages
  - volunteer_shifts & coverage_requests
  - supervisor_tasks
        │
        ▼
[Event Awareness & Notification Engine]
  - Deterministic relevance scoring (My Zone, My Team, Event-wide Urgent)
  - Attention states (urgent, important, routine)
  - Haptic feedback & pocket-friendly vibration bursts
        │
        ▼
[Operational Health & Analytics Rollup]
  - get_event_operational_health (Aggregated JSON)
  - get_event_operational_timeline (Chronological stream)
        │
        ▼
[Organizer Web Dashboard]
  - High-level health index & heatmaps
  - Zone occupancy & incident dispatch feeds
```

### Critical Rule: Zero Double-Counting
An operational event (such as a medical incident reported in Hall B) generates multiple downstream representations:
1. A row in `operational_incidents` (PostgreSQL)
2. A Realtime CDC event broadcast over Supabase channels
3. An awareness feed card on volunteer phones
4. A vibration haptic pulse on relevant volunteer devices
5. An increment in the incident counter within `get_event_operational_health`

**These are multiple views of a SINGLE underlying operational reality.** The Organizer Dashboard must never tally or display the same event multiple times across different widgets or real-time channels.

---

## 2. Implemented Subsystems

### 2.1 Crowd Telemetry & Density Tracking
- **Physical Mechanism:** Attendee phones broadcast a BLE advertisement with a rotating 6-byte ephemeral identifier derived from SHA-256 (`lib/services/ble_peripheral_service.dart`).
- **Scanning & Buffering:** Volunteer staff phones scan nearby BLE devices in the background (`ble_scanner_service.dart`). Observations are buffered into local SQLite on the phone (`observation_queue.dart`) to ensure resilience against spotty venue Wi-Fi.
- **Backend Persistence:** Every 15-30 seconds, buffered observations are flushed to Supabase:
  - `observations`: Individual presence pings for spatial analysis.
  - `volunteer_counts`: Deduplicated active device counts per zone.
- **Organizer Interface:** The dashboard reads `volunteer_counts` or the aggregated `zones` block in `get_event_operational_health` to render real-time crowd heatmaps and congestion alerts.

### 2.2 Incident Management & First Response
- **Lifecycle:** `reported` ➔ `acknowledged` ➔ `assigned` ➔ `in_progress` ➔ `resolved` ➔ `closed`.
- **Categories:** `medical`, `security`, `crowd`, `infrastructure`, `assistance`, `lost_person`, `other`.
- **Priorities:** `urgent` (red), `important` (amber), `routine` (blue).
- **Auditability:** Every transition is recorded in `incident_status_logs` with actor timestamps, allowing the Organizer Dashboard to calculate mean time to acknowledge (MTTA) and mean time to resolve (MTTR).

### 2.3 Attendee Assistance
- **Attendee Channel:** Attendees can request assistance or report an emergency from the mobile app.
- **Dispatcher/Staff Escalation:** Assistance requests are automatically normalized into the incident triage pipeline with `category = 'assistance'`, notifying volunteers stationed in the attendee's zone.

### 2.4 Lost & Found Operations
- **Item Tracking:** Supports both `lost` and `found` reports with item categories (electronics, keys, wallet, apparel, ID, other), photos, and custody holders.
- **Status Lifecycle:** `registered` ➔ `in_custody` ➔ `matched` ➔ `claimed` ➔ `returned`.
- **Organizer Oversight:** Organizers can audit all items currently in volunteer custody and verify high-value returns.

### 2.5 Teams, Shifts, Breaks & Coverage
- **Team Hierarchy:** Volunteers belong to functional teams (`Medical`, `Security`, `Ticketing`, `Logistics`).
- **Shift State Machine:** `scheduled` ➔ `active` ➔ `on_break` ➔ `completed`.
- **Coverage/Relief Workflow:** When a staff member needs to take a break or leave their post:
  1. The volunteer clicks "Request Coverage" in the app (`request_shift_coverage`).
  2. The request appears on supervisor dashboards and available team members' screens.
  3. A peer accepts the coverage (`accept_shift_coverage`), updating zone coverage without operational downtime.
- **Shift Handoffs:** Outgoing volunteers log unresolved issues, ongoing tasks, and physical equipment custody to incoming volunteers (`create_shift_handoff`).

### 2.6 Supervisor Tasks
- **Ad-hoc Task Dispatch:** Supervisors and organizers can dispatch targeted tasks (`Replenish wristbands at Gate 2`, `Clear obstruction near Exit 4`) to specific volunteers or zones.
- **Realtime Feedback:** Staff can acknowledge, start, and complete tasks with completion timestamps tracked in the operational health rollup.

### 2.7 Operational Communications
- **Targeting Channels:**
  - `broadcast`: Reaches all active staff for the event.
  - `team`: Reaches members of a specific functional team.
  - `zone`: Reaches volunteers currently on duty in a specific zone.
  - `direct`: Secure 1-on-1 operational chat between two staff members.
- **Mandatory Acknowledgment:** Emergency announcements require volunteers to tap "Acknowledge", providing organizers with an audit receipt of who has received critical safety bulletins.

### 2.8 Event Awareness & Attention Model
- **Concept:** Rather than constantly switching screens, the Volunteer app synthesizes incoming events from all subsystems into a unified awareness feed.
- **Deterministic Relevance:** Events are categorized into:
  - `myZone`: Highest priority; impacts the volunteer's assigned area.
  - `myTeam`: Impacts the volunteer's team responsibilities.
  - `eventWideUrgent`: Critical alerts requiring immediate action regardless of zone.
  - `unrelatedNormal`: Filtered out or silenced to avoid notification fatigue.
- **Hardware Haptics:** Custom waveform vibrations on Android phones alert staff without requiring them to stare at screens in crowded environments.

### 2.9 Operational Health & Analytics
- **Aggregation Layer:** The database function `get_event_operational_health(event_id)` aggregates live metrics across all 8 subsystems in a single SQL query.
- **Response Metrics:** Calculates average acknowledgment and resolution times in seconds.
- **Zone Rollup:** Provides per-zone breakdown of active staff, current crowd density, pending tasks, and open incidents.

---

## 3. Recommended Organizer Dashboard Visualizations

| Operational Subsystem | Recommended Web Component | Underlying Data Source |
| :--- | :--- | :--- |
| **Crowd Monitoring** | Interactive Venue Map / Heatmap with zone color coding (Green: Low, Amber: Medium, Red: High) | `zones[].current_density`, `zones[].active_count` from `get_event_operational_health` |
| **Incident Command** | Kanban board or filterable data table (`Active`, `In Progress`, `Resolved`) with MTTA/MTTR KPI cards | `operational_incidents` table + Realtime CDC |
| **Staff & Coverage** | Zone-by-zone roster matrix showing assigned vs active volunteers, and break/relief indicators | `zones[].active_staff`, `coverage.pending` |
| **Activity Feed** | Chronological live timeline of all system events | `get_event_operational_timeline` RPC |
| **Safety Broadcasts** | Emergency banner creation modal with acknowledgment tracking percentage | `operational_messages` + `message_acknowledgments` |
