import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../design_system/design_system.dart';
import '../../services/attendee_identity.dart';
import '../../services/offline_service.dart';
import '../explore/data/event_cache_manager.dart';
import '../explore/models/spatially_event.dart';
import '../profile/data/profile_repository.dart';
import '../profile/models/profile_preferences.dart';
import 'attendee_assistance_dialog.dart';
import 'data/safety_repository.dart';
import 'lost_found_screen.dart';
import 'models/safety_models.dart';
import 'widgets/safety_action_card.dart';
import 'widgets/safety_resource_tile.dart';

/// Spatially Attendee Safety, Emergency & Venue Help Hub.
/// 
/// Provides authoritative venue safety resources, one-tap Map wayfinding to
/// medical/security/exit POIs, Lost & Found management, and accessibility status.
class SafetyScreen extends StatefulWidget {
  final SpatiallyEvent? event;

  const SafetyScreen({
    super.key,
    this.event,
  });

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  final SafetyRepository _safetyRepo = SafetyRepositoryImpl();
  final ProfileRepository _profileRepo = ProfileRepositoryImpl();

  SpatiallyEvent? _currentEvent;
  List<SafetyResource> _emergencyActions = [];
  List<SafetyResource> _venueHelpResources = [];
  List<EmergencyContact> _emergencyContacts = [];
  ProfilePreferences _preferences = ProfilePreferences.defaults();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Resolve event context if not provided
      if (_currentEvent == null) {
        await _resolveEventContext();
      }

      // 2. Load safety resources and contacts
      final emergency = await _safetyRepo.getEmergencyActions();
      final help = await _safetyRepo.getVenueHelpResources();
      final contacts = await _safetyRepo.getEmergencyContacts();
      final prefs = await _profileRepo.getPreferences();

