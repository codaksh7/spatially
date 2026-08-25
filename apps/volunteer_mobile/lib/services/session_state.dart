/// Simple in-memory singleton that holds per-session state.
/// Populated after login + event + zone selection. Reset on logout.
/// Used by BleScannerService to stamp observations.
class SessionState {
  SessionState._();
  static final SessionState _instance = SessionState._();
  static SessionState get instance => _instance;

  /// UUID of the currently logged-in Supabase user.
  /// Set from auth.currentUser?.id after successful sign-in.
  String? volunteerId;

  /// UUID of the event the volunteer is working this session.
  /// Set from EventPickerScreen after the volunteer selects an assigned event.
  String? eventId;

  /// Zone selected by the volunteer at the start of each session.
  /// Comes from the selected event's zones array column.
  String? zone;

  /// True if the battery check has already been performed for this session.
  bool batteryChecked = false;

  /// The user-configured interval (in seconds) for upserting volunteer counts.
  int syncRateSeconds = 30;

  /// Clears all session data. Call on sign-out.
  void clear() {
    volunteerId = null;
    eventId = null;
    zone = null;
    batteryChecked = false;
    syncRateSeconds = 30;
  }
}
