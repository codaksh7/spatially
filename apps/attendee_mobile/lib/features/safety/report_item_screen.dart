import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import 'data/lost_found_repository.dart';
import 'models/safety_models.dart';

/// Screen allowing attendees to report a lost or found item.
class ReportItemScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  final LostFoundType initialType;

  const ReportItemScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    this.initialType = LostFoundType.lost,
  });

  @override
  State<ReportItemScreen> createState() => _ReportItemScreenState();
}

class _ReportItemScreenState extends State<ReportItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final LostFoundRepository _repository = LostFoundRepositoryImpl();

  late LostFoundType _selectedType;
  LostFoundCategory _selectedCategory = LostFoundCategory.phone;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _specificLocationController = TextEditingController();

  String _selectedZoneId = '712';
  String _selectedZoneName = 'Room 712 • Foyer & Registration';
  bool _hasMockPhotoAttached = false;
  bool _isSubmitting = false;

  final List<Map<String, String>> _venueZones = [
    {'id': '701', 'name': 'Room 701 • Auditorium'},
    {'id': '702', 'name': 'Room 702 • Project Exhibition Hall A'},
    {'id': '706', 'name': 'Room 706 • Project Exhibition Hall B'},
    {'id': '707', 'name': 'Room 707 • Workshop & Labs'},
    {'id': '711', 'name': 'Room 711 • Seminar Room'},
    {'id': '712', 'name': 'Room 712 • Foyer & Registration'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _specificLocationController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final report = await _repository.submitReport(
        eventId: widget.eventId,
        type: _selectedType,
        category: _selectedCategory,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        venueZoneId: _selectedZoneId,
        venueZoneName: _selectedZoneName,
        specificLocation: _specificLocationController.text.trim().isNotEmpty
            ? _specificLocationController.text.trim()
            : null,
        imagePlaceholderName: _hasMockPhotoAttached ? 'item_attachment.jpg' : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedType.label} report created successfully!',
          ),
          backgroundColor: SpatiallyColors.success,
        ),
      );

      Navigator.of(context).pop(report);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: SpatiallyColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Scaffold(
      appBar: SpatiallyAppBar(
        title: _selectedType == LostFoundType.lost ? 'Report Lost Item' : 'Report Found Item',
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: SpatiallySpacing.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event Context Strip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpatiallySpacing.md,
                  vertical: SpatiallySpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: SpatiallyColors.violet.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available_rounded, size: 16, color: SpatiallyColors.violet),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Event Context: ${widget.eventName}',
                        style: SpatiallyTypography.caption(color: textPrimary).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              SpatiallySpacing.gapVerticalMd,

              // Segmented selector: Lost vs Found
              SegmentedButton<LostFoundType>(
                segments: const [
                  ButtonSegment(
                    value: LostFoundType.lost,
                    label: Text('I Lost an Item'),
                    icon: Icon(Icons.search_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: LostFoundType.found,
                    label: Text('I Found an Item'),
                    icon: Icon(Icons.check_circle_outline_rounded, size: 16),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (set) {
                  if (set.isNotEmpty) {
                    setState(() {
                      _selectedType = set.first;
                    });
                  }
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpatiallyRadius.sm)),
                  ),
                ),
              ),

              SpatiallySpacing.gapVerticalLg,

              // Category Selector
              Text(
                'ITEM CATEGORY',
                style: SpatiallyTypography.badge(color: textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: LostFoundCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    avatar: Icon(
                      cat.icon,
                      size: 16,
                      color: isSelected ? Colors.white : textSecondary,
                    ),
                    label: Text(cat.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      }
                    },
                    selectedColor: SpatiallyColors.violet,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                    backgroundColor: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
                  );
                }).toList(),
              ),

              SpatiallySpacing.gapVerticalLg,

              // Item Title
              Text(
                'ITEM TITLE',
                style: SpatiallyTypography.badge(color: textSecondary),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                style: SpatiallyTypography.body(color: textPrimary),
                decoration: InputDecoration(
                  hintText: _selectedType == LostFoundType.lost
                      ? 'e.g. Navy Blue HydroFlask Water Bottle'
                      : 'e.g. Set of 3 Keys with Yellow Tag',
                  filled: true,
                  fillColor: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                    borderSide: BorderSide(
                      color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a brief item title';
                  }
                  return null;
                },
              ),

              SpatiallySpacing.gapVerticalMd,

              // Detailed Description
              Text(
                'DESCRIPTION & DISTINGUISHING MARKS',
                style: SpatiallyTypography.badge(color: textSecondary),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                style: SpatiallyTypography.body(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Include color, brand, stickers, scratches, or other identifiable details.',
                  filled: true,
                  fillColor: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                    borderSide: BorderSide(
                      color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued,
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 8) {
                    return 'Please provide a helpful description (at least 8 characters)';
                  }
                  return null;
                },
              ),

              SpatiallySpacing.gapVerticalLg,

              // Venue Area Selector
              Text(
                _selectedType == LostFoundType.lost ? 'LAST SEEN VENUE AREA' : 'FOUND VENUE AREA',
                style: SpatiallyTypography.badge(color: textSecondary),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedZoneId,
                dropdownColor: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                  ),
                ),
                items: _venueZones.map((z) {
                  return DropdownMenuItem<String>(
                    value: z['id'],
                    child: Text(
                      z['name']!,
                      style: SpatiallyTypography.body(color: textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final item = _venueZones.firstWhere((z) => z['id'] == val);
                    setState(() {
                      _selectedZoneId = val;
                      _selectedZoneName = item['name']!;
                    });
                  }
                },
              ),

              SpatiallySpacing.gapVerticalMd,

              // Specific Location (Optional)
              Text(
                'SPECIFIC LOCATION NOTES (OPTIONAL)',
                style: SpatiallyTypography.badge(color: textSecondary),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _specificLocationController,
                style: SpatiallyTypography.body(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Left aisle Row 4, or under charging bench',
                  filled: true,
                  fillColor: isDark ? SpatiallyColors.darkSurface : SpatiallyColors.lightSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                  ),
                ),
              ),

              SpatiallySpacing.gapVerticalLg,

              // Photo Attachment Section (Controlled Demo Boundary)
              SpatiallyCard(
                padding: const EdgeInsets.all(SpatiallySpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.photo_camera_outlined, size: 20, color: textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Photo Attachment (Demo)',
                          style: SpatiallyTypography.subheading(color: textPrimary).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Attach a clear photo of the item if safely accessible.',
                      style: SpatiallyTypography.caption(color: textSecondary),
                    ),
                    const SizedBox(height: 12),
                    if (_hasMockPhotoAttached)
                      Container(
                        padding: const EdgeInsets.all(SpatiallySpacing.sm),
                        decoration: BoxDecoration(
                          color: SpatiallyColors.spatialCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: SpatiallyColors.spatialCyan, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sample item image attached (item_attachment.jpg)',
                                style: SpatiallyTypography.caption(color: textPrimary).copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              color: textSecondary,
                              onPressed: () {
                                setState(() {
                                  _hasMockPhotoAttached = false;
                                });
                              },
                            ),
                          ],
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _hasMockPhotoAttached = true;
                          });
                        },
                        icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                        label: const Text('Simulate Photo Capture'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SpatiallyColors.spatialCyan,
                          side: const BorderSide(color: SpatiallyColors.spatialCyan),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              SpatiallySpacing.gapVerticalLg,

              // Trust & Privacy Advisory
              Container(
                padding: const EdgeInsets.all(SpatiallySpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? SpatiallyColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                  border: Border.all(
                    color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 18, color: SpatiallyColors.violet),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reports are verified on-site by event staff and volunteers. Items handed to Help Desk are tagged and stored securely. Never record confidential passwords or PINs.',
                        style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                          height: 1.35,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SpatiallySpacing.gapVerticalXl,

              // Submit Button
              SpatiallyPrimaryButton(
                label: _isSubmitting ? 'Submitting Report...' : 'Submit ${_selectedType.label}',
                onPressed: _isSubmitting ? null : _handleSubmit,
              ),

              SpatiallySpacing.gapVerticalXxl,
            ],
          ),
        ),
      ),
    );
  }
}