      if (mounted) {
        setState(() {
          _emergencyActions = emergency;
          _venueHelpResources = help;
          _emergencyContacts = contacts;
          _preferences = prefs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resolveEventContext() async {
    try {
      final isOnline = await OfflineService().checkConnectivity();
      if (!isOnline) {
        final cached = await EventCacheManager().getCachedPrimaryEvent();
        if (cached != null) {
          _currentEvent = SpatiallyEvent.fromJson(cached);
        }
        return;
      }

      final attendeeId = AttendeeIdentity.deviceId;
      if (attendeeId != null) {
        final ticketData = await Supabase.instance.client
            .from('tickets')
            .select('*, events(*)')
            .eq('attendee_id', attendeeId)
            .order('purchased_at', ascending: false)
            .timeout(const Duration(seconds: 4));

        if (ticketData.isNotEmpty) {
          for (final row in ticketData) {
            final evMap = row['events'];
            if (evMap is Map<String, dynamic>) {
              final ev = SpatiallyEvent.fromJson(evMap);
              if (ev.isLive) {
                _currentEvent = ev;
                return;
              } else if (_currentEvent == null && ev.isUpcoming) {
                _currentEvent = ev;
              }
            }
          }
        }
      }

      if (_currentEvent == null) {
        final liveEvents = await Supabase.instance.client
            .from('events')
            .select()
            .eq('status', 'live')
            .limit(1)
            .timeout(const Duration(seconds: 3));

        if (liveEvents.isNotEmpty) {
          _currentEvent = SpatiallyEvent.fromJson(Map<String, dynamic>.from(liveEvents.first));
        }
      }
    } catch (_) {
      final cached = await EventCacheManager().getCachedPrimaryEvent();
      if (cached != null) {
        _currentEvent = SpatiallyEvent.fromJson(cached);
      }
    }
  }

  Future<void> _toggleStepFree(bool enable) async {
    final updated = _preferences.copyWith(preferStepFreeRoutes: enable);
    setState(() {
      _preferences = updated;
    });
    await _profileRepo.savePreferences(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? SpatiallyColors.darkTextPrimary : SpatiallyColors.lightTextPrimary;
    final textSecondary = isDark ? SpatiallyColors.darkTextSecondary : SpatiallyColors.lightTextSecondary;

    final eventTitle = _currentEvent?.name ?? 'Spatially Demo Venue';
    final eventId = _currentEvent?.id ?? 'demo_event';

    return Scaffold(
      appBar: SpatiallyAppBar(
        title: 'Safety & Venue Help',
        automaticallyImplyLeading: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              color: SpatiallyColors.violet,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: SpatiallySpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!OfflineService().isOnline) ...[
                      const SpatiallyOfflineBanner(
                        message: 'Offline Mode • Venue safety resources, medical, security & exits available',
                      ),
                    ],

                    // Context Event Strip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpatiallySpacing.md,
                        vertical: SpatiallySpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: SpatiallyColors.navySurface.withValues(alpha: isDark ? 0.6 : 0.08),
                        borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                        border: Border.all(
                          color: SpatiallyColors.spatialCyan.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: SpatiallyColors.spatialCyan, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  eventTitle,
                                  style: SpatiallyTypography.caption(color: textPrimary).copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Authoritative Venue Emergency & Accessibility Network',
                                  style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SpatiallySpacing.gapVerticalLg,

                    // SECTION 1: EMERGENCY ACTIONS
                    Row(
                      children: [
                        const Icon(Icons.emergency_rounded, color: SpatiallyColors.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'EMERGENCY & URGENT HELP',
                          style: SpatiallyTypography.badge(color: SpatiallyColors.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _emergencyActions.length,
                      separatorBuilder: (_, _) => SpatiallySpacing.gapVerticalMd,
                      itemBuilder: (context, index) {
                        return SafetyActionCard(resource: _emergencyActions[index]);
                      },
                    ),

                    SpatiallySpacing.gapVerticalXl,

                    // SECTION: ON-SITE STAFF ASSISTANCE
                    const SpatiallySectionHeader(
                      title: 'On-Site Staff Assistance',
                      subtitle: 'Request direct assistance from event volunteers and venue operations',
                    ),
                    SpatiallySpacing.gapVerticalSm,
                    SpatiallyCard(
                      padding: const EdgeInsets.all(SpatiallySpacing.md),
                      onTap: () {
                        AttendeeAssistanceDialog.show(
                          context,
                          eventId: eventId,
                          eventName: eventTitle,
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: SpatiallyColors.violet.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.support_agent_rounded,
                                    color: SpatiallyColors.violet,
                                    size: 24,
                                  ),
                                ),
                              ),
                              SpatiallySpacing.gapHorizontalMd,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Request Staff Assistance',
                                      style: SpatiallyTypography.subheading(color: textPrimary).copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Accessibility, Direction, or On-Site Help',
                                      style: SpatiallyTypography.caption(color: textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SpatiallySpacing.gapVerticalMd,
                          Text(
                            'Need physical guidance, accessibility assistance, or immediate volunteer help? Submit a request and active on-site volunteers will be notified.',
                            style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                              height: 1.35,
                            ),
                          ),
                          SpatiallySpacing.gapVerticalMd,
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    AttendeeAssistanceDialog.show(
                                      context,
                                      eventId: eventId,
                                      eventName: eventTitle,
                                    );
                                  },
                                  icon: const Icon(Icons.handshake_outlined, size: 16),
                                  label: const Text('Request Assistance'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SpatiallyColors.violet,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SpatiallySpacing.gapVerticalXl,

                    // SECTION 2: LOST & FOUND HUB
                    const SpatiallySectionHeader(
                      title: 'Lost & Found',
                      subtitle: 'Report lost possessions or view items recovered by venue staff',
                    ),
                    SpatiallySpacing.gapVerticalSm,
                    SpatiallyCard(
                      padding: const EdgeInsets.all(SpatiallySpacing.md),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LostFoundScreen(
                              eventId: eventId,
                              eventName: eventTitle,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: SpatiallyColors.violet.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(SpatiallyRadius.md),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    color: SpatiallyColors.violet,
                                    size: 24,
                                  ),
                                ),
                              ),
                              SpatiallySpacing.gapHorizontalMd,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Event Property Desk',
                                      style: SpatiallyTypography.subheading(color: textPrimary).copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Room 712 Central Desk • 48h Post-Event Retention',
                                      style: SpatiallyTypography.caption(color: textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SpatiallySpacing.gapVerticalMd,
                          Text(
                            'Left something in an auditorium or found an unattended device? Log it directly or visit the Central Help Desk to verify claims.',
                            style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                              height: 1.35,
                            ),
                          ),
                          SpatiallySpacing.gapVerticalMd,
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => LostFoundScreen(
                                          eventId: eventId,
                                          eventName: eventTitle,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.search_rounded, size: 16),
                                  label: const Text('Open Lost & Found'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SpatiallyColors.violet,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SpatiallySpacing.gapVerticalXl,

                    // SECTION 3: VENUE ASSISTANCE & FACILITIES
                    const SpatiallySectionHeader(
                      title: 'Venue Assistance',
                      subtitle: 'On-site attendee desks and support services',
                    ),
                    SpatiallySpacing.gapVerticalSm,
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _venueHelpResources.length,
                      separatorBuilder: (_, _) => SpatiallySpacing.gapVerticalMd,
                      itemBuilder: (context, index) {
                        return SafetyResourceTile(resource: _venueHelpResources[index]);
                      },
                    ),

                    SpatiallySpacing.gapVerticalXl,

                    // SECTION 4: ACCESSIBILITY INTEGRATION
                    const SpatiallySectionHeader(
                      title: 'Accessibility & Mobility',
                      subtitle: 'Active routing preferences from your Spatially profile',
                    ),
                    SpatiallySpacing.gapVerticalSm,
                    SpatiallyCard(
                      padding: const EdgeInsets.all(SpatiallySpacing.md),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Prefer Step-Free Routes',
                              style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Routes wayfinding via elevator spine and step-free entrance ramps',
                              style: SpatiallyTypography.caption(color: textSecondary),
                            ),
                            value: _preferences.preferStepFreeRoutes,
                            activeThumbColor: SpatiallyColors.spatialCyan,
                            onChanged: _toggleStepFree,
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 16, color: SpatiallyColors.spatialCyan),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Map routes automatically reflect step-free navigation when enabled.',
                                    style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SpatiallySpacing.gapVerticalXl,

                    // SECTION 5: EMERGENCY CONTACTS DIRECTORY (CONTROLLED DEMO BOUNDARY)
                    const SpatiallySectionHeader(
                      title: 'Operational Directory',
                      subtitle: 'Internal venue station channels (Demonstration Directory)',
                    ),
                    SpatiallySpacing.gapVerticalSm,
                    ..._emergencyContacts.map((contact) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SpatiallyCard(
                          padding: const EdgeInsets.all(SpatiallySpacing.md),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: SpatiallyColors.violet.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(Icons.phone_in_talk_rounded, color: SpatiallyColors.violet, size: 18),
                                ),
                              ),
                              SpatiallySpacing.gapHorizontalMd,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          contact.title,
                                          style: SpatiallyTypography.body(color: textPrimary).copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: SpatiallyColors.warning.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(SpatiallyRadius.xs),
                                          ),
                                          child: Text(
                                            'DEMO ONLY',
                                            style: SpatiallyTypography.caption(color: SpatiallyColors.warning).copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${contact.role} • ${contact.location}',
                                      style: SpatiallyTypography.caption(color: textSecondary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Channel: ${contact.channel} (${contact.operationalHours})',
                                      style: SpatiallyTypography.caption(color: SpatiallyColors.violet).copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    SpatiallySpacing.gapVerticalLg,

                    // Disclaimer footer
                    Container(
                      padding: const EdgeInsets.all(SpatiallySpacing.md),
                      decoration: BoxDecoration(
                        color: isDark ? SpatiallyColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(SpatiallyRadius.sm),
                      ),
                      child: Text(
                        'DISCLAIMER: Authoritative venue safety information is configured by event organizers. In a life-threatening or medical emergency outside event premises, call local emergency authorities directly. Spatially does not track precise personal GPS coordinates.',
                        style: SpatiallyTypography.caption(color: textSecondary).copyWith(
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ),

                    SpatiallySpacing.gapVerticalXxl,
                  ],
                ),
              ),
            ),
    );
  }
}
