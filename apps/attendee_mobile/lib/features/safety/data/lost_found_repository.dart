import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/attendee_identity.dart';
import '../../../services/offline_service.dart';
import '../models/safety_models.dart';

/// Abstract contract for event-scoped Lost & Found operations.
abstract class LostFoundRepository {
  Stream<List<LostFoundReport>> getReportsStream(String eventId);
  Future<List<LostFoundReport>> getReports(String eventId, {LostFoundType? type, bool onlyMyReports = false});
  Future<LostFoundReport> submitReport({
    required String eventId,
    required LostFoundType type,
    required LostFoundCategory category,
    required String title,
    required String description,
    required String venueZoneId,
    required String venueZoneName,
    String? specificLocation,
    String? imagePlaceholderName,
  });
  Future<void> updateReportStatus(String reportId, LostFoundStatus status);
  Future<void> syncPendingReports();
}

/// Exception thrown when the digital Lost & Found service/table is not available.
class LostFoundUnavailableException implements Exception {
  final String message;
  const LostFoundUnavailableException([
    this.message = 'Lost & Found digital logging service is currently unavailable for this event. Please report or claim items in person at the Central Help Desk (Room 712 Foyer).',
  ]);

  @override
  String toString() => message;
}

/// Production repository with Supabase persistence, stream reactivity, offline drafting, and outbox sync.
class LostFoundRepositoryImpl implements LostFoundRepository {
  static final LostFoundRepositoryImpl _instance = LostFoundRepositoryImpl._internal();
  factory LostFoundRepositoryImpl() => _instance;

  final SupabaseClient _supabase;
  final Map<String, List<LostFoundReport>> _eventReports = {};
  final List<Map<String, dynamic>> _offlineOutbox = [];
  final StreamController<List<LostFoundReport>> _controller = StreamController<List<LostFoundReport>>.broadcast();

  LostFoundRepositoryImpl._internal({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client {
    OfflineService().isOnlineNotifier.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (OfflineService().isOnline) {
      syncPendingReports();
    }
  }

  Future<void> _fetchRemoteReports(String eventId) async {
    try {
      final response = await _supabase
          .from('lost_found_reports')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 4));

      final myDeviceId = AttendeeIdentity.deviceId;
      final myUserId = _supabase.auth.currentUser?.id;

      final remoteReports = (response as List<dynamic>).map((row) {
        final r = Map<String, dynamic>.from(row as Map);
        final reportType = (r['report_type']?.toString().toLowerCase() == 'found')
            ? LostFoundType.found
            : LostFoundType.lost;

        final catStr = r['category']?.toString().toLowerCase();
        final cat = LostFoundCategory.values.firstWhere(
          (c) => c.name.toLowerCase() == catStr,
          orElse: () => LostFoundCategory.other,
        );

        final statusStr = r['status']?.toString().toLowerCase();
        final status = LostFoundStatus.values.firstWhere(
          (s) => s.name.toLowerCase() == statusStr,
          orElse: () => LostFoundStatus.submitted,
        );

        final isMine = (myDeviceId != null && r['reporter_device_id'] == myDeviceId) ||
            (myUserId != null && r['reporter_user_id'] == myUserId);

        return LostFoundReport(
          id: r['id']?.toString() ?? '',
          eventId: r['event_id']?.toString() ?? eventId,
          type: reportType,
          category: cat,
          title: r['title']?.toString() ?? 'Report',
          description: r['description']?.toString() ?? '',
          venueZoneId: r['zone_id']?.toString() ?? '712',
          venueZoneName: r['venue_zone_name']?.toString() ?? 'Room 712 • Foyer & Registration',
          specificLocation: r['specific_location']?.toString(),
          imagePlaceholderName: r['image_url']?.toString(),
          status: status,
          createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
          isCurrentUser: isMine,
          pickupInstructions: r['pickup_instructions']?.toString(),
        );
      }).toList();

      final existingLocal = _eventReports[eventId] ?? [];
      final pendingDrafts = existingLocal.where((r) => r.status == LostFoundStatus.pendingSync).toList();

      // Combine remote reports with any local un-synced pending drafts
      _eventReports[eventId] = [...pendingDrafts, ...remoteReports];
      _controller.add(List.unmodifiable(_eventReports[eventId]!));
    } catch (e) {
      // Backend table 'lost_found_reports' is not provisioned or network query failed.
      // Explicitly notify controller with error so stream terminates cleanly rather than hanging.
      debugPrint('LostFoundRepository: Remote fetch failed ($e). Emitting honest error.');
      _controller.addError(const LostFoundUnavailableException());
      throw const LostFoundUnavailableException();
    }
  }

  @override
  Stream<List<LostFoundReport>> getReportsStream(String eventId) {
    _fetchRemoteReports(eventId);
    return _controller.stream;
  }

