import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/volunteer_assignment_repository.dart';

/// Singleton holding per-session state with local SharedPreferences persistence
/// to survive app process death and background restarts.
class SessionState {
  SessionState._();
  static final SessionState _instance = SessionState._();
  static SessionState get instance => _instance;

  static const String _keyEventId = 'spatially_active_event_id';
  static const String _keyEventName = 'spatially_active_event_name';
  static const String _keyZoneId = 'spatially_active_zone_id';
  static const String _keyZoneName = 'spatially_active_zone_name';
  static const String _keyZoneCode = 'spatially_active_zone_code';
  static const String _keyIsRoving = 'spatially_active_is_roving';
  static const String _keyCapacityLimit = 'spatially_active_capacity_limit';
  static const String _keySyncRate = 'spatially_sync_rate_seconds';

  /// UUID of the currently logged-in Supabase user.
  String? volunteerId;

  /// Full name of the logged-in volunteer.
  String? volunteerName;

  /// Role of the logged-in user ('volunteer' or 'admin').
  String? userRole;

  /// UUID of the event the volunteer is working this session.
  String? eventId;

  /// Human-readable title of the active event (e.g., 'Cultural Night 2026').
  String? eventName;

  /// Normalized UUID of the assigned/selected zone from public.event_zones.
  String? zoneId;

  /// Code of the zone (e.g., '701') used for telemetry contract (volunteer_counts.zone).
  String? zoneCode;

  /// Display name of the zone (e.g., 'Auditorium' or 'Project Exhibition Hall A').
  String? zoneName;

  /// True if the volunteer has a roving assignment rather than a fixed station.
  bool isRoving = false;

  /// Maximum safe operating capacity for the zone (from public.event_zones).
  int? capacityLimit;

  /// Backward-compatible getter/setter for zone display name.
  String? get zone => zoneName;
  set zone(String? val) => zoneName = val;

  String? get assignedZoneId => zoneId;
  String? get assignedZoneName => zoneName;

  /// True if the battery check has already been performed for this session.
  bool batteryChecked = false;

  /// Block 2.5C: Operational Shift Context
  String? activeShiftId;
  String? activeShiftName;
  String? shiftStatus; // 'scheduled', 'active', 'on_break', 'handoff_pending', 'completed'
  String? teamId;
  String? teamName;
  String? supervisorName;
  bool get isOnBreak => shiftStatus == 'on_break';
  bool get isShiftActive => shiftStatus == 'active';

  void setShiftContext({
    required String shiftId,
    required String shiftName,
    required String shiftStatus,
    String? teamId,
    String? teamName,
    String? supervisorName,
  }) {
    activeShiftId = shiftId;
    activeShiftName = shiftName;
    this.shiftStatus = shiftStatus;
    this.teamId = teamId;
    this.teamName = teamName;
    this.supervisorName = supervisorName;
  }

  void clearShiftContext() {
    activeShiftId = null;
    activeShiftName = null;
    shiftStatus = null;
    teamId = null;
    teamName = null;
    supervisorName = null;
  }

  /// The user-configured interval (in seconds) for upserting volunteer counts.
  int syncRateSeconds = 30;

