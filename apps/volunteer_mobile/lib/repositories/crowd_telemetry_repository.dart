import '../models/ble_observation.dart';
import '../services/telemetry_service.dart';

abstract class CrowdTelemetryRepository {
  /// Sends a single BLE observation. Enforces privacy gate:
  /// non-Spatially ambient devices are dropped and never persisted.
  Future<void> sendObservation(BleObservation observation);

  /// Upserts the live active count of Spatially devices for the current volunteer.
  Future<void> updateVolunteerCount({
    required int activeCount,
    required String eventId,
    required String zone,
  });
}

class CrowdTelemetryRepositoryImpl implements CrowdTelemetryRepository {
  final TelemetryService _telemetryService;

  CrowdTelemetryRepositoryImpl({TelemetryService? telemetryService})
      : _telemetryService = telemetryService ?? TelemetryService();

  @override
  Future<void> sendObservation(BleObservation observation) async {
    // Privacy Gate: Never persist ambient non-Spatially BLE devices
    if (!observation.isSpatiallyDevice) {
      return;
    }
    await _telemetryService.sendObservation(observation);
  }

  @override
  Future<void> updateVolunteerCount({
    required int activeCount,
    required String eventId,
    required String zone,
  }) async {
    await _telemetryService.updateVolunteerCount(activeCount);
  }
}
