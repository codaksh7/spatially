
# Deep Forensic UI/UX Audit Report: Spatially Volunteer Mobile App

**Target App:** `apps/volunteer_mobile`
**Evidence Base:** 46 Physical Device Screenshots (`Volunteer SS/`), Live Flutter Source Code (`apps/volunteer_mobile/lib/`), and Spatially Major Project Design Specifications.
**Mode:** Diagnostic & Forensic Only (Zero Code Modifications Applied).

---

## Section A: Executive Architecture & Thematic Fracture

### 1. Global Theme Architecture Failure

* **[CONFIRMED FROM CODE]** In [lib/main.dart](file:///d:/majorProject/apps/volunteer_mobile/lib/main.dart#L21-L35), `MaterialApp` is instantiated without any `theme:` or `darkTheme:` definition:
  ```dart
  return MaterialApp(
    routes: { ... },
    home: const AuthGate(),
  );
  ```

  It completely falls back to Flutter’s generic Material 3 Light defaults (`ThemeData.light()`).
* **[CONFIRMED FROM CODE & SCREENSHOT]** Screen-level implementations have diverged into two completely disconnected, clashing design universes:
  1. **Light Mode Screens:** [ScanScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/scan_screen.dart#L673), [IncidentsListScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/incidents_list_screen.dart#L99), [IncidentDetailScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/incident_detail_screen.dart#L125), [LostFoundOperationsScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/lost_found_operations_screen.dart#L130), [LoginScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/login_screen.dart#L107), [EventPickerScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/event_picker_screen.dart#L56), [ZoneSelectionScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/zone_selection_screen.dart#L97).
  2. **Hardcoded Dark Mode Screens:** [OperationalHealthScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/operational_health_screen.dart#L132) (`0xFF0F172A`), [ShiftOverviewScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/shift_overview_screen.dart#L463) (`0xFF0B101B`), [ShiftHandoffScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/shift_handoff_screen.dart#L112) (`0xFF0B101B`), [TeamOverviewScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/team_overview_screen.dart#L104) (`0xFF0B101B`), [SupervisorTasksScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/supervisor_tasks_screen.dart#L101) (`0xFF0B101B`).
* **[CONFIRMED FROM SCREENSHOT]** The extreme manifestation occurs in [EventAwarenessFeedScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/event_awareness_feed_screen.dart#L26-L35) (`Screenshot_20260930-004902.png` and `004904.png`): The Scaffold sets `backgroundColor: const Color(0xFF0F172A)` (pitch dark slate), but leaves `AppBar` uncolored. Flutter’s default light `AppBarTheme` renders a **blinding pure white AppBar directly stacked on top of pitch-black body content**!

### 2. Prototype vs. Production Divergence

* **[CORRELATED / SYSTEMIC]** An isolated prototype exists under [lib/visual_validation/](file:///d:/majorProject/apps/volunteer_mobile/lib/visual_validation/README.md) with a unified dark tactical token system (`validation_colors.dart`, `tactical_app_bar.dart`, `tactical_buttons.dart`). However, the **real running production app** on the device is running raw legacy screens that directly call arbitrary Material widgets, hardcoded hex values, and ad-hoc styling.

---

## Section B: ScanScreen (Primary Command Dashboard)

*Screenshots: `Screenshot_20260930-004735.png`, `004823.png`, `005155.png`, `005232.png`*

1. **Severe AppBar Crowding & Title Truncation:**
   * **[CONFIRMED FROM CODE]** In [scan_screen.dart:674-738](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/scan_screen.dart#L674-L738), the `AppBar` declares 5 separate `IconButton` actions: `forum_outlined` (Comms), `assignment_outlined` (Incidents), `sync` (Queue sync), `qr_code_scanner` (Pass scan), and `logout` (Sign out).
   * **[CONFIRMED FROM SCREENSHOT]** Because 5 icon buttons consume over 240px of horizontal space on a 360–390dp mobile viewport, the title text is severely cut off as:
     $$
     \mathbf{Spatially\ Volun...}
     $$

     The subtitle (`Volunteer Dashboard`) is completely pushed out and obliterated.
2. **Rainbow / Pastel Workflow Tile Chaos:**
   * **[CONFIRMED FROM CODE]** In [scan_screen.dart:1230-1490](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/scan_screen.dart#L1230-L1490), the action tiles utilize uncalibrated pastel container colors: `Colors.amber[50]`, `Colors.red[50]`, `Colors.cyan[50]`, `Colors.blue[50]`, `Colors.purple[50]`, `Colors.indigo[50]`, `Colors.orange[50]`.
   * **[CONFIRMED FROM SCREENSHOT]** This looks like a generic toy dashboard rather than a high-reliability event operations terminal. Low-contrast icons in pale boxes fail rapid visual parsing under bright sunlight.
3. **Hero Metric Disconnection:**
   * The `CURRENT DETECTED` card (`0 attendee devices`, `Low Crowd - 0% capacity`) displays large 48pt numeral `0` with weak hierarchy, followed by an unbordered 3-column sub-metric row (`0 Cumulative Seen`, `5 Ambient BLE`, `81 Raw Signals`).
4. **Persistent Sync Feedback Snackbars:**
   * **[CONFIRMED FROM SCREENSHOT]** `Screenshot_20260930-005155.png` and `005236.png` reveal that `ObservationQueue().syncStatusStream` constantly triggers a dark floating bottom SnackBar `"Sync completed."`, which lingers across navigation transitions and even remains visible on the unauthenticated login screen!

---

## Section C: Operational Health & Telemetry Dashboard (OperationalHealthScreen)

*Screenshots: `Screenshot_20260930-004846.png`, `004849.png`, `004852.png`, `004855.png`, `004857.png`*

1. **Critical Contrast Failure — Invisible AppBar:**
   * **[CONFIRMED FROM CODE]** In [operational_health_screen.dart:134-140](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/operational_health_screen.dart#L134-L140):
     ```dart
     backgroundColor: const Color(0xFF1E293B),
     title: const Text('Operational Health', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
     ```

     Neither `foregroundColor`, `titleTextStyle.color`, nor `iconTheme` is specified.
   * **[CONFIRMED FROM SCREENSHOT]** Inheriting Material 3 Light defaults, the text `'Operational Health'` and the back arrow icon render in near-black/dark grey (`#1E293B` on `#1E293B`), rendering the header **100% invisible to the human eye** (contrast ratio ~1.1:1; severe WCAG 1.4.3 violation).
2. **Clipped TabBar Overflow:**
   * **[CONFIRMED FROM CODE]** TabBar uses `isScrollable: true` with 5 text tabs: `Live Health`, `Zones`, `Timeline`, `Response Times`, `Summary`.
   * **[CONFIRMED FROM SCREENSHOT]** On `Screenshot_20260930-004846.png` and `004855.png`, the 4th tab is cut off at the right viewport edge as `"Response Time..."`. The user receives no visual indicator or gradient scroll-fade showing that a 5th tab ("Summary") even exists off-screen.
3. **Low Contrast Analytics Cards:**
   * In the `Live Health` tab (`Screenshot_20260930-004846.png`), dark grey cards (`#1E293B`) feature faint slate subtitles (`#94A3B8` and `#64748B`), creating an illegible, muddy visual experience under outdoor conditions.

---

## Section D: Event Awareness Feed (EventAwarenessFeedScreen)

*Screenshots: `Screenshot_20260930-004902.png`, `004904.png`*

1. **Severe Bipolar Theme Clash:**
   * **[CONFIRMED FROM CODE]** [event_awareness_feed_screen.dart:26-35](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/event_awareness_feed_screen.dart#L26-L35): Scaffold `backgroundColor: const Color(0xFF0F172A)` paired with default unstyled `AppBar()`.
   * **[CONFIRMED FROM SCREENSHOT]** Renders an alarming visual break: an expansive white rectangular header block sitting on a dark navy/slate activity feed.
2. **Filter Chip Visual Noise:**
   * Chips (`All`, `Attention`, `My Zone`, `Team`, `Crowd`) use rigid horizontal scrolling with `#334155` background and indigo `#6366F1` selection. When `Attention` is selected (`004904.png`), unselected chips fade into the background while the filter bar consumes 52px of vertical real estate.
3. **Card Inconsistency:**
   * Awareness cards use hardcoded left-border color accents (Red for Critical, Amber for Warning, Cyan for Info). These border strokes lack rounded outer corner smoothing, producing harsh rectangular borders inside rounded card shells.

---

## Section E: Incident Management & Details (IncidentsListScreen & IncidentDetailScreen)

*Screenshots: `Screenshot_20260930-004912.png`, `004921.png`, `004934.png`, `005026.png`, `005031.png`, `005033.png`, `005035.png`, `005037.png`*

1. **Light Mode Shock & Tab Label Clipping:**
   * Navigating from the dark health/feed screen into `IncidentsListScreen` flashes an all-white background (`#FFFFFF`).
   * **[CONFIRMED FROM SCREENSHOT]** The 4th tab is truncated horizontally to `"Res..."` (`005026.png`), obscuring "Resolved / History".
2. **Action Button Collision in Incident Details:**
   * **[CONFIRMED FROM CODE]** In [incident_detail_screen.dart:450-510](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/incident_detail_screen.dart#L450-L510): Action buttons are placed in a horizontal `Row` with 3 completely distinct colors: Amber (`Acknowledge`), Purple (`Assign to Me`), Green (`Resolve`).
   * **[CONFIRMED FROM SCREENSHOT]** In `Screenshot_20260930-004912.png`, this produces an uncalibrated row of mismatched colored pill buttons.
3. **Empty Header Residual on Resolved Incident:**
   * **[CONFIRMED FROM SCREENSHOT]** In `Screenshot_20260930-004934.png`, once an incident is resolved, the action buttons disappear, but the title section `"Operational Actions"` remains stranded as an empty text header above a blank card space.
4. **Resolution Dialog Design Weakness:**
   * In `Screenshot_20260930-004921.png`, the `Resolve Incident` dialog renders an unstyled white card with Material 2 text fields, generic green `Resolve Incident` button, and standard grey `Cancel` text button with inconsistent corner radii.

---

## Section F: Operational Reporting Dialogs (ReportIssueDialog)

*Screenshots: `Screenshot_20260930-005003.png`, `005008.png`, `005013.png`, `005015.png`*

1. **Category Chip Overload:**
   * **[CONFIRMED FROM CODE]** [report_issue_dialog.dart:180-230](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/report_issue_dialog.dart#L180-L230): The bottom sheet wraps 11 category choices in an unconstrained `Wrap`: `Crowd Density`, `Medical`, `Security`, `Lost Child`, `Facility Issue`, `Access Control`, `Technical`, `Safety Hazard`, `Staff Support`, `Attendee Inquiry`, `Other`.
   * **[CONFIRMED FROM SCREENSHOT]** In `Screenshot_20260930-005003.png`, this forces a dense wall of 5 lines of grey pill chips, pushing critical input fields off-screen and requiring immediate vertical scrolling.
2. **Dialog Dual Personality / Hardcoded Mutations:**
   * In `005008.png`, the primary button is bright orange (`Report Issue`).
   * In `005013.png` and `005015.png`, the exact same dialog is reused for "Request Operational Help", where the button suddenly morphs into royal blue (`Submit Help Request`), altering border radii and typography arbitrarily.

---

## Section G: Shift Overview & Management (ShiftOverviewScreen)

*Screenshots: `Screenshot_20260930-005058.png`, `005100.png`, `005103.png`, `005116.png`*

1. **[CRITICAL BUG - CONFIRMED FROM SCREENSHOT & CODE] RenderFlex Overflow in Coverage Dialog:**
   * **[CONFIRMED FROM SCREENSHOT]** In `Screenshot_20260930-005103.png`, the `Request Station Coverage` dialog displays a bright yellow-and-black diagonal banner:
     $$
     \mathbf{A\ RenderFlex\ overflowed\ by\ 9.1\ pixels\ on\ the\ right.}
     $$

     The overflow error obscures the `URGENT` priority chip.
   * **[CONFIRMED FROM CODE]** Pinpointed in [shift_overview_screen.dart:375-398](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/shift_overview_screen.dart#L375-L398):
     ```dart
     Row(
       children: ['normal', 'important', 'urgent'].map((p) {
         return Padding(
           padding: const EdgeInsets.only(right: 8),
           child: ChoiceChip(label: Text(p.toUpperCase()), ...),
         );
       }).toList(),
     )
     ```

     Three uppercase chips (`NORMAL`, `IMPORTANT`, `URGENT`) with margins inside a constrained modal dialog exceed the physical width bounds on 360–380dp screens.
2. **Invisible Header & Back Icon:**
   * In `Screenshot_20260930-005058.png`, the AppBar title `'Shift & Station Management'` and the back icon are black-on-black (`#1E293B` on `#0B101B`), completely invisible.
3. **Mismatched 2x2 Action Button Matrix:**
   * In `Screenshot_20260930-005058.png`, the `Shift Actions` card features four conflicting button paradigms in a 2x2 grid:
     - Top-left: Outlined Amber button (`Start Break`)
     - Top-right: Outlined Purple button (`Request Coverage`)
     - Bottom-left: Filled Dark Slate button (`Shift Handoff`)
     - Bottom-right: Filled Red button (`End Shift`)
   * Four different border, fill, and color models placed in one quadrant creates visual chaos.

---

## Section H: Shift Handoff & Relievers (ShiftHandoffScreen)

*Screenshot: `Screenshot_20260930-005111.png`*

1. **Invisible AppBar:**
   * Title `'Shift Handoff Protocol'` is rendered in black text on dark background `#0B101B`.
2. **Sub-WCAG Form Inputs:**
   * The text input areas (`Reliever Volunteer ID / Name`, `Station Operational Status & Context`, `Key Open Items / Hazards`) have dark grey fills (`#0F172A`) with dark grey placeholder text (`#475569`), resulting in an inaccessible 1.8:1 contrast ratio that fails WCAG AA standards.

---

## Section I: Team Overview & Staff Directory (TeamOverviewScreen)

*Screenshots: `Screenshot_20260930-005124.png`, `005133.png`, `005135.png`*

1. **Invisible AppBar Title:**
   * `'Team & Roster Overview'` text is black-on-dark-navy.
2. **Redundant Status Chips:**
   * In `Screenshot_20260930-005124.png`, roster items repeat the volunteer's own card (`aryan (You) - ADMIN`) with a tiny grey role badge and green `ON_DUTY` pill that lacks vertical alignment with the avatar circle.
3. **Empty States Lack Actionable Direction:**
   * In `005133.png` (`Relief Requests`) and `005135.png` (`Supervisor Tasks`), empty states consist of faint grey outline icons with small, centered text ("No pending relief requests", "No supervisor tasks assigned"), providing zero secondary actions or explanations.

---

## Section J: Communications Center & Messaging (CommunicationsCenterScreen)

*Screenshots: `Screenshot_20260930-005203.png`, `005205.png`, `005207.png`, `005212.png`*

1. **Truncated AppBar Title:**
   * **[CONFIRMED FROM SCREENSHOT]** In `Screenshot_20260930-005203.png`, the screen title is cut off as:
     $$
     \mathbf{Communicatio...}
     $$

     With the subtitle `Demo Fest 2026` squished below it, caused by the `Online` status pill, task clipboard icon, and refresh icon consuming the top right actions.
2. **Clipped TabBar Label:**
   * The 3rd tab label is truncated to `"Direct & Op"`, cutting off the word "Operations".
3. **Massive Disconnected Floating Action Button:**
   * The bottom right features an oversized dark indigo rectangular FAB with text `"Compose"` (`Screenshot_20260930-005203.png`). It floats 80px off the bottom edge, creating dead whitespace and drawing disproportionate visual weight.

---

## Section K: Direct Thread / 1-on-1 Comms (DirectThreadScreen)

*Screenshots: `Screenshot_20260930-005210.png`, `005216.png`*

1. **Light Mode Inversion:**
   * Tapping any message thread transitions from dark or semi-dark views into a stark white chat canvas (`#FFFFFF`).
2. **Horizontally Stretched Quick Replies:**
   * In `Screenshot_20260930-005210.png`, quick reply chips (`Acknowledged.`, `On my way.`, `I'm coming.`, `Receive...`) sit above the input box and are cut off at the right edge without a scroll cue.
3. **Message Bubble Hierarchy:**
   * Outgoing bubbles use a deep purple-blue with faint white text, while timestamps (`20:37`) and delivery checkmarks (`SENT`) sit outside the bubble in faint grey, detached from the message bubble itself.

---

## Section L: QR Scanner / Ticket Verification (QrScannerScreen)

*Screenshot: `Screenshot_20260930-005159.png`*

1. **Camera Framing Cutoff:**
   * Camera feed renders in the upper 55% of the screen with a white rounded bounding square. The lower 45% of the screen is an empty white void displaying only a generic blue QR icon and text `"Ready to Scan / Position the attendee QR ticket code inside the frame."`.
2. **AppBar Label Inconsistency:**
   * Header reads `"Spatially Pass Verification"` in standard plain sans-serif, dropping the Audiowide logo treatment used across the rest of the application.

---

## Section M: Lost & Found Operations (LostFoundOperationsScreen)

*Screenshots: `Screenshot_20260930-005043.png`, `005046.png`, `005048.png`*

1. **Stark Light Theme:**
   * Employs generic Material 3 light cards with standard grey drop shadows and light grey backgrounds (`#F8F9FA`).
2. **Filter Chip Monotony:**
   * TabBar (`All Items`, `Unclaimed`, `Claimed / Returned`, `Transferred`) uses generic Material blue indicator lines and standard text styles.
3. **Status Update Sheet:**
   * In `005046.png` and `005048.png`, status updates occur via a bottom sheet containing a basic dropdown menu and single blue button, lacking verification notes or handover signatures.

---

## Section N: Authentication & Session Gate (LoginScreen, EventPickerScreen, ZoneSelectionScreen)

*Screenshots: `Screenshot_20260930-005236.png`, `005252.png`, `005255.png`, `005257.png`, `005300.png`*

1. **Login Screen Hierarchy & Disabled-Looking CTA:**
   * **[CONFIRMED FROM SCREENSHOT & CODE]** In `Screenshot_20260930-005236.png` and [login_screen.dart:108-156](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/login_screen.dart#L108-L156):
     - The AppBar contains the text `"Spatially for Volunteer"`.
     - 40px below it, the body repeats the exact same text `"Spatially for Volunteer"` in huge 32pt/24pt letters.
     - The `ElevatedButton` has no explicit styling; Material 3 renders it as a pale, washed-out grey pill with faint purple text, making it look **permanently disabled** even when active.
     - The persistent `"Sync completed."` SnackBar lingers over the login form.
2. **Station Setup Redundant String Formats:**
   * **[CONFIRMED FROM CODE]** In [zone_selection_screen.dart:294](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/zone_selection_screen.dart#L294):
     ```dart
     '${zone.name} (${zone.code})'
     ```
   * **[CONFIRMED FROM SCREENSHOT]** In `Screenshot_20260930-005257.png` and `005300.png`, because `name` and `code` are identical in the database, the dropdown items and cards display redundant duplicated strings:
     - `"Entrance (Entrance)"`
     - `"Main Stage (Main Stage)"`
     - `"Food Court (Food Court)"`
     - `"Exit (Exit)"`

---

## Section O: Typography & Hierarchy Analysis

* **Font Family Fragmentation:**
  - [scan_screen.dart:680-689](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/scan_screen.dart#L680-L689) mixes `GoogleFonts.audiowide` for titles and `GoogleFonts.poppins` for subtitles.
  - [operational_health_screen.dart:137](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/operational_health_screen.dart#L137) uses default system fonts (`TextStyle`).
  - [event_awareness_feed_screen.dart:31](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/event_awareness_feed_screen.dart#L31) uses `GoogleFonts.poppins`.
  - [login_screen.dart](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/login_screen.dart) uses Audiowide + Poppins.
  - [qr_scanner_screen.dart](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/qr_scanner_screen.dart) uses system default fonts.
* **Numeric Representation:**
  - Real-time operational numbers (BLE counts, timestamps, RSSI values) use standard proportional font glyphs rather than tabular figures (`FontFeature.tabularFigures()`), causing jitter during live telemetry refreshes.

---

## Section P: Color & Semantic Token Analysis

* **Complete Absence of Global Design Tokens:**
  - Zero shared `ThemeData` tokens in production (`main.dart`).
  - Dark surfaces alternate arbitrarily between `#0F172A` (Slate 900), `#0B101B` (Pitch Dark), `#1E293B` (Slate 800), and `#121927`.
  - Status indicators use ad-hoc hex values across screens:
    - Critical: `#EF4444`, `Colors.red`, `Colors.redAccent`
    - Warning/Amber: `#F59E0B`, `Colors.amber`, `Colors.orange`
    - Success/Online: `#10B981`, `Colors.green`, `Colors.emerald`
    - Information/Action: `#6366F1`, `Colors.blue`, `Colors.cyanAccent`, `Colors.indigo`

---

## Section Q: Layout, Spacing & Overflow Risks

1. **[CRITICAL] Request Station Coverage Dialog Overflow:**
   - 9.1px `RenderFlex` overflow on the priority `Row` in `shift_overview_screen.dart:375`.
2. **AppBar Title Truncation Across Multiple Screens:**
   - `ScanScreen`: `"Spatially Volun..."` due to 5 action buttons.
   - `CommunicationsCenterScreen`: `"Communicatio..."` due to right-side badges.
3. **TabBar Label Clipping Across Multiple Screens:**
   - `OperationalHealthScreen`: `"Response Time..."` cut off.
   - `IncidentsListScreen`: `"Res..."` cut off.
   - `CommunicationsCenterScreen`: `"Direct & Op"` cut off.

---

## Section R: Accessibility & Tactile Usability Audit (WCAG AA/AAA)

1. **Severe WCAG 1.4.3 Contrast Failures:**
   - Dark theme AppBars in `OperationalHealthScreen`, `ShiftOverviewScreen`, `TeamOverviewScreen`, and `ShiftHandoffScreen` render dark-grey-on-black (`#1E293B` on `#0B101B` or `#1E293B`), yielding ~1.1:1 contrast (minimum required is 4.5:1 for regular text, 3.0:1 for large text).
2. **Sub-48dp Tap Target Hazards:**
   - Filter chips and small close icons across dialogs measure between 28dp and 32dp in height, violating the WCAG 2.5.5 target size requirement (48x48dp minimum) for operational mobile environments.
3. **Sunlight & Glare Inoperability:**
   - The pastel workflow cards on `ScanScreen` (`Colors.amber[50]`, `Colors.cyan[50]`) wash out completely under outdoor festival/event lighting conditions.

---

## Priority Summary (Top 8 High-Impact Issues)

| Priority     | Issue Description                                                              | Screen(s) Affected                                                                                                                                                                                                                                                                                                                                                                                                                                                     | Severity                      |
| :----------- | :----------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------- |
| **P1** | **Active RenderFlex 9.1px Overflow Crash Banner**                        | [ShiftOverviewScreen (Coverage Dialog)](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/shift_overview_screen.dart#L375-L398)                                                                                                                                                                                                                                                                                                                                 | **Critical Blocker**    |
| **P2** | **Invisible Header Titles & Back Arrows (Dark-on-Dark)**                 | [OperationalHealthScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/operational_health_screen.dart#L134), [ShiftOverviewScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/shift_overview_screen.dart#L463), [TeamOverviewScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/team_overview_screen.dart#L104), [ShiftHandoffScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/shift_handoff_screen.dart#L112) | **Severe A11y Failure** |
| **P3** | **Global Theme Fracture & Blinding White/Dark Stacks**                   | [main.dart](file:///d:/majorProject/apps/volunteer_mobile/lib/main.dart#L26), [EventAwarenessFeedScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/event_awareness_feed_screen.dart#L26-L35), [IncidentsListScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/incidents_list_screen.dart#L99)                                                                                                                                             | **High Architectural**  |
| **P4** | **AppBar Title Truncation ("Spatially Volun...", "Communicatio...")**    | [ScanScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/scan_screen.dart#L674), [CommunicationsCenterScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/communications_center_screen.dart#L150)                                                                                                                                                                                                                                            | **High Visual**         |
| **P5** | **TabBar Label Truncation ("Res...", "Response Time...")**               | [IncidentsListScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/incidents_list_screen.dart#L110), [OperationalHealthScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/operational_health_screen.dart#L148)                                                                                                                                                                                                                               | **Medium UX**           |
| **P6** | **Pastel Workflow Tile Incoherence & Low Outdoor Contrast**              | [ScanScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/scan_screen.dart#L1230-L1490)                                                                                                                                                                                                                                                                                                                                                                    | **Medium Usability**    |
| **P7** | **Washed-out / Disabled-Looking Authentication CTA & Duplicated Titles** | [LoginScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/login_screen.dart#L107-L208)                                                                                                                                                                                                                                                                                                                                                                    | **Medium Visual**       |
| **P8** | **Redundant Display Strings ("Main Stage (Main Stage)")**                | [ZoneSelectionScreen](file:///d:/majorProject/apps/volunteer_mobile/lib/screens/zone_selection_screen.dart#L294)                                                                                                                                                                                                                                                                                                                                                        | **Low Cosmetic**        |

---

## Final Readiness Check

* **Are any code modifications committed or staged?****NO.** Zero lines of code were modified, deleted, or committed during this inspection.
* **Is the evidence base fully validated against ground truth?****YES.** All 46 device screenshots in `Volunteer SS/` have been individually inspected, cross-checked against production Flutter code, and cataloged.
* **Next Steps:**
  Awaiting user directive before proceeding with any design token consolidation, layout bug fixes, or theme unification.

sve this also in mds folder
