# Spatially — Database & RPC Reference Manual

> **Target Audience:** Organizer Web Engineers (`client/`, `server/`)  
> **Status:** Authoritative Database Reference  
> **Last Updated:** September 29, 2026  
> **Migrations Directory:** `supabase/migrations/`

---

## 1. Core Domain Schema Overview

The database is built on PostgreSQL hosted via Supabase. All migrations reside in `supabase/migrations/` and execute sequentially.

```
                          ┌─────────────────────┐
                          │       events        │
                          └──────────┬──────────┘
                                     │
         ┌───────────────┬───────────┼───────────┬───────────────┐
         │               │           │           │               │
         ▼               ▼           ▼           ▼               ▼
┌─────────────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────────────┐
│   event_zones   │ │ tickets │ │  teams  │ │ booths  │ │    sessions     │
└────────┬────────┘ └────┬────┘ └────┬────┘ └─────────┘ └─────────────────┘
         │               │           │
         ├───────────────┼───────────┤
         ▼               ▼           ▼
┌─────────────────┐ ┌─────────────────────┐ ┌─────────────────────────────┐
│  observations   │ │  volunteer_shifts   │ │    operational_incidents    │
└─────────────────┘ └──────────┬──────────┘ └──────────────┬──────────────┘
                               │                           │
                               ▼                           ▼
                    ┌─────────────────────┐ ┌─────────────────────────────┐
                    │  coverage_requests  │ │     operational_messages    │
                    └─────────────────────┘ └─────────────────────────────┘
```

---

## 2. Key Domain Tables

### 2.1 Event & Spatial Foundation
- **`events`**: Core event entity (`id`, `name`, `venue`, `date`, `zones` text array, `description`, `capacity`, `organizer_id`, `start_time`, `end_time`, `location_address`).
- **`event_zones`**: Detailed spatial zone records (`id`, `event_id`, `name`, `code`, `floor_level`, `capacity_limit`, `operating_capacity`, `is_crowd_monitored`, `polygon_coordinates`, `created_at`).
- **`venue_maps`**: Scalable SVG/vector floor plans, bounds, scale factors, and visual layers.

### 2.2 Ticketing & Admission
- **`tickets`**: Individual admission passes (`id`, `event_id`, `attendee_id`, `ticket_code`, `status` (`purchased`, `checked_in`, `cancelled`), `tier_name`, `price`, `check_in_at`, `checked_in_by`, `checked_in_zone`).

### 2.3 Crowd Telemetry
- **`observations`**: High-frequency BLE presence records (`id`, `event_id`, `zone`, `volunteer_id`, `ephemeral_id`, `rssi`, `created_at`).
- **`volunteer_counts`**: Real-time active device counts (`event_id`, `volunteer_id`, `zone`, `active_count`, `updated_at`). Primary source for live dashboard occupancy widgets.

### 2.4 Staff, Teams & Shifts
- **`event_teams`**: Functional volunteer groups (`id`, `event_id`, `name`, `lead_volunteer_id`, `color_hex`).
- **`volunteer_assignments`**: Volunteer-to-event association (`volunteer_id`, `event_id`, `team_id`, `role`, `status`).
- **`volunteer_shifts`**: Active work shifts (`id`, `event_id`, `volunteer_id`, `zone_id`, `zone_name`, `team_id`, `status` (`active`, `completed`), `break_state` (`none`, `taking_break`), `start_time`, `end_time`).
- **`shift_breaks`**: Historical log of breaks taken during shifts.
- **`coverage_requests`**: Peer-to-peer and supervisor relief requests (`id`, `event_id`, `shift_id`, `requester_id`, `target_volunteer_id`, `zone_id`, `status` (`pending`, `accepted`, `resolved`, `cancelled`), `reason`).
- **`shift_handoffs`**: Structured operational transfer between incoming/outgoing staff.
- **`supervisor_tasks`**: Ad-hoc tasks assigned to staff (`id`, `event_id`, `title`, `description`, `zone_id`, `priority`, `assigned_to`, `status` (`pending`, `in_progress`, `completed`, `cancelled`)).

