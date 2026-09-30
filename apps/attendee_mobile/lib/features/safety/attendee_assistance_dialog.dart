import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../design_system/design_system.dart';
import '../../services/attendee_identity.dart';

class AttendeeAssistanceDialog extends StatefulWidget {
  final String eventId;
  final String eventName;

  const AttendeeAssistanceDialog({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  static Future<void> show(
    BuildContext context, {
    required String eventId,
    required String eventName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: AttendeeAssistanceDialog(eventId: eventId, eventName: eventName),
      ),
    );
  }

  @override
  State<AttendeeAssistanceDialog> createState() => _AttendeeAssistanceDialogState();
}

class _AttendeeAssistanceDialogState extends State<AttendeeAssistanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedCategory = 'attendee_assistance';
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _viewHistory = false;
  List<Map<String, dynamic>> _myRequests = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final deviceId = AttendeeIdentity.deviceId;
      final res = await Supabase.instance.client.rpc(
        'get_attendee_assistance_status',
        params: {
          'p_event_id': widget.eventId,
          'p_device_id': deviceId,
        },
      );
      if (mounted) {
        setState(() {
          _myRequests = List<Map<String, dynamic>>.from(res as List);
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final deviceId = AttendeeIdentity.deviceId;
      final res = await Supabase.instance.client.rpc(
        'request_attendee_assistance',
        params: {
          'p_event_id': widget.eventId,
          'p_category': _selectedCategory,
          'p_title': _titleController.text.trim(),
          'p_description': _descController.text.trim(),
          'p_specific_location': _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          'p_device_id': deviceId,
        },
      );

      if (res is Map<String, dynamic> && res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF10B981),
              content: Text('Assistance request sent to on-site event staff.'),
            ),
          );
          setState(() {
            _viewHistory = true;
            _isSubmitting = false;
          });
          _loadHistory();
        }
      } else {
        throw Exception('Submission failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to submit request: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.support_agent_rounded, color: SpatiallyColors.violet, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _viewHistory ? 'My Assistance Requests' : 'Request Staff Assistance',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _viewHistory = !_viewHistory);
                    if (_viewHistory) _loadHistory();
                  },
                  child: Text(_viewHistory ? 'New Request' : 'Status (${_myRequests.length})'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Flexible(
            child: _viewHistory ? _buildHistoryView() : _buildFormView(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
              ),
              const SizedBox(height: 14),
            ],

            const Text(
              'Need help from event staff or volunteers? Submit a request and active on-site personnel will respond.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Category selector
            const Text('What do you need help with?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCategoryChip('General Help', 'attendee_assistance'),
                _buildCategoryChip('Accessibility', 'accessibility'),
                _buildCategoryChip('Directions / Lost', 'operational'),
                _buildCategoryChip('Lost Property', 'lost_found'),
                _buildCategoryChip('Medical Support', 'medical'),
              ],
            ),
            if (_selectedCategory == 'medical') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.local_hospital, color: Color(0xFFDC2626), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'FOR LIFE-THREATENING EMERGENCIES: Call local emergency services (911/112) immediately. This app dispatches venue first-aid volunteers only.',
                        style: TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Title
            const Text('Summary', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g., Need wheelchair ramp access, Lost backpack in Hall A',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a summary' : null,
            ),
            const SizedBox(height: 16),

            // Description
            const Text('Details & Contact Information', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe your situation and how staff can identify or reach you.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter details' : null,
            ),
            const SizedBox(height: 16),

            // Location
            const Text('Where are you right now?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'e.g., Near Booth 14, Entrance Hallway, Row G Auditorium',
                prefixIcon: const Icon(Icons.pin_drop_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpatiallyColors.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value) {
    final isSelected = _selectedCategory == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedCategory = value);
      },
    );
  }

  Widget _buildHistoryView() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myRequests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('You have not submitted any assistance requests for this event.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _myRequests.length,
      separatorBuilder: (context, i) => const SizedBox(height: 12),
      itemBuilder: (ctx, index) {
        final req = _myRequests[index];
        final status = req['status']?.toString() ?? 'open';
        final title = req['title']?.toString() ?? 'Assistance';
        final desc = req['description']?.toString() ?? '';
        final staffName = req['assigned_to_name']?.toString();
        final resolution = req['resolution_notes']?.toString();

        Color statusColor;
        String statusLabel;
        switch (status) {
          case 'open':
            statusColor = Colors.blue;
            statusLabel = 'Submitted • Waiting for Staff';
            break;
          case 'acknowledged':
            statusColor = Colors.amber.shade800;
            statusLabel = 'Acknowledged by Operations';
            break;
          case 'assigned':
          case 'in_progress':
            statusColor = Colors.purple;
            statusLabel = staffName != null ? 'Staff Coming: $staffName' : 'Staff Assigned';
            break;
          case 'resolved':
          case 'closed':
            statusColor = Colors.green;
            statusLabel = 'Resolved';
            break;
          default:
            statusColor = Colors.grey;
            statusLabel = status;
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                if (resolution != null && resolution.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Staff Response: $resolution', style: const TextStyle(fontSize: 12, color: Color(0xFF166534))),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
