import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';
import '../data/profile_repository.dart';
import '../models/user_profile.dart';

/// Screen allowing attendees to edit personal identity, headline, organization, bio, and interests.
class EditProfileScreen extends StatefulWidget {
  final UserProfile initialProfile;
  final ProfileRepository repository;

  const EditProfileScreen({
    super.key,
    required this.initialProfile,
    required this.repository,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _headlineController;
  late TextEditingController _orgController;
  late TextEditingController _bioController;

  late List<String> _selectedInterests;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile.name);
    _headlineController = TextEditingController(text: widget.initialProfile.headline);
    _orgController = TextEditingController(text: widget.initialProfile.organization);
    _bioController = TextEditingController(text: widget.initialProfile.bio);
    _selectedInterests = List<String>.from(widget.initialProfile.interests);

    _nameController.addListener(() {
      setState(() {}); // Update avatar initials preview
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headlineController.dispose();
    _orgController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String get _avatarInitials {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'A';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final updated = widget.initialProfile.copyWith(
      name: _nameController.text.trim(),
      headline: _headlineController.text.trim(),
      organization: _orgController.text.trim(),
      bio: _bioController.text.trim(),
      interests: _selectedInterests,
      isAnonymous: _nameController.text.trim().isEmpty || _nameController.text.trim() == 'Attendee Guest',
      updatedAt: DateTime.now(),
    );

    await widget.repository.saveProfile(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully'),
          backgroundColor: SpatiallyColors.success,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop(updated);
    }
  }

  void _showInterestsSelector() {
    final available = widget.repository.getAvailableInterests();
    final tempInterests = List<String>.from(_selectedInterests);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final theme = Theme.of(modalCtx);
            final isDark = theme.brightness == Brightness.dark;
            final bg = isDark ? SpatiallyColors.darkSurfaceElevated : SpatiallyColors.lightSurface;
            final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
            final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(SpatiallyRadius.lg)),
              ),
              padding: const EdgeInsets.all(SpatiallySpacing.lg),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalCtx).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Topics & Interests',
                        style: SpatiallyTypography.sectionHeading(color: textPrimary),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textSecondary),
                        onPressed: () => Navigator.of(modalCtx).pop(),
                      ),
                    ],
                  ),
                  SpatiallySpacing.gapVerticalXs,
                  Text(
                    'Topics guide future matchmaking and session recommendations.',
                    style: SpatiallyTypography.caption(color: textSecondary),
                  ),
                  SpatiallySpacing.gapVerticalMd,
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: SpatiallySpacing.sm,
                        runSpacing: SpatiallySpacing.sm,
                        children: available.map((topic) {
                          final isSelected = tempInterests.contains(topic);
                          return FilterChip(
                            label: Text(topic),
                            selected: isSelected,
                            selectedColor: SpatiallyColors.violet.withValues(alpha: 0.2),
                            checkmarkColor: SpatiallyColors.violet,
                            labelStyle: SpatiallyTypography.caption(
                              color: isSelected ? SpatiallyColors.violet : textPrimary,
                            ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
                            backgroundColor: isDark
                                ? SpatiallyColors.darkSurfaceElevated
                                : SpatiallyColors.lightBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(SpatiallyRadius.full),
                              side: BorderSide(
                                color: isSelected
                                    ? SpatiallyColors.violet
                                    : (isDark
                                        ? SpatiallyColors.darkBorderSubdued
                                        : SpatiallyColors.lightBorderSubdued),
                              ),
                            ),
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  tempInterests.add(topic);
                                } else {
                                  tempInterests.remove(topic);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SpatiallySpacing.gapVerticalMd,
                  SpatiallyPrimaryButton(
                    label: 'Apply Topics (${tempInterests.length})',
                    useGradient: true,
                    onPressed: () {
                      setState(() {
                        _selectedInterests = tempInterests;
                      });
                      Navigator.of(modalCtx).pop();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    return Scaffold(
      appBar: SpatiallyAppBar(
        title: 'Edit Profile',
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _handleSave,
            child: Text(
              'Save',
              style: SpatiallyTypography.body(color: SpatiallyColors.violet).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: SpatiallySpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar preview
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: SpatiallyColors.brandGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: SpatiallyColors.violet.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _avatarInitials,
                            style: SpatiallyTypography.headingLarge(color: Colors.white).copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SpatiallySpacing.gapVerticalSm,
                      Text(
                        'Initials Avatar',
                        style: SpatiallyTypography.caption(color: textSecondary),
                      ),
                    ],
                  ),
                ),

                SpatiallySpacing.gapVerticalLg,

                // Full Name
                Text(
                  'FULL NAME *',
                  style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                SpatiallySpacing.gapVerticalXs,
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  style: SpatiallyTypography.body(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Alex Rivera',
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),

                SpatiallySpacing.gapVerticalMd,

                // Professional Headline
                Text(
                  'PROFESSIONAL HEADLINE',
                  style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                SpatiallySpacing.gapVerticalXs,
                TextFormField(
                  controller: _headlineController,
                  textInputAction: TextInputAction.next,
                  maxLength: 60,
                  style: SpatiallyTypography.body(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Lead Mobile Architect',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                    ),
                  ),
                ),

                SpatiallySpacing.gapVerticalSm,

                // Organization / Affiliation
                Text(
                  'ORGANIZATION / UNIVERSITY',
                  style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                SpatiallySpacing.gapVerticalXs,
                TextFormField(
                  controller: _orgController,
                  textInputAction: TextInputAction.next,
                  maxLength: 60,
                  style: SpatiallyTypography.body(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. NextGen Robotics Corp',
                    prefixIcon: const Icon(Icons.business_outlined, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                    ),
                  ),
                ),

                SpatiallySpacing.gapVerticalSm,

                // Short Bio
                Text(
                  'SHORT BIO',
                  style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                SpatiallySpacing.gapVerticalXs,
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  maxLength: 200,
                  textInputAction: TextInputAction.done,
                  style: SpatiallyTypography.body(color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Briefly describe your background or what you hope to discover at the event...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                    ),
                  ),
                ),

                SpatiallySpacing.gapVerticalMd,

                // Interests & Topics
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOPICS OF INTEREST',
                      style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showInterestsSelector,
                      icon: const Icon(Icons.edit_outlined, size: 16, color: SpatiallyColors.violet),
                      label: Text(
                        'Edit Topics',
                        style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SpatiallySpacing.gapVerticalXs,

                if (_selectedInterests.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(SpatiallySpacing.md),
                    decoration: BoxDecoration(
                      color: isDark
                          ? SpatiallyColors.darkSurfaceElevated
                          : SpatiallyColors.lightBackground,
                      borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                      border: Border.all(
                        color: isDark ? SpatiallyColors.darkBorderSubdued : SpatiallyColors.lightBorderSubdued,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'No topics selected. Tap "Edit Topics" to choose your interests.',
                        style: SpatiallyTypography.caption(color: textSecondary),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: SpatiallySpacing.xs,
                    runSpacing: SpatiallySpacing.xs,
                    children: _selectedInterests.map((interest) {
                      return Chip(
                        label: Text(interest),
                        labelStyle: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: SpatiallyColors.violet.withValues(alpha: 0.12),
                        deleteIcon: const Icon(Icons.close_rounded, size: 14, color: SpatiallyColors.violet),
                        onDeleted: () {
                          setState(() {
                            _selectedInterests.remove(interest);
                          });
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SpatiallyRadius.full),
                          side: const BorderSide(color: Colors.transparent),
                        ),
                      );
                    }).toList(),
                  ),

                SpatiallySpacing.gapVerticalXl,

                // Primary Save Button
                SpatiallyPrimaryButton(
                  label: 'Save Profile Changes',
                  useGradient: true,
                  isLoading: _isSaving,
                  onPressed: _handleSave,
                ),

                SpatiallySpacing.gapVerticalMd,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
