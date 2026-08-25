import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Persistent device identity for the attendee app.
///
/// On first launch, a random UUID is generated via [Uuid().v4()] and stored
/// in shared_preferences under [_kDeviceIdKey]. On subsequent launches the
/// stored UUID is read back, so the identity is stable across app restarts
/// (but NOT across app reinstalls, which wipe shared_preferences).
///
/// Access the identity via [AttendeeIdentity.deviceId] after calling
/// [AttendeeIdentity.init()].
class AttendeeIdentity {
  AttendeeIdentity._();

  static const String _kDeviceIdKey = 'attendee_device_id';

  static String? _deviceId;

  /// The persisted device UUID. Null until [init()] has been awaited.
  static String? get deviceId => _deviceId;

  /// Reads or generates the device UUID. Must be called once at startup
  /// (await it in main() before runApp).
  static Future<void> init() async {
    print('DEBUG: AttendeeIdentity.init() called');
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_kDeviceIdKey);
      if (existing != null) {
        _deviceId = existing;
      } else {
        final newId = const Uuid().v4();
        await prefs.setString(_kDeviceIdKey, newId);
        _deviceId = newId;
      }
      print('DEBUG: attendee_device_id = $_deviceId');
    } catch (e, stackTrace) {
      print('DEBUG ERROR in AttendeeIdentity.init: $e\n$stackTrace');
    }
  }
}
