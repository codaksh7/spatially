import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/operational_incident.dart';
import '../repositories/incident_repository.dart';
import '../services/session_state.dart';

class ReportIssueDialog extends StatefulWidget {
  final bool isNeedHelpMode;

  const ReportIssueDialog({
    super.key,
    this.isNeedHelpMode = false,
  });

  static Future<OperationalIncident?> show(
    BuildContext context, {
    bool isNeedHelpMode = false,
  }) {
    return showModalBottomSheet<OperationalIncident>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: ReportIssueDialog(isNeedHelpMode: isNeedHelpMode),
      ),
    );
  }

  @override
  State<ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReportIssueDialogState extends State<ReportIssueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();

  late IncidentCategory _selectedCategory;
  IncidentPriority _selectedPriority = IncidentPriority.normal;
  File? _selectedImage;
  bool _isUploading = false;
  bool _linkOperationalMessage = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.isNeedHelpMode) {
      _selectedCategory = IncidentCategory.operational;
      _titleController.text = 'Volunteer Assistance Needed';
      _selectedPriority = IncidentPriority.important;
    } else {
      _selectedCategory = IncidentCategory.crowd;
    }

    final zoneName = SessionState.instance.assignedZoneName;
    if (zoneName != null && zoneName.isNotEmpty) {
      _locationController.text = zoneName;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      String? uploadedUrl;
      if (_selectedImage != null) {
        uploadedUrl = await IncidentRepository.instance.uploadEvidence(_selectedImage!);
      }

      final session = SessionState.instance;
      final incident = await IncidentRepository.instance.reportIncident(
        category: _selectedCategory,
        priority: _selectedPriority,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        zoneId: session.assignedZoneId,
        venueZoneName: session.assignedZoneName,
        specificLocation: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        imageUrl: uploadedUrl,
        linkOperationalMessage: _linkOperationalMessage,
      );

      if (mounted) {
        Navigator.of(context).pop(incident);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: incident.isOfflineQueued ? const Color(0xFFD97706) : const Color(0xFF10B981),
            content: Text(
              incident.isOfflineQueued
                  ? 'Incident queued locally (offline). Will sync when connection returns.'
                  : 'Incident reported successfully.',
            ),
          ),
        );
      }
    } on UrgentOfflineException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error submitting report: $e';
        _isUploading = false;
      });
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
                Icon(
                  widget.isNeedHelpMode ? Icons.handshake_outlined : Icons.report_problem_outlined,
                  color: widget.isNeedHelpMode ? const Color(0xFF2563EB) : const Color(0xFFEA580C),
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.isNeedHelpMode ? 'Request Operational Help' : 'Report Operational Issue',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Form content
          Flexible(
            child: SingleChildScrollView(
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
                          border: Border.all(color: const Color(0xFFEF4444)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Priority Selector
                    const Text('Priority Level', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: IncidentPriority.values.map((priority) {
                        final isSelected = _selectedPriority == priority;
                        Color activeColor;
                        switch (priority) {
                          case IncidentPriority.urgent:
                            activeColor = const Color(0xFFDC2626);
                            break;
                          case IncidentPriority.important:
                            activeColor = const Color(0xFFD97706);
                            break;
                          case IncidentPriority.normal:
                            activeColor = const Color(0xFF2563EB);
                            break;
                        }

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () => setState(() => _selectedPriority = priority),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.3),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  priority.label,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black87),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_selectedPriority == IncidentPriority.urgent) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Urgent issues notify organizers immediately. Requires active connection.',
                                style: TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Category Selector
                    const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: IncidentCategory.values.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(cat.label, style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedCategory = cat);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Title Field
                    const Text('Title / Summary', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      maxLength: 100,
                      decoration: InputDecoration(
                        hintText: 'e.g., Gate 2 Crowd Congestion, Need Scanner Backup',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        counterText: '',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please provide a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description Field
                    const Text('Details & Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: 'Describe what happened, what assistance is required, and any relevant circumstances.',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please describe the issue';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Location Context
                    const Text('Location / Zone Context', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Main Entrance, Zone 701, Near Restroom 3',
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Photo Evidence
                    const Text('Photo Evidence (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    if (_selectedImage != null) ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImage!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                onPressed: () => setState(() => _selectedImage = null),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ] else ...[
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined, size: 18),
                            label: const Text('Take Photo'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: const Text('Gallery'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Link Operational Message
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Broadcast to Operational Communications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: const Text('Creates an escalation thread in Comms Center', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      value: _linkOperationalMessage,
                      onChanged: (val) => setState(() => _linkOperationalMessage = val),
                    ),
                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.isNeedHelpMode
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                widget.isNeedHelpMode ? 'Send Help Request' : 'Submit Issue Report',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