  /// Restores persisted event/zone context from SharedPreferences and verifies
  /// authorization against the server via the repository.
  Future<bool> restoreAndValidate(VolunteerAssignmentRepository repository) async {
    final vId = volunteerId;
    if (vId == null) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEventId = prefs.getString(_keyEventId);
      final savedEventName = prefs.getString(_keyEventName);
      final savedZoneId = prefs.getString(_keyZoneId);
      final savedZoneName = prefs.getString(_keyZoneName);
      final savedZoneCode = prefs.getString(_keyZoneCode);
      final savedIsRoving = prefs.getBool(_keyIsRoving) ?? (savedZoneId == null);
      final savedCapacity = prefs.getInt(_keyCapacityLimit);
      syncRateSeconds = prefs.getInt(_keySyncRate) ?? 30;

      if (savedEventId == null || savedZoneName == null) {
        return false;
      }

      // Verify that this assignment is still valid on the server
      final isValid = await repository.isAssignmentValid(
        volunteerId: vId,
        eventId: savedEventId,
        zoneId: savedZoneId,
      );

      if (isValid) {
        eventId = savedEventId;
        eventName = savedEventName ?? 'Active Event';
        zoneId = savedZoneId;
        zoneName = savedZoneName;
        zoneCode = savedZoneCode;
        isRoving = savedIsRoving;
        capacityLimit = savedCapacity;
        batteryChecked = true;
        print('SessionState: Restored and verified active shift for event $savedEventName ($savedEventId) in zone $savedZoneName ($savedZoneCode, roving=$isRoving)');
        return true;
      } else {
        print('SessionState: Stored shift is no longer valid on server. Clearing context.');
        eventId = null;
        eventName = null;
        zoneId = null;
        zoneName = null;
        zoneCode = null;
        isRoving = false;
        capacityLimit = null;
        await clearPersistence();
        return false;
      }
    } catch (e) {
      print('SessionState: Error restoring shift: $e');
      return false;
    }
  }

  /// Persists the active shift context to local storage.
  Future<void> persistShift({
    required String newEventId,
    String? newEventName,
    String? newZoneId,
    String? newZoneName,
    String? newZoneCode,
    bool? isRoving,
    int? capacityLimit,
  }) async {
    eventId = newEventId;
    if (newEventName != null) {
      eventName = newEventName;
    }
    zoneId = newZoneId;
    zoneName = newZoneName;
    zoneCode = newZoneCode;
    this.isRoving = isRoving ?? (newZoneId == null);
    if (capacityLimit != null) {
      this.capacityLimit = capacityLimit;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEventId, newEventId);
      if (eventName != null) {
        await prefs.setString(_keyEventName, eventName!);
      }
      if (newZoneId != null) {
        await prefs.setString(_keyZoneId, newZoneId);
      } else {
        await prefs.remove(_keyZoneId);
      }
      if (newZoneName != null) {
        await prefs.setString(_keyZoneName, newZoneName);
      } else {
        await prefs.remove(_keyZoneName);
      }
      if (newZoneCode != null) {
        await prefs.setString(_keyZoneCode, newZoneCode);
      } else {
        await prefs.remove(_keyZoneCode);
      }
      await prefs.setBool(_keyIsRoving, this.isRoving);
      if (this.capacityLimit != null) {
        await prefs.setInt(_keyCapacityLimit, this.capacityLimit!);
      } else {
        await prefs.remove(_keyCapacityLimit);
      }
      await prefs.setInt(_keySyncRate, syncRateSeconds);
    } catch (e) {
      print('SessionState: Error persisting shift: $e');
    }
  }

  /// Removes persisted shift data from SharedPreferences.
  Future<void> clearPersistence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyEventId);
      await prefs.remove(_keyEventName);
      await prefs.remove(_keyZoneId);
      await prefs.remove(_keyZoneName);
      await prefs.remove(_keyZoneCode);
      await prefs.remove(_keyIsRoving);
      await prefs.remove(_keyCapacityLimit);
    } catch (e) {
      print('SessionState: Error clearing persistent shift: $e');
    }
  }

  /// Clears in-memory session data and removes persistent shift context.
  Future<void> clear() async {
    volunteerId = null;
    userRole = null;
    eventId = null;
    eventName = null;
    zoneId = null;
    zoneName = null;
    zoneCode = null;
    isRoving = false;
    capacityLimit = null;
    batteryChecked = false;
    activeShiftId = null;
    activeShiftName = null;
    shiftStatus = null;
    teamId = null;
    teamName = null;
    supervisorName = null;
    syncRateSeconds = 30;
    await clearPersistence();
  }
}
