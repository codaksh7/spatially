/// Represents a queued offline ticket check-in stored in local SQLite.
class OfflineCheckInRecord {
  final int? id;
  final String operationId;
  final String ticketCode;
  final String eventId;
  final String? volunteerId;
  final DateTime scannedAt;
  final String syncStatus; // 'pending', 'synced', 'rejected', 'conflict'
  final String? errorMessage;

  const OfflineCheckInRecord({
    this.id,
    required this.operationId,
    required this.ticketCode,
    required this.eventId,
    this.volunteerId,
    required this.scannedAt,
    this.syncStatus = 'pending',
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'operation_id': operationId,
      'ticket_code': ticketCode,
      'event_id': eventId,
      if (volunteerId != null) 'volunteer_id': volunteerId,
      'scanned_at': scannedAt.toIso8601String(),
      'sync_status': syncStatus,
      'error_message': errorMessage,
    };
  }

  factory OfflineCheckInRecord.fromMap(Map<String, dynamic> map) {
    return OfflineCheckInRecord(
      id: map['id'] as int?,
      operationId: map['operation_id'] as String,
      ticketCode: map['ticket_code'] as String,
      eventId: map['event_id'] as String,
      volunteerId: map['volunteer_id'] as String?,
      scannedAt: DateTime.parse(map['scanned_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'pending',
      errorMessage: map['error_message'] as String?,
    );
  }
}
