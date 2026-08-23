class BleObservation {
  final String ephemeralId;
  final int rssi;
  final DateTime scannedAt;
  final bool isSpatiallyDevice;
  final String? volunteerId;
  final String? zone;

  BleObservation({
    required this.ephemeralId,
    required this.rssi,
    required this.scannedAt,
    this.isSpatiallyDevice = false,
    this.volunteerId,
    this.zone,
  });

  Map<String, dynamic> toMap() {
    return {
      'ephemeral_id': ephemeralId,
      'rssi': rssi,
      'scanned_at': scannedAt.toIso8601String(),
      'is_spatially_device': isSpatiallyDevice,
      'volunteer_id': volunteerId,
      'zone': zone,
    };
  }
}
