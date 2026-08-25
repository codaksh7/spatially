import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ble_observation.dart';
import '../config/supabase_config.dart';
import 'session_state.dart';

class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;

  TelemetryService._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _initialized = true;
      print('TelemetryService: Supabase initialized successfully.');
    } catch (e) {
      print('TelemetryService ERROR: Failed to initialize Supabase: $e');
    }
  }

  /// Sends a single observation to the Supabase database.
  /// This is a fire-and-forget call for the online-first path.
  Future<void> sendObservation(BleObservation observation) async {
    if (!_initialized) {
      print('TelemetryService ERROR: Cannot send observation, Supabase not initialized.');
      return;
    }

    try {
      // Intermediate variables to avoid a Dart CFE type-inference crash
      // (STATUS_ACCESS_VIOLATION) triggered by the fluent chain:
      //   Supabase.instance.client.from('table').insert(arg)
      // The CFE crashes when resolving: ThisExpression → PropertyGet → IndexGet
      // → MethodInvocation(argument) in a single chained expression inside async.
      final supabaseInstance = Supabase.instance;
      final client = supabaseInstance.client;
      final table = client.from('observations');
      final row = observation.toMap();
      await table.insert(row);
      print('TelemetryService: Successfully sent observation for ${observation.ephemeralId}');
    } catch (e) {
      print('TelemetryService ERROR: Failed to send observation: $e');
    }
  }

  /// Upserts the live count of active Spatially devices for the current volunteer.
  Future<void> updateVolunteerCount(int activeCount) async {
    if (!_initialized) return;

    final volunteerId = SessionState.instance.volunteerId;
    final zone = SessionState.instance.zone;

    if (volunteerId == null || zone == null) {
      // Missing session information, simply ignore.
      return;
    }

    try {
      final supabaseInstance = Supabase.instance;
      final client = supabaseInstance.client;
      final table = client.from('volunteer_counts');
      final Map<String, dynamic> row = {
        'volunteer_id': volunteerId,
        'event_id': SessionState.instance.eventId,
        'zone': zone,
        'active_count': activeCount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      // Upsert on primary key (volunteer_id)
      await table.upsert(row);

    } catch (e) {
      print('TelemetryService ERROR: Failed to update volunteer count: $e');
    }
  }
}