### 2.5 Operational Communications
- **`operational_messages`**: Real-time broadcast and operational chat (`id`, `event_id`, `sender_id`, `sender_name`, `target_type` (`broadcast`, `team`, `zone`, `direct`), `target_id`, `priority` (`routine`, `important`, `urgent`), `content`, `requires_ack`, `created_at`).
- **`message_acknowledgments`**: Staff receipts for emergency/mandatory announcements.

### 2.6 Incidents & Assistance
- **`operational_incidents`**: Incident management (`id`, `event_id`, `title`, `description`, `category` (`medical`, `security`, `crowd`, `infrastructure`, `assistance`, `lost_person`, `other`), `priority` (`routine`, `important`, `urgent`), `status` (`reported`, `acknowledged`, `assigned`, `in_progress`, `resolved`, `closed`), `zone_id`, `venue_zone_name`, `reporter_id`, `assigned_to`).
- **`incident_status_logs`**: Chronological audit trail of all status mutations on an incident.
- **`lost_found_reports`**: Misplaced items and custody tracking (`id`, `event_id`, `report_type` (`lost`, `found`), `item_category`, `description`, `location`, `status` (`open`, `claimed`, `returned`), `contact_name`).

---

## 3. Authoritative PostgreSQL RPCs

All RPCs are defined with `SECURITY DEFINER` and enforce event-staff or user authorization checks.

### 3.1 Operational Health & Analytics (Organizer Dashboard Primary)

#### `public.get_event_operational_health(p_event_id UUID) -> JSONB`
* **Purpose:** Computes the comprehensive real-time operational status across incidents, assistance requests, staff coverage, tasks, shifts, communications, zones, and lost & found.
* **Intended Consumer:** `OrganizerDashboard.jsx` (Home overview & metric cards).
* **Authorization:** Authenticated staff / organizer (`is_event_staff`).
* **Input Parameters:**
  * `p_event_id` (`UUID`): ID of the active event.
* **Output Format:**
```json
{
  "event_id": "...",
  "computed_at": "2026-09-29T12:00:00Z",
  "incidents": {
    "total": 12,
    "active": 3,
    "urgent": 1,
    "resolved": 9,
    "by_category": { "crowd": 2, "medical": 1 },
    "avg_time_to_acknowledge_seconds": 45,
    "avg_time_to_assign_seconds": 120,
    "avg_time_to_resolve_seconds": 480
  },
  "assistance": {
    "total": 5, "pending": 1, "in_progress": 1, "resolved": 3,
    "avg_time_to_resolve_seconds": 210
  },
  "coverage": {
    "total": 4, "pending": 1, "accepted": 1, "resolved": 2,
    "avg_time_to_accept_seconds": 75
  },
  "tasks": {
    "total": 8, "pending": 2, "in_progress": 1, "completed": 5,
    "avg_time_to_complete_seconds": 360
  },
  "shifts": {
    "total": 15, "active": 12, "on_break": 2, "completed": 3
  },
  "communications": {
    "total_messages": 34, "broadcasts": 4, "urgent": 2
  },
  "zones": [
    {
      "zone_id": "...", "zone_name": "Main Gate",
      "floor_level": 1, "capacity_limit": 500, "operating_capacity": 450,
      "current_density": "high", "is_monitored": true,
      "active_count": 342, "count_updated_at": "2026-09-29T12:00:00Z",
      "active_incidents": 1, "pending_tasks": 0, "active_staff": 4,
      "coverage_needed": false
    }
  ],
  "lost_found": {
    "total": 7, "lost": 3, "found": 4, "active": 2, "resolved": 5
  }
}
```

#### `public.get_event_operational_timeline(p_event_id UUID, p_limit INTEGER DEFAULT 50) -> JSONB`
* **Purpose:** Returns a unified chronological feed of operational milestones across incidents, coverage requests, tasks, and shift handoffs.
* **Intended Consumer:** Live Activity Feed in Organizer Web.
* **Parameters:** `p_event_id` (`UUID`), `p_limit` (`INTEGER`).
* **Item Structure:** `{ id, source_type, event_type, title, description, timestamp, zone_name, actor_name, priority, action_route, action_payload }`.

---

### 3.2 Staff & Shift Management RPCs