  @override
  Future<List<LostFoundReport>> getReports(
    String eventId, {
    LostFoundType? type,
    bool onlyMyReports = false,
  }) async {
    await _fetchRemoteReports(eventId);

    var list = _eventReports[eventId] ?? [];
    if (type != null) {
      list = list.where((r) => r.type == type).toList();
    }
    if (onlyMyReports) {
      list = list.where((r) => r.isCurrentUser).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  @override
  Future<LostFoundReport> submitReport({
    required String eventId,
    required LostFoundType type,
    required LostFoundCategory category,
    required String title,
    required String description,
    required String venueZoneId,
    required String venueZoneName,
    String? specificLocation,
    String? imagePlaceholderName,
  }) async {
    final isOnline = OfflineService().isOnline;
    final myDeviceId = AttendeeIdentity.deviceId ?? 'guest_device';
    final myUserId = _supabase.auth.currentUser?.id;

    final String instructions = type == LostFoundType.found
        ? 'Item handed to on-site volunteer or kept safe by reporter.'
        : 'Central Help Desk notified. Staff will cross-reference incoming found property.';

    if (isOnline) {
      try {
        final payload = {
          'event_id': eventId,
          'reporter_device_id': myDeviceId,
          'reporter_user_id': myUserId,
          'report_type': type.name,
          'category': category.name,
          'title': title,
          'description': description,
          'venue_zone_name': venueZoneName,
          'specific_location': specificLocation,
          'image_url': imagePlaceholderName,
          'status': 'submitted',
          'pickup_instructions': instructions,
        };

        final inserted = await _supabase
            .from('lost_found_reports')
            .insert(payload)
            .select()
            .single()
            .timeout(const Duration(seconds: 4));

        final newReport = LostFoundReport(
          id: inserted['id']?.toString() ?? 'lf_${DateTime.now().millisecondsSinceEpoch}',
          eventId: eventId,
          type: type,
          category: category,
          title: title,
          description: description,
          venueZoneId: venueZoneId,
          venueZoneName: venueZoneName,
          specificLocation: specificLocation,
          imagePlaceholderName: imagePlaceholderName,
          status: LostFoundStatus.submitted,
          createdAt: DateTime.tryParse(inserted['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
          isCurrentUser: true,
          pickupInstructions: instructions,
        );

        final list = _eventReports[eventId] ?? [];
        list.insert(0, newReport);
        _eventReports[eventId] = list;
        _controller.add(List.unmodifiable(list));
        return newReport;
      } catch (_) {
        // Fallback to offline queue if Supabase insert timed out or failed
      }
    }

    // Offline or network error: Save locally as pendingSync
    final offlineReport = LostFoundReport(
      id: 'lf_pending_${DateTime.now().millisecondsSinceEpoch}',
      eventId: eventId,
      type: type,
      category: category,
      title: title,
      description: description,
      venueZoneId: venueZoneId,
      venueZoneName: venueZoneName,
      specificLocation: specificLocation,
      imagePlaceholderName: imagePlaceholderName,
      status: LostFoundStatus.pendingSync,
      createdAt: DateTime.now(),
      isCurrentUser: true,
      pickupInstructions: 'Draft saved locally offline. Will be submitted once connectivity is restored.',
    );

    _offlineOutbox.add({
      'report': offlineReport,
      'payload': {
        'event_id': eventId,
        'reporter_device_id': myDeviceId,
        'reporter_user_id': myUserId,
        'report_type': type.name,
        'category': category.name,
        'title': title,
        'description': description,
        'venue_zone_name': venueZoneName,
        'specific_location': specificLocation,
        'image_url': imagePlaceholderName,
        'status': 'submitted',
        'pickup_instructions': instructions,
      }
    });

    final list = _eventReports[eventId] ?? [];
    list.insert(0, offlineReport);
    _eventReports[eventId] = list;
    _controller.add(List.unmodifiable(list));

    return offlineReport;
  }

  @override
  Future<void> updateReportStatus(String reportId, LostFoundStatus status) async {
    for (final eventId in _eventReports.keys) {
      final list = _eventReports[eventId]!;
      final idx = list.indexWhere((r) => r.id == reportId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(status: status);
        _controller.add(List.unmodifiable(list));
        break;
      }
    }
  }

  @override
  Future<void> syncPendingReports() async {
    if (_offlineOutbox.isEmpty) return;

    final itemsToSync = List<Map<String, dynamic>>.from(_offlineOutbox);
    for (final item in itemsToSync) {
      try {
        final payload = item['payload'] as Map<String, dynamic>;
        final localReport = item['report'] as LostFoundReport;

        final inserted = await _supabase
            .from('lost_found_reports')
            .insert(payload)
            .select()
            .single()
            .timeout(const Duration(seconds: 4));

        _offlineOutbox.remove(item);

        final eventId = localReport.eventId;
        if (_eventReports.containsKey(eventId)) {
          final list = _eventReports[eventId]!;
          final idx = list.indexWhere((r) => r.id == localReport.id);
          if (idx != -1) {
            list[idx] = localReport.copyWith(
              id: inserted['id']?.toString() ?? localReport.id,
              status: LostFoundStatus.submitted,
              pickupInstructions: localReport.type == LostFoundType.found
                  ? 'Item handed to on-site volunteer or kept safe by reporter.'
                  : 'Central Help Desk notified. Staff will cross-reference incoming found property.',
            );
            _controller.add(List.unmodifiable(list));
          }
        }
      } catch (_) {
        // Leave item in outbox for subsequent retry
      }
    }
  }
}
