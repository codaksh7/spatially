/// Strongly-typed result from public.check_in_ticket RPC.
class TicketCheckInResult {
  final bool success;
  final String? errorCode;
  final String message;
  final String? ticketId;
  final String? ticketCode;
  final String? eventId;
  final String? eventName;
  final DateTime? checkedInAt;
  final String? checkedInBy;
  final bool isOfflineQueued;

  const TicketCheckInResult({
    required this.success,
    this.errorCode,
    required this.message,
    this.ticketId,
    this.ticketCode,
    this.eventId,
    this.eventName,
    this.checkedInAt,
    this.checkedInBy,
    this.isOfflineQueued = false,
  });

  factory TicketCheckInResult.fromRpc(Map<String, dynamic> json) {
    return TicketCheckInResult(
      success: json['success'] as bool? ?? false,
      errorCode: json['error_code'] as String?,
      message: json['message'] as String? ?? '',
      ticketId: json['ticket_id'] as String?,
      ticketCode: json['ticket_code'] as String?,
      eventId: json['event_id'] as String?,
      eventName: json['event_name'] as String?,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.tryParse(json['checked_in_at'].toString())?.toLocal()
          : null,
      checkedInBy: json['checked_in_by'] as String?,
      isOfflineQueued: false,
    );
  }

  factory TicketCheckInResult.offlineQueued({
    required String ticketCode,
    required String eventId,
  }) {
    return TicketCheckInResult(
      success: true,
      message: 'Ticket recorded offline (pending server sync)',
      ticketCode: ticketCode,
      eventId: eventId,
      checkedInAt: DateTime.now(),
      isOfflineQueued: true,
    );
  }
}