| RPC Name | Inputs | Description |
| :--- | :--- | :--- |
| `start_volunteer_shift` | `p_event_id`, `p_zone_id`, `p_zone_name`, `p_team_id` | Checks in staff member to active shift in specified zone |
| `end_volunteer_shift` | `p_shift_id`, `p_notes` | Closes active shift |
| `start_shift_break` | `p_shift_id`, `p_reason` | Transitions shift to `taking_break` |
| `end_shift_break` | `p_shift_id` | Ends break, resumes active shift |
| `request_shift_coverage`| `p_shift_id`, `p_event_id`, `p_reason`, `p_target_volunteer_id` | Emits peer or team relief request |
| `accept_shift_coverage` | `p_request_id` | Claims pending relief request |
| `create_supervisor_task`| `p_event_id`, `p_title`, `p_description`, `p_zone_name`, `p_assigned_to`, `p_priority` | Dispatches task to staff member |
| `update_task_status` | `p_task_id`, `p_status`, `p_notes` | Updates task (`in_progress`, `completed`, `cancelled`) |
| `create_shift_handoff` | `p_event_id`, `p_shift_id`, `p_target_id`, `p_notes`, `p_open_issues` | Transfers shift custody with operational notes |

---

### 3.3 Incident & Assistance RPCs

| RPC Name | Inputs | Description |
| :--- | :--- | :--- |
| `report_operational_incident` | `p_event_id`, `p_title`, `p_description`, `p_category`, `p_priority`, `p_zone_name` | Creates incident and notifies staff |
| `assign_operational_incident` | `p_incident_id`, `p_assignee_id`, `p_assignee_name` | Assigns responder to active incident |
| `acknowledge_operational_incident`| `p_incident_id` | Records first-responder acknowledgment |
| `update_incident_status` | `p_incident_id`, `p_status`, `p_resolution_notes` | Mutates status (`in_progress`, `resolved`, `closed`) |
| `request_attendee_assistance` | `p_event_id`, `p_category`, `p_description`, `p_location` | Attendee-initiated help ticket |
| `update_lost_found_status` | `p_report_id`, `p_status`, `p_notes` | Mutates lost & found custody status |

---

### 3.4 Ticketing & Check-In RPCs

| RPC Name | Inputs | Description |
| :--- | :--- | :--- |
| `check_in_ticket` | `p_ticket_code`, `p_event_id`, `p_volunteer_id`, `p_zone`, `p_offline_timestamp` | Idempotently checks in ticket QR code with offline reconciliation |
| `claim_guest_tickets` | `p_guest_id` | Associates guest-purchased tickets with newly registered user |

---

## 4. Supabase Realtime Channels

To enable live updates without manual page refresh, the Organizer Web Dashboard should subscribe to Supabase Realtime CDC channels:

```javascript
import { supabase } from './supabaseClient';

// 1. Subscribe to Live Incidents for current event
const incidentSubscription = supabase
  .channel(`organizer_incidents_${eventId}`)
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'operational_incidents',
      filter: `event_id=eq.${eventId}`
    },
    (payload) => {
      console.log('Incident changed:', payload);
      refreshHealthData();
    }
  )
  .subscribe();

// 2. Subscribe to Live Crowd Density Counts
const crowdSubscription = supabase
  .channel(`organizer_crowd_${eventId}`)
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'public',
      table: 'volunteer_counts',
      filter: `event_id=eq.${eventId}`
    },
    (payload) => {
      console.log('Crowd count updated:', payload);
      updateZoneDensityWidget(payload.new);
    }
  )
  .subscribe();
```

---

## 5. Security & Row Level Security (RLS) Boundaries

All core tables have RLS enabled:
- **`events`**: Public read for active events; write restricted to authenticated event organizer (`organizer_id = auth.uid()` or service role).
- **`operational_incidents` / `operational_messages` / `volunteer_shifts`**: Read and write permitted to verified event staff (`is_event_staff(event_id) = true`) and service role.
- **`observations` / `volunteer_counts`**: Insert/Upsert permitted to authenticated volunteers; select permitted to event staff and organizers.
- **Service Role:** `server/` uses `SUPABASE_SERVICE_KEY` which bypasses RLS for administrative actions (e.g., inviting staff, bulk ticket generation). Never bundle the service key in `client/`.
