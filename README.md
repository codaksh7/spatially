# Spatially

## Project Overview
Spatially is a proof-of-concept BLE-based crowd monitoring and event ticketing system. It allows organizers to manage events, sell tickets, and passively track attendee density across different zones using BLE signals.

The system consists of three planned surfaces:
1. **Attendee Mobile** (`attendee_mobile`): App for attendees to purchase tickets, display QR codes for entry, and broadcast their presence securely via BLE.
2. **Volunteer Mobile** (`volunteer_mobile`): App for event staff to scan QR tickets and passively scan for attendee BLE signals, logging observations and active counts to the backend.
3. **Organizer Web**: (Not yet built) A dashboard for event organizers to monitor crowd density and manage events.

## Architecture
- **Mobile Apps**: Built with Flutter and deployed on Android.
- **Backend**: Supabase (PostgreSQL, Authentication, REST API).
- **Proximity Tracking**: Native Android Foreground Services for continuous BLE advertising/scanning. Attendee phones act as BLE peripherals, and Volunteer phones act as scanners.
- **Check-in**: Standard camera-based QR code scanning for ticket check-in.

## Database Schema
The database is built on PostgreSQL via Supabase. The source of truth for the schema can be found in `apps/volunteer_mobile/supabase/schema*.sql`.

- **`events`**: Defines events, venues, dates, and an array of valid `zones` (e.g., Main Stage, Food Court).
- **`tickets`**: Links an `event_id` to an `attendee_id` (a local UUID) and holds a unique `ticket_code` along with its status (`purchased` vs `checked_in`).
- **`volunteer_assignments`**: Links a `volunteer_id` (Auth user) to an `event_id`.
- **`observations`**: The core telemetry table tracking attendee presence. Links `ephemeral_id` (attendee's rotating BLE identifier) to a `volunteer_id`, `event_id`, and `zone`.
- **`volunteer_counts`**: Stores the live active device counts grouped by `volunteer_id`, `event_id`, and `zone` for the organizer dashboard.

## Setup Instructions

1. **Clone the repository**:
   ```bash
   git clone <repo-url>
   cd majorProject
   ```

2. **Install Flutter Dependencies**:
   For both mobile apps, run:
   ```bash
   cd apps/attendee_mobile
   flutter pub get
   
   cd ../volunteer_mobile
   flutter pub get
   ```

3. **Supabase Configuration**:
   The apps connect to Supabase using constants defined in `lib/config/supabase_config.dart`. **DO NOT hardcode real credentials in this repository.** Obtain the `SUPABASE_URL` and `SUPABASE_ANON_KEY` securely from the team and place them in your local config files before running the apps.

## Current Status

**Built and Working:**
- End-to-end BLE detection pipeline (foreground services, background persistence).
- Rotating Ephemeral BLE ID (SHA-256 derived, 6-byte truncated) for attendee privacy.
- Volunteer authentication via Supabase Auth.
- Multi-event support and zone selection.
- Ticketing system with QR generation and scanner check-in flow.
- Offline-first SQLite write queue for telemetry observations (flushes on connection).
- Live active device counting upserts.

**Not Yet Built:**
- Organizer web page / dashboard.
- Real payment integration for tickets.
- Row Level Security (RLS) and security hardening.

## Known Limitations
- **RLS Disabled**: Supabase Row Level Security (RLS) is currently completely disabled across all tables for the prototype phase. This must be addressed before production.
- **KGP Warning**: You may see a Kotlin Gradle Plugin (KGP) warning during Flutter builds for `app_settings` and `mobile_scanner`. This is non-blocking.
- **Android Exclusivity**: The BLE architecture is heavily reliant on Android Foreground Services and custom Android plugin forks.

## Team
- **Aryan**: Mobile Apps (`attendee_mobile`, `volunteer_mobile`)
- **Blaise, Daksh, Devansh**: Organizer Web Dashboard (Upcoming)
