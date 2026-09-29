/// Represents an attendee's participation record in a past or active event.
/// 
/// Strictly distinguishes between REGISTERED (ticket purchased) and ATTENDED (physically checked in).
class EventHistoryItem {
  final String eventId;
  final String ticketId;
  final String eventName;
  final String venue;
  final DateTime eventDate;
  final String ticketStatus; // 'checked_in' | 'purchased'
  final String ticketCode;
  final bool isLive;
  final bool isEnded;
  final DateTime? checkedInAt;

  const EventHistoryItem({
    required this.eventId,
    required this.ticketId,
    required this.eventName,
    required this.venue,
    required this.eventDate,
    required this.ticketStatus,
    required this.ticketCode,
    this.isLive = false,
    this.isEnded = false,
    this.checkedInAt,
  });

  /// Whether the attendee was verified as present / checked in at the event.
  bool get isAttended => ticketStatus.toLowerCase() == 'checked_in';

  /// Whether the attendee is registered but has not yet checked in.
  bool get isRegisteredOnly => !isAttended;
}
