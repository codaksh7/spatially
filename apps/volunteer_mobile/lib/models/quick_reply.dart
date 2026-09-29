/// SPATIALLY — VOLUNTEER BLOCK 2.5A
/// Structured operational quick replies for fast staff communication.
library;

class QuickReplyOption {
  final String text;
  final String actionType;
  final bool isAffirmative;

  const QuickReplyOption({
    required this.text,
    required this.actionType,
    this.isAffirmative = true,
  });

  static const List<QuickReplyOption> defaultOptions = [
    QuickReplyOption(text: "Acknowledged.", actionType: 'ack', isAffirmative: true),
    QuickReplyOption(text: "On my way.", actionType: 'en_route', isAffirmative: true),
    QuickReplyOption(text: "I'm coming.", actionType: 'coming', isAffirmative: true),
    QuickReplyOption(text: "Received.", actionType: 'received', isAffirmative: true),
    QuickReplyOption(text: "Issue resolved.", actionType: 'resolved', isAffirmative: true),
    QuickReplyOption(text: "I can't assist.", actionType: 'declined', isAffirmative: false),
    QuickReplyOption(text: "Need organizer.", actionType: 'escalate_organizer', isAffirmative: false),
    QuickReplyOption(text: "Need another volunteer.", actionType: 'request_backup', isAffirmative: false),
  ];
}
