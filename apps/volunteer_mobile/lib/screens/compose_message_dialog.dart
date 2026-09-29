import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/operational_message.dart';
import '../models/quick_reply.dart';
import '../models/volunteer_directory_entry.dart';
import '../repositories/operational_communication_repository.dart';
import '../services/session_state.dart';

class ComposeMessageSheet extends StatefulWidget {
  final OperationalCommunicationRepository repository;
  final String eventId;
  final VolunteerDirectoryEntry? preselectedRecipient;
  final OperationalTargetType? initialTargetType;

  const ComposeMessageSheet({
    super.key,
    required this.repository,
    required this.eventId,
    this.preselectedRecipient,
    this.initialTargetType,
  });

  @override
  State<ComposeMessageSheet> createState() => _ComposeMessageSheetState();
}

class _ComposeMessageSheetState extends State<ComposeMessageSheet> {
  final TextEditingController _bodyController = TextEditingController();
  late OperationalTargetType _targetType;
  OperationalPriority _priority = OperationalPriority.normal;
  bool _requiresAck = false;
  VolunteerDirectoryEntry? _selectedRecipient;
  List<VolunteerDirectoryEntry> _directory = [];
  bool _isLoadingDirectory = false;
  bool _isSending = false;
  String? _errorMessage;

  bool get _isOrganizerOrAdmin =>
      SessionState.instance.userRole == 'organizer' ||
      SessionState.instance.userRole == 'admin';

  @override
  void initState() {
    super.initState();
    _selectedRecipient = widget.preselectedRecipient;
    if (_selectedRecipient != null) {
      _targetType = OperationalTargetType.volunteer;
    } else {
      _targetType = widget.initialTargetType ?? OperationalTargetType.organizer;
    }

    if (_targetType == OperationalTargetType.volunteer && _selectedRecipient == null) {
      _loadDirectory();
    }
  }

  Future<void> _loadDirectory() async {
    setState(() => _isLoadingDirectory = true);
    try {
      final list = await widget.repository.getVolunteerDirectory(widget.eventId);
      if (mounted) {
        setState(() {
          _directory = list.where((v) => v.volunteerId != SessionState.instance.volunteerId).toList();
          _isLoadingDirectory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDirectory = false);
    }
  }

  Future<void> _submitMessage() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      setState(() => _errorMessage = 'Please enter a message.');
      return;
    }

    if (_targetType == OperationalTargetType.volunteer && _selectedRecipient == null) {
      setState(() => _errorMessage = 'Please select a recipient volunteer.');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final msg = await widget.repository.sendMessage(
        eventId: widget.eventId,
        targetType: _targetType,
        body: body,
        targetId: _targetType == OperationalTargetType.volunteer ? _selectedRecipient?.volunteerId : null,
        zoneId: _targetType == OperationalTargetType.zone ? SessionState.instance.zoneId : null,
        messageType: _priority == OperationalPriority.urgent ? 'escalation' : 'operational',
        priority: _priority,
        requiresAcknowledgment: _requiresAck,
      );

      if (mounted) {
        Navigator.of(context).pop(msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.isLocalQueued
                  ? 'Offline: Message queued locally. Will send when connection returns.'
                  : 'Operational message sent successfully.',
            ),
            backgroundColor: msg.isLocalQueued ? Colors.amber.shade800 : Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zoneName = SessionState.instance.zoneName ?? 'Assigned Zone';

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.send_rounded, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  'Compose Operational Message',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Target Scope Selector
            Text(
              'RECIPIENT / SCOPE',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Organizer / Ops'),
                  selected: _targetType == OperationalTargetType.organizer,
                  onSelected: (selected) {
                    if (selected) setState(() => _targetType = OperationalTargetType.organizer);
                  },
                ),
                ChoiceChip(
                  label: Text('Zone ($zoneName)'),
                  selected: _targetType == OperationalTargetType.zone,
                  onSelected: (selected) {
                    if (selected) setState(() => _targetType = OperationalTargetType.zone);
                  },
                ),
                ChoiceChip(
                  label: const Text('Direct Volunteer'),
                  selected: _targetType == OperationalTargetType.volunteer,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _targetType = OperationalTargetType.volunteer);
                      if (_directory.isEmpty) _loadDirectory();
                    }
                  },
                ),
                if (_isOrganizerOrAdmin)
                  ChoiceChip(
                    label: const Text('Event Broadcast'),
                    selected: _targetType == OperationalTargetType.event,
                    onSelected: (selected) {
                      if (selected) setState(() => _targetType = OperationalTargetType.event);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // If Direct Volunteer, show Directory Recipient Picker
            if (_targetType == OperationalTargetType.volunteer) ...[
              if (_isLoadingDirectory)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(),
                )
              else if (_directory.isEmpty && _selectedRecipient == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No other volunteers found in this event.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                )
              else
                DropdownButtonFormField<VolunteerDirectoryEntry>(
                  initialValue: _selectedRecipient,
                  decoration: InputDecoration(
                    labelText: 'Select Staff Recipient',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: _directory.map((v) {
                    return DropdownMenuItem(
                      value: v,
                      child: Text('${v.fullName} (${v.assignmentLabel})'),
                    );
                  }).toList(),
                  onChanged: (entry) {
                    setState(() => _selectedRecipient = entry);
                  },
                ),
              const SizedBox(height: 12),
            ],

            // Priority Selector
            Text(
              'PRIORITY LEVEL',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _priority = OperationalPriority.normal),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _priority == OperationalPriority.normal ? Colors.blue.shade50 : null,
                      side: BorderSide(
                        color: _priority == OperationalPriority.normal ? Colors.blue.shade700 : Colors.grey.shade300,
                        width: _priority == OperationalPriority.normal ? 2 : 1,
                      ),
                    ),
                    child: const Text('Normal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _priority = OperationalPriority.important),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _priority == OperationalPriority.important ? Colors.amber.shade50 : null,
                      side: BorderSide(
                        color: _priority == OperationalPriority.important ? Colors.amber.shade800 : Colors.grey.shade300,
                        width: _priority == OperationalPriority.important ? 2 : 1,
                      ),
                    ),
                    child: Text('Important', style: TextStyle(color: Colors.amber.shade900)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _priority = OperationalPriority.urgent),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _priority == OperationalPriority.urgent ? Colors.red.shade50 : null,
                      side: BorderSide(
                        color: _priority == OperationalPriority.urgent ? Colors.red.shade700 : Colors.grey.shade300,
                        width: _priority == OperationalPriority.urgent ? 2 : 1,
                      ),
                    ),
                    child: const Text('Urgent', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Acknowledgment Checkbox
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Require Recipient Acknowledgment',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Recipients must tap "Acknowledge" to confirm receipt',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              value: _requiresAck,
              onChanged: (val) => setState(() => _requiresAck = val ?? false),
            ),
            const SizedBox(height: 8),

            // Quick Reply Templates
            Text(
              'QUICK TEMPLATES',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: QuickReplyOption.defaultOptions.map((opt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      label: Text(opt.text, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _bodyController.text = opt.text;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Message Body Field
            TextField(
              controller: _bodyController,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Enter operational instruction or request...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                counterText: '${_bodyController.text.length}/1000',
              ),
              onChanged: (_) => setState(() {}),
            ),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Submit Button
            ElevatedButton(
              onPressed: _isSending ? null : _submitMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: _priority == OperationalPriority.urgent ? Colors.red.shade700 : Colors.indigo.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _priority == OperationalPriority.urgent
                          ? 'Broadcast Urgent Alert'
                          : 'Send Message',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
