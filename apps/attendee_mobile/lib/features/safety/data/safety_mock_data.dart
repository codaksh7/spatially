import 'package:flutter/material.dart';
import '../models/safety_models.dart';

/// Authoritative mock venue safety data and demo-labeled emergency directories.
class SafetyMockData {
  static const String demoVenueName = 'Spatially Demo Venue';

  /// Primary venue safety & emergency resources tied directly to Map POIs.
  static final List<SafetyResource> venueSafetyResources = [
    const SafetyResource(
      id: 'res_first_aid',
      title: 'First Aid & Medical Station',
      subtitle: 'Certified campus first responders & emergency kit',
      category: SafetyCategory.medical,
      zoneId: '712',
      zoneName: 'Room 712 • Foyer & Registration',
      poiId: 'poi_first_aid',
      icon: Icons.medical_services_rounded,
      availability: ResourceAvailability.available,
      guidance: 'For minor cuts, dehydration, or urgent medical evaluation. Staffed continuously during event sessions.',
      contactChannel: 'On-site Desk • Ext: 712-MED',
    ),
    const SafetyResource(
      id: 'res_security',
      title: 'Venue Security Desk',
      subtitle: 'Campus security officers & incident reporting',
      category: SafetyCategory.security,
      zoneId: '712',
      zoneName: 'Room 712 • Foyer & Registration',
      poiId: 'poi_security_desk',
      icon: Icons.shield_rounded,
      availability: ResourceAvailability.available,
      guidance: 'Report suspicious activity, access perimeter concerns, or request security escort assistance.',
      contactChannel: 'On-site Desk • Ext: 712-SEC',
    ),
    const SafetyResource(
      id: 'res_exit_north',
      title: 'Emergency Exit North',
      subtitle: 'Press-bar fire door to North escape staircase',
      category: SafetyCategory.emergencyExit,
      zoneId: '707',
      zoneName: 'North Corridor (adjacent to Room 707)',
      poiId: 'poi_exit_north',
      icon: Icons.exit_to_app_rounded,
      availability: ResourceAvailability.evacuationOnly,
      guidance: 'In event of fire or evacuation alarm, proceed calmly along North corridor following illuminated green signage.',
    ),
    const SafetyResource(
      id: 'res_exit_south',
      title: 'Emergency Exit South',
      subtitle: 'Primary ground lobby evacuation route',
      category: SafetyCategory.emergencyExit,
      zoneId: '712',
      zoneName: 'South Lobby (Room 712 Main Entrance)',
      poiId: 'poi_exit_south',
      icon: Icons.exit_to_app_rounded,
      availability: ResourceAvailability.evacuationOnly,
      guidance: 'Main exit to open assembly quad. Accessible wide doors with low-gradient egress ramp.',
    ),
    const SafetyResource(
      id: 'res_help_desk',
      title: 'Central Help & Lost Property',
      subtitle: 'Badge verification, event staff & lost items',
      category: SafetyCategory.helpDesk,
      zoneId: '712',
      zoneName: 'Room 712 • Foyer & Registration',
      poiId: 'poi_help_desk',
      icon: Icons.help_outline_rounded,
      availability: ResourceAvailability.available,
      guidance: 'Visit for physical badge inquiries, lost & found collections, schedule updates, and volunteer support.',
      contactChannel: 'Main Lobby Desk • Ext: 712-INFO',
    ),
    const SafetyResource(
      id: 'res_accessibility',
      title: 'Accessibility & Mobility Support',
      subtitle: 'Wheelchair loan, elevator access & escort guides',
      category: SafetyCategory.accessibility,
      zoneId: '712',
      zoneName: 'Room 712 • Foyer & Registration',
      poiId: 'poi_accessibility_desk',
      icon: Icons.accessible_rounded,
      availability: ResourceAvailability.available,
      guidance: 'Request assistance for step-free routes, reserved seating in Stage A, or assisted navigation across expo halls.',
      contactChannel: 'Accessibility Desk • Ext: 712-ACC',
    ),
  ];

  /// Controlled emergency directory contacts (explicitly marked as demo/internal venue only).
  static final List<EmergencyContact> demoEmergencyContacts = [
    const EmergencyContact(
      id: 'contact_medical',
      title: 'Venue Medical Officer',
      role: 'On-site Paramedic & First Aid Team',
      location: 'First Aid Station, Room 712 Foyer',
      channel: 'Internal Radio / Ext: 712-MED',
      isDemonstrationOnly: true,
      operationalHours: '08:30 – 19:00',
    ),
    const EmergencyContact(
      id: 'contact_security',
      title: 'Campus Safety Dispatch',
      role: 'Event Perimeter & Access Security',
      location: 'Security Booth, Room 712 Foyer',
      channel: 'Internal Radio / Ext: 712-SEC',
      isDemonstrationOnly: true,
      operationalHours: '24 Hours On-Call',
    ),
    const EmergencyContact(
      id: 'contact_helpdesk',
      title: 'Central Event Help Desk',
      role: 'Organizer Operations & Lost Property',
      location: 'Central Lobby, Room 712',
      channel: 'Lobby Counter / Ext: 712-INFO',
      isDemonstrationOnly: true,
      operationalHours: '08:00 – 18:30',
    ),
  ];

  /// Pre-seeded demo Lost & Found reports.
  static List<LostFoundReport> getInitialLostFoundReports(String eventId) {
    final now = DateTime.now();
    return [
      LostFoundReport(
        id: 'lf_seed_001',
        eventId: eventId,
        type: LostFoundType.lost,
        category: LostFoundCategory.wallet,
        title: 'Matte Black Slim Cardholder',
        description: 'Contains a student ID card and contactless metro pass. Dropped during the opening keynote session.',
        venueZoneId: '701',
        venueZoneName: 'Room 701 • Auditorium',
        specificLocation: 'Row G, Left Section near aisle',
        status: LostFoundStatus.underReview,
        createdAt: now.subtract(const Duration(minutes: 50)),
        isCurrentUser: false,
        pickupInstructions: 'Reported to auditorium volunteer team.',
      ),
      LostFoundReport(
        id: 'lf_seed_002',
        eventId: eventId,
        type: LostFoundType.found,
        category: LostFoundCategory.electronics,
        title: '65W Anker USB-C GaN Charger',
        description: 'Found plugged into charging strip at workstation table 4. Handed in to Room 712 Help Desk.',
        venueZoneId: '707',
        venueZoneName: 'Room 707 • Workshop & Labs',
        specificLocation: 'Table 4 Tech Workbench',
        status: LostFoundStatus.submitted,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 20)),
        isCurrentUser: false,
        pickupInstructions: 'Available for verification and claim at Central Help Desk in Room 712.',
      ),
      LostFoundReport(
        id: 'lf_seed_003',
        eventId: eventId,
        type: LostFoundType.found,
        category: LostFoundCategory.idCard,
        title: 'Spatially VIP Attendee Lanyard',
        description: 'Purple lanyard with attendee badge. Left at the registration turnstile counter.',
        venueZoneId: '712',
        venueZoneName: 'Room 712 • Foyer & Registration',
        specificLocation: 'Turnstile A counter',
        status: LostFoundStatus.matched,
        createdAt: now.subtract(const Duration(hours: 2, minutes: 15)),
        isCurrentUser: false,
        pickupInstructions: 'Matched with registered attendee; awaiting pickup at Desk 1.',
      ),
    ];
  }
}
