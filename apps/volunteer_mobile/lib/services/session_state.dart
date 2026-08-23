/// Simple in-memory singleton that holds per-session state.
/// Populated after login + zone selection. Reset on logout.
/// Used by BleScannerService (Part 2c) to stamp observations.
class SessionState {
  SessionState._();
  static final SessionState _instance = SessionState._();
  static SessionState get instance => _instance;

  /// UUID of the currently logged-in Supabase user.
  /// Set from auth.currentUser?.id after successful sign-in.
  String? volunteerId;

  /// Zone selected by the volunteer at the start of each session.
  /// One of: "Entrance", "Main Stage", "Food Court", "Exit".
  String? zone;

  /// Clears all session data. Call on sign-out.
  void clear() {
    volunteerId = null;
    zone = null;
  }
}
