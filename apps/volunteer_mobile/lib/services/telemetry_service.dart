import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ble_observation.dart';
import '../config/supabase_config.dart';
import 'session_state.dart';
import 'observation_queue.dart';

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
        publishableKey: supabaseAnonKey,
      );
      _initialized = true;
      print('TelemetryService: Supabase initialized successfully.');
    } catch (e) {
      print('TelemetryService ERROR: Failed to initialize Supabase: $e');
    }

    // Initialise the offline queue AFTER Supabase is up so that the startup
    // flush can attempt cloud writes immediately if there is connectivity.
    await ObservationQueue().init();
  }

  /// Sends a single observation to Supabase, falling back to the local
  /// SQLite queue if the network write fails.
  /// Enforces privacy gate: Ambient non-Spatially devices are strictly ignored.
  Future<void> sendObservation(BleObservation observation) async {
    if (!_initialized) {
      print('TelemetryService ERROR: Cannot send observation, Supabase not initialized.');
      return;
    }

    // Privacy Gate: Never transmit or store non-Spatially ambient devices
    if (!observation.isSpatiallyDevice) {
      return;
    }

    // Delegate to ObservationQueue which owns the online-first → local-queue fallback logic.
    await ObservationQueue().sendOrQueue(observation);
  }

  DateTime? _lastCountSyncAt;
  DateTime? get lastCountSyncAt => _lastCountSyncAt;

  /// Upserts the live count of active Spatially devices for the current volunteer.
  Future<void> updateVolunteerCount(int activeCount) async {
    if (!_initialized) return;

    final volunteerId = SessionState.instance.volunteerId;
    final zoneCode = SessionState.instance.zoneCode ?? SessionState.instance.zone;
    final eventId = SessionState.instance.eventId;

    if (volunteerId == null || zoneCode == null || eventId == null) {
      // Missing session information, ignore tick.
      return;
    }

    try {
      final supabaseInstance = Supabase.instance;
      final client = supabaseInstance.client;
      final table = client.from('volunteer_counts');
      final Map<String, dynamic> row = {
        'volunteer_id': volunteerId,
        'event_id': eventId,
        'zone': zoneCode,
        'active_count': activeCount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      // Upsert on primary key (volunteer_id)
      await table.upsert(row);
      _lastCountSyncAt = DateTime.now();
    } catch (e) {
      print('TelemetryService ERROR: Failed to update volunteer count: $e');
    }
  }
}
