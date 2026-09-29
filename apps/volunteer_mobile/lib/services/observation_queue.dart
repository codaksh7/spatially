import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ble_observation.dart';
import '../models/offline_check_in_record.dart';
import '../models/operational_awareness_item.dart';
import 'session_state.dart';

class QueueSyncInfo {
  final int pendingObservations;
  final int pendingTickets;
  final bool isSyncing;
  final DateTime? lastSyncedAt;

  const QueueSyncInfo({
    required this.pendingObservations,
    required this.pendingTickets,
    required this.isSyncing,
    this.lastSyncedAt,
  });

  int get totalPending => pendingObservations + pendingTickets;
}

/// Manages offline storage and cloud sync for BLE observations and ticket check-ins.
///
/// Architecture:
/// - Writes first attempt the Supabase insert/RPC directly (online-first).
/// - If that operation fails, the row is written to local SQLite tables
///   (`pending_observations` or `pending_ticket_checkins`).
/// - A [Connectivity] listener triggers an automatic flush whenever the device
///   regains connectivity.
/// - Startup flushes also run once at launch to recover state from previous offline sessions.
class ObservationQueue {
  static final ObservationQueue _instance = ObservationQueue._internal();
  factory ObservationQueue() => _instance;
  ObservationQueue._internal();

  static const String _obsTableName = 'pending_observations';
  static const String _ticketsTableName = 'pending_ticket_checkins';

  Database? _db;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final StreamController<QueueSyncInfo> _syncInfoController =
      StreamController<QueueSyncInfo>.broadcast();
  DateTime? _lastSyncedAt;

  Stream<QueueSyncInfo> get syncStatusStream => _syncInfoController.stream;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isSyncing => _isFlushingObservations || _isFlushingTickets;

  Future<void> _notifySyncChanged() async {
    try {
      final info = await getSyncInfo(volunteerId: SessionState.instance.volunteerId);
      if (!_syncInfoController.isClosed) {
        _syncInfoController.add(info);
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Initialisation
  // -------------------------------------------------------------------------

  Future<void> init() async {
    await _openDb();
    await cleanupStaleRejectedTickets();
    _startConnectivityListener();
    // Flush any rows left from a previous offline session.
    await _flushPending();
    await _flushPendingTickets();
    await _notifySyncChanged();
  }

  Future<void> _openDb() async {
    _db = await openDatabase(
      'spatially_queue.db',
      version: 8,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_obsTableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ephemeral_id TEXT NOT NULL,
            rssi INTEGER NOT NULL,
            scanned_at TEXT NOT NULL,
            is_spatially_device INTEGER NOT NULL,
            volunteer_id TEXT,
            event_id TEXT,
            zone TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE $_ticketsTableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation_id TEXT NOT NULL UNIQUE,
            ticket_code TEXT NOT NULL,
            event_id TEXT NOT NULL,
            volunteer_id TEXT,
            scanned_at TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            error_message TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE pending_operational_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            local_id TEXT NOT NULL UNIQUE,
            event_id TEXT NOT NULL,
            volunteer_id TEXT NOT NULL,
            target_type TEXT NOT NULL,
            target_id TEXT,
            zone_id TEXT,
            message_type TEXT NOT NULL,
            priority TEXT NOT NULL,
            body TEXT NOT NULL,
            requires_acknowledgment INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            error_message TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_operational_messages (
            id TEXT PRIMARY KEY,
            event_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            volunteer_id TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE pending_operational_incidents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            local_id TEXT NOT NULL UNIQUE,
            event_id TEXT NOT NULL,
            volunteer_id TEXT NOT NULL,
            category TEXT NOT NULL,
            priority TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            zone_id TEXT,
            venue_zone_name TEXT,
            venue_poi_id TEXT,
            specific_location TEXT,
            image_url TEXT,
            link_operational_message INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            error_message TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_operational_incidents (
            id TEXT PRIMARY KEY,
            event_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            volunteer_id TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_lost_found_reports (
            id TEXT PRIMARY KEY,
            event_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            volunteer_id TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_volunteer_shifts (
            id TEXT PRIMARY KEY,
            event_id TEXT NOT NULL,
            volunteer_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_event_teams (
            id TEXT PRIMARY KEY,
            event_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_supervisor_tasks (
            id TEXT PRIMARY KEY,
            event_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_coverage_requests (
            id TEXT PRIMARY KEY,
            event_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_shift_handoffs (
            id TEXT PRIMARY KEY,
            event_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_awareness_items (
            id TEXT PRIMARY KEY,
            event_id TEXT NOT NULL,
            source_id TEXT NOT NULL,
            category TEXT NOT NULL,
            priority TEXT NOT NULL,
            relevance TEXT NOT NULL,
            status TEXT NOT NULL,
            title TEXT NOT NULL,
            message TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            zone_id TEXT,
            zone_name TEXT,
            zone_code TEXT,
            team_id TEXT,
            team_name TEXT,
            action_route TEXT,
            action_payload TEXT,
            is_stale INTEGER NOT NULL DEFAULT 0,
            is_cached INTEGER NOT NULL DEFAULT 1,
            volunteer_id TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE handled_attention_keys (
            key TEXT PRIMARY KEY,
            handled_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_operational_health (
            event_id TEXT PRIMARY KEY,
            payload_json TEXT NOT NULL,
            cached_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_operational_timeline (
            id TEXT PRIMARY KEY,
            event_id TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $_ticketsTableName (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              operation_id TEXT NOT NULL UNIQUE,
              ticket_code TEXT NOT NULL,
              event_id TEXT NOT NULL,
              volunteer_id TEXT,
              scanned_at TEXT NOT NULL,
              sync_status TEXT NOT NULL DEFAULT 'pending',
              error_message TEXT
            )
          ''');
        }
        if (oldVersion < 3) {
          final columns = await db.rawQuery("PRAGMA table_info($_ticketsTableName)");
          final hasVolunteerId = columns.any((col) => col['name'] == 'volunteer_id');
          if (!hasVolunteerId) {
            await db.execute('ALTER TABLE $_ticketsTableName ADD COLUMN volunteer_id TEXT');
          }
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS pending_operational_messages (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              local_id TEXT NOT NULL UNIQUE,
              event_id TEXT NOT NULL,
              volunteer_id TEXT NOT NULL,
              target_type TEXT NOT NULL,
              target_id TEXT,
              zone_id TEXT,
              message_type TEXT NOT NULL,
              priority TEXT NOT NULL,
              body TEXT NOT NULL,
              requires_acknowledgment INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              sync_status TEXT NOT NULL DEFAULT 'pending',
              error_message TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_operational_messages (
              id TEXT PRIMARY KEY,
              event_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              created_at TEXT NOT NULL,
              volunteer_id TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS pending_operational_incidents (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              local_id TEXT NOT NULL UNIQUE,
              event_id TEXT NOT NULL,
              volunteer_id TEXT NOT NULL,
              category TEXT NOT NULL,
              priority TEXT NOT NULL,
              title TEXT NOT NULL,
              description TEXT NOT NULL,
              zone_id TEXT,
              venue_zone_name TEXT,
              venue_poi_id TEXT,
              specific_location TEXT,
              image_url TEXT,
              link_operational_message INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              sync_status TEXT NOT NULL DEFAULT 'pending',
              error_message TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_operational_incidents (
              id TEXT PRIMARY KEY,
              event_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              volunteer_id TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_lost_found_reports (
              id TEXT PRIMARY KEY,
              event_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              volunteer_id TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_volunteer_shifts (
              id TEXT PRIMARY KEY,
              event_id TEXT NOT NULL,
              volunteer_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_event_teams (
              id TEXT PRIMARY KEY,
              event_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_supervisor_tasks (
              id TEXT PRIMARY KEY,
              event_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_coverage_requests (
              id TEXT PRIMARY KEY,
              event_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_shift_handoffs (
              id TEXT PRIMARY KEY,
              event_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 7) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_awareness_items (
              id TEXT PRIMARY KEY,
              event_id TEXT NOT NULL,
              source_id TEXT NOT NULL,
              category TEXT NOT NULL,
              priority TEXT NOT NULL,
              relevance TEXT NOT NULL,
              status TEXT NOT NULL,
              title TEXT NOT NULL,
              message TEXT NOT NULL,
              timestamp TEXT NOT NULL,
              zone_id TEXT,
              zone_name TEXT,
              zone_code TEXT,
              team_id TEXT,
              team_name TEXT,
              action_route TEXT,
              action_payload TEXT,
              is_stale INTEGER NOT NULL DEFAULT 0,
              is_cached INTEGER NOT NULL DEFAULT 1,
              volunteer_id TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS handled_attention_keys (
              key TEXT PRIMARY KEY,
              handled_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 8) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_operational_health (
              event_id TEXT PRIMARY KEY,
              payload_json TEXT NOT NULL,
              cached_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS cached_operational_timeline (
              id TEXT PRIMARY KEY,
              event_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              timestamp TEXT NOT NULL
            )
          ''');
        }
      },
    );
    print('ObservationQueue: SQLite database opened (v8) with operational health & analytics ready.');
  }

  Database? get db => _db;

  Future<Database> getDb() async {
    if (_db == null) {
      await init();
    }
    return _db!;
  }

  void _startConnectivityListener() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final hasConnection = results.any(
        (r) => r != ConnectivityResult.none,
      );
      if (hasConnection) {
        print('ObservationQueue: Connectivity restored — flushing pending queues.');
        _flushPending();
        _flushPendingTickets();
        flushPendingIncidents();
      }
    });
  }

  // -------------------------------------------------------------------------
  // Observation Write Path (Privacy Filtered)
  // -------------------------------------------------------------------------

  /// Attempts a direct Supabase insert for Spatially devices only.
  /// Drops non-Spatially ambient devices without persisting hardware MACs.
  Future<void> sendOrQueue(BleObservation observation) async {
    // Privacy Gate: Strictly ignore and drop non-Spatially devices
    if (!observation.isSpatiallyDevice) {
      return;
    }

    try {
      final supabaseInstance = Supabase.instance;
      final client = supabaseInstance.client;
      final table = client.from('observations');
      final row = observation.toMap();
      await table.insert(row);
      _lastSyncedAt = DateTime.now();
      _notifySyncChanged();
      print('TelemetryService: Successfully sent observation for ${observation.ephemeralId}');
    } catch (e) {
      print('TelemetryService ERROR: Failed to send observation, queuing offline: $e');
      await _enqueue(observation);
    }
  }

  Future<void> _enqueue(BleObservation obs) async {
    final db = _db;
    if (db == null) return;

    await db.insert(_obsTableName, {
      'ephemeral_id': obs.ephemeralId,
      'rssi': obs.rssi,
      'scanned_at': obs.scannedAt.toIso8601String(),
      'is_spatially_device': obs.isSpatiallyDevice ? 1 : 0,
      'volunteer_id': obs.volunteerId,
      'event_id': obs.eventId,
      'zone': obs.zone,
    });
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_obsTableName'),
    ) ?? 0;
    print('DEBUG: Queued observation offline, pending_observations count=$count');
    _notifySyncChanged();
  }

  // -------------------------------------------------------------------------
  // Ticket Check-in Queue Path
  // -------------------------------------------------------------------------

  Future<void> enqueueTicketCheckIn(OfflineCheckInRecord record) async {
    final db = _db;
    if (db == null) return;

    final volunteerId = record.volunteerId ?? SessionState.instance.volunteerId;
    final row = record.toMap();
    if (volunteerId != null) {
      row['volunteer_id'] = volunteerId;
    }

    await db.insert(
      _ticketsTableName,
      row,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    print('ObservationQueue: Queued offline check-in for ticket: ${record.ticketCode}');
    _notifySyncChanged();
  }

  Future<List<OfflineCheckInRecord>> getPendingTicketCheckIns({String? volunteerId}) async {
    final db = _db;
    if (db == null) return [];

    final whereClause = volunteerId != null
        ? 'sync_status = ? AND (volunteer_id = ? OR volunteer_id IS NULL)'
        : 'sync_status = ?';
    final whereArgs = volunteerId != null ? ['pending', volunteerId] : ['pending'];

    final rows = await db.query(
      _ticketsTableName,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'id ASC',
    );

    return rows.map((r) => OfflineCheckInRecord.fromMap(r)).toList();
  }

  Future<void> updateTicketCheckInStatus(
    int id,
    String status, {
    String? errorMessage,
  }) async {
    final db = _db;
    if (db == null) return;

    await db.update(
      _ticketsTableName,
      {
        'sync_status': status,
        'error_message': errorMessage,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getPendingObservationCount({String? volunteerId}) async {
    final db = _db;
    if (db == null) return 0;

    final whereClause = volunteerId != null ? 'volunteer_id = ?' : null;
    final whereArgs = volunteerId != null ? [volunteerId] : null;

    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        whereClause != null
            ? 'SELECT COUNT(*) FROM $_obsTableName WHERE $whereClause'
            : 'SELECT COUNT(*) FROM $_obsTableName',
        whereArgs,
      ),
    );
    return count ?? 0;
  }

  Future<QueueSyncInfo> getSyncInfo({String? volunteerId}) async {
    final obsCount = await getPendingObservationCount(volunteerId: volunteerId);
    final ticketsCount = await getPendingTicketCheckInCount(volunteerId: volunteerId);
    return QueueSyncInfo(
      pendingObservations: obsCount,
      pendingTickets: ticketsCount,
      isSyncing: isSyncing,
      lastSyncedAt: _lastSyncedAt,
    );
  }

  Future<int> getPendingTicketCheckInCount({String? volunteerId}) async {
    final db = _db;
    if (db == null) return 0;

    final whereClause = volunteerId != null
        ? 'sync_status = ? AND (volunteer_id = ? OR volunteer_id IS NULL)'
        : 'sync_status = ?';
    final whereArgs = volunteerId != null ? ['pending', volunteerId] : ['pending'];

    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $_ticketsTableName WHERE $whereClause',
        whereArgs,
      ),
    );
    return count ?? 0;
  }

  /// Conservative cleanup for rejected ticket records:
  /// Retains recent rejected records for diagnosis, but caps the table
  /// to prevent unbounded SQLite growth over long-term operations.
  /// Never touches 'pending' or 'synced' records awaiting transmission.
  Future<int> cleanupStaleRejectedTickets({
    int maxRetained = 50,
    Duration olderThan = const Duration(days: 7),
  }) async {
    final db = _db;
    if (db == null) return 0;

    try {
      final cutoff = DateTime.now().toUtc().subtract(olderThan).toIso8601String();
      // 1. Delete rejected records older than retention period
      int deleted = await db.delete(
        _ticketsTableName,
        where: 'sync_status = ? AND scanned_at < ?',
        whereArgs: ['rejected', cutoff],
      );

      // 2. Cap rejected records to maxRetained if still exceeding limit
      final rejectedCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM $_ticketsTableName WHERE sync_status = ?',
          ['rejected'],
        ),
      ) ?? 0;

      if (rejectedCount > maxRetained) {
        final excess = rejectedCount - maxRetained;
        final excessIds = await db.query(
          _ticketsTableName,
          columns: ['id'],
          where: 'sync_status = ?',
          whereArgs: ['rejected'],
          orderBy: 'scanned_at ASC',
          limit: excess,
        );
        if (excessIds.isNotEmpty) {
          final idList = excessIds.map((r) => r['id'] as int).toList();
          final placeholder = List.filled(idList.length, '?').join(',');
          final moreDeleted = await db.delete(
            _ticketsTableName,
            where: 'id IN ($placeholder)',
            whereArgs: idList,
          );
          deleted += moreDeleted;
        }
      }
      return deleted;
    } catch (e) {
      print('ObservationQueue: Error during rejected ticket cleanup: $e');
      return 0;
    }
  }

  // -------------------------------------------------------------------------
  // Flush Paths
  // -------------------------------------------------------------------------

  bool _isFlushingObservations = false;
  bool _isFlushingTickets = false;

  Future<void> _flushPending() async {
    if (_isFlushingObservations) return;
    _isFlushingObservations = true;
    _notifySyncChanged();

    try {
      final db = _db;
      if (db == null) return;

      final currentVolunteerId = SessionState.instance.volunteerId;
      if (currentVolunteerId == null) {
        // Safe account boundary: do not flush observations without an authenticated volunteer context
        return;
      }

      // Only flush observations originating from the currently authenticated volunteer
      final rows = await db.query(
        _obsTableName,
        where: 'volunteer_id = ?',
        whereArgs: [currentVolunteerId],
        orderBy: 'id ASC',
      );
      if (rows.isEmpty) return;

      print('ObservationQueue: Attempting to flush ${rows.length} queued observation(s) for volunteer $currentVolunteerId.');

      int flushed = 0;
      for (final row in rows) {
        try {
          final supabaseInstance = Supabase.instance;
          final client = supabaseInstance.client;
          final table = client.from('observations');
          await table.insert({
            'ephemeral_id': row['ephemeral_id'],
            'rssi': row['rssi'],
            'scanned_at': row['scanned_at'],
            'is_spatially_device': (row['is_spatially_device'] as int) == 1,
            'volunteer_id': row['volunteer_id'],
            'event_id': row['event_id'],
            'zone': row['zone'],
          });
          await db.delete(
            _obsTableName,
            where: 'id = ?',
            whereArgs: [row['id']],
          );
          flushed++;
        } catch (e) {
          print('ObservationQueue: Failed to flush row id=${row['id']}, will retry: $e');
          break;
        }
      }

      if (flushed > 0) {
        _lastSyncedAt = DateTime.now();
        print('DEBUG: Flushed $flushed queued observations to Supabase');
      }
    } finally {
      _isFlushingObservations = false;
      _notifySyncChanged();
    }
  }

  Future<void> _flushPendingTickets() async {
    if (_isFlushingTickets) return;
    _isFlushingTickets = true;
    _notifySyncChanged();

    try {
      final db = _db;
      if (db == null) return;

      final currentVolunteerId = SessionState.instance.volunteerId;
      if (currentVolunteerId == null) {
        // Safe account boundary: do not flush check-ins without an authenticated volunteer context
        return;
      }

      final pending = await getPendingTicketCheckIns(volunteerId: currentVolunteerId);
      if (pending.isEmpty) return;

      print('ObservationQueue: Attempting to flush ${pending.length} queued ticket check-in(s) for volunteer $currentVolunteerId.');

      final client = Supabase.instance.client;
      bool anySynced = false;
      for (final record in pending) {
        if (record.id == null) continue;
        try {
          final response = await client.rpc('check_in_ticket', params: {
            'p_ticket_code': record.ticketCode,
            'p_event_id': record.eventId,
            'p_volunteer_id': currentVolunteerId,
          });

          if (response is Map<String, dynamic> && response['success'] == true) {
            await updateTicketCheckInStatus(record.id!, 'synced');
            anySynced = true;
            print('ObservationQueue: Successfully synced ticket ${record.ticketCode}');
          } else {
            final error = response is Map<String, dynamic>
                ? response['message']?.toString()
                : 'Server check-in rejected';
            await updateTicketCheckInStatus(record.id!, 'rejected', errorMessage: error);
            print('ObservationQueue: Rejected ticket ${record.ticketCode}: $error');
          }
        } catch (e) {
          print('ObservationQueue: Network error flushing ticket ${record.ticketCode}: $e');
          break; // Stop loop on network error; retry later
        }
      }
      if (anySynced) {
        _lastSyncedAt = DateTime.now();
      }
    } finally {
      _isFlushingTickets = false;
      _notifySyncChanged();
    }
  }

  /// Manually flush all pending queues immediately (e.g. from UI sync button).
  Future<void> flushAllNow() async {
    await _flushPending();
    await _flushPendingTickets();
    await flushPendingIncidents();
    _notifySyncChanged();
  }

  // -------------------------------------------------------------------------
  // Operational Incidents & Lost & Found Offline Outbox / Cache
  // -------------------------------------------------------------------------

  bool _isFlushingIncidents = false;

  Future<void> enqueuePendingIncident(Map<String, dynamic> row) async {
    final db = await getDb();
    await db.insert('pending_operational_incidents', row,
        conflictAlgorithm: ConflictAlgorithm.replace);
    print('ObservationQueue: Queued offline incident ${row['local_id']} (${row['title']})');
  }

  Future<List<Map<String, dynamic>>> getPendingIncidents({
    required String volunteerId,
    required String eventId,
  }) async {
    final db = await getDb();
    return await db.query(
      'pending_operational_incidents',
      where: 'volunteer_id = ? AND event_id = ? AND sync_status = ?',
      whereArgs: [volunteerId, eventId, 'pending'],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> removePendingIncident(String localId) async {
    final db = await getDb();
    await db.delete(
      'pending_operational_incidents',
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> cacheIncidents(String eventId, String volunteerId, List<Map<String, dynamic>> incidents) async {
    final db = await getDb();
    final batch = db.batch();
    for (final inc in incidents) {
      batch.insert(
        'cached_operational_incidents',
        {
          'id': inc['id'],
          'event_id': eventId,
          'volunteer_id': volunteerId,
          'payload_json': jsonEncode(inc),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedIncidents(String eventId, String volunteerId) async {
    final db = await getDb();
    final rows = await db.query(
      'cached_operational_incidents',
      where: 'event_id = ? AND volunteer_id = ?',
      whereArgs: [eventId, volunteerId],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => jsonDecode(r['payload_json'] as String) as Map<String, dynamic>).toList();
  }

  Future<void> cacheLostFoundReports(String eventId, String volunteerId, List<Map<String, dynamic>> items) async {
    final db = await getDb();
    final batch = db.batch();
    for (final it in items) {
      batch.insert(
        'cached_lost_found_reports',
        {
          'id': it['id'],
          'event_id': eventId,
          'volunteer_id': volunteerId,
          'payload_json': jsonEncode(it),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedLostFoundReports(String eventId, String volunteerId) async {
    final db = await getDb();
    final rows = await db.query(
      'cached_lost_found_reports',
      where: 'event_id = ? AND volunteer_id = ?',
      whereArgs: [eventId, volunteerId],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => jsonDecode(r['payload_json'] as String) as Map<String, dynamic>).toList();
  }

  Future<void> flushPendingIncidents() async {
    if (_isFlushingIncidents) return;
    _isFlushingIncidents = true;

    try {
      final currentVolunteerId = SessionState.instance.volunteerId;
      final currentEventId = SessionState.instance.eventId;
      if (currentVolunteerId == null || currentEventId == null) {
        return;
      }

      final pending = await getPendingIncidents(
        volunteerId: currentVolunteerId,
        eventId: currentEventId,
      );
      if (pending.isEmpty) return;

      print('ObservationQueue: Attempting to flush ${pending.length} queued incident(s)...');
      final client = Supabase.instance.client;

      for (final row in pending) {
        try {
          final res = await client.rpc('report_operational_incident', params: {
            'p_event_id': row['event_id'],
            'p_category': row['category'],
            'p_priority': row['priority'],
            'p_title': row['title'],
            'p_description': row['description'],
            'p_zone_id': row['zone_id'],
            'p_venue_zone_name': row['venue_zone_name'],
            'p_venue_poi_id': row['venue_poi_id'],
            'p_specific_location': row['specific_location'],
            'p_image_url': row['image_url'],
            'p_link_operational_message': (row['link_operational_message'] as int? ?? 0) == 1,
            'p_reporter_type': 'volunteer',
          });

          if (res is Map<String, dynamic> && res['success'] == true) {
            await removePendingIncident(row['local_id'] as String);
            print('ObservationQueue: Successfully flushed incident ${row['local_id']}');
          }
        } catch (e) {
          print('ObservationQueue: Network error flushing incident ${row['local_id']}: $e');
          break; // Stop loop on network failure
        }
      }
    } finally {
      _isFlushingIncidents = false;
    }
  }

  // -------------------------------------------------------------------------
  // Block 2.5C: Team & Shift Offline Caching
  // -------------------------------------------------------------------------

  Future<void> cacheVolunteerShifts({
    required String eventId,
    required String volunteerId,
    required List<Map<String, dynamic>> shifts,
  }) async {
    final db = await getDb();
    final batch = db.batch();
    batch.delete(
      'cached_volunteer_shifts',
      where: 'event_id = ? AND volunteer_id = ?',
      whereArgs: [eventId, volunteerId],
    );
    for (final s in shifts) {
      final id = s['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      batch.insert(
        'cached_volunteer_shifts',
        {
          'id': id,
          'event_id': eventId,
          'volunteer_id': volunteerId,
          'payload_json': jsonEncode(s),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedVolunteerShifts({
    required String eventId,
    required String volunteerId,
  }) async {
    final db = await getDb();
    final rows = await db.query(
      'cached_volunteer_shifts',
      where: 'event_id = ? AND volunteer_id = ?',
      whereArgs: [eventId, volunteerId],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => jsonDecode(r['payload_json'] as String) as Map<String, dynamic>).toList();
  }

  Future<void> cacheEventTeams({
    required String eventId,
    required List<Map<String, dynamic>> teams,
  }) async {
    final db = await getDb();
    final batch = db.batch();
    batch.delete('cached_event_teams', where: 'event_id = ?', whereArgs: [eventId]);
    for (final t in teams) {
      final id = t['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      batch.insert(
        'cached_event_teams',
        {
          'id': id,
          'event_id': eventId,
          'payload_json': jsonEncode(t),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedEventTeams({required String eventId}) async {
    final db = await getDb();
    final rows = await db.query(
      'cached_event_teams',
      where: 'event_id = ?',
      whereArgs: [eventId],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => jsonDecode(r['payload_json'] as String) as Map<String, dynamic>).toList();
  }

  Future<void> cacheSupervisorTasks({
    required String eventId,
    required List<Map<String, dynamic>> tasks,
  }) async {
    final db = await getDb();
    final batch = db.batch();
    batch.delete('cached_supervisor_tasks', where: 'event_id = ?', whereArgs: [eventId]);
    for (final t in tasks) {
      final id = t['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      batch.insert(
        'cached_supervisor_tasks',
        {
          'id': id,
          'event_id': eventId,
          'payload_json': jsonEncode(t),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedSupervisorTasks({
    required String eventId,
    String? assignedToId,
  }) async {
    final db = await getDb();
    final rows = await db.query(
      'cached_supervisor_tasks',
      where: 'event_id = ?',
      whereArgs: [eventId],
      orderBy: 'updated_at DESC',
    );
    final all = rows.map((r) => jsonDecode(r['payload_json'] as String) as Map<String, dynamic>).toList();
    if (assignedToId != null) {
      return all.where((t) => t['assigned_to_id'] == assignedToId).toList();
    }
    return all;
  }

  Future<void> cacheCoverageRequests({
    required String eventId,
    required List<Map<String, dynamic>> requests,
  }) async {
    final db = await getDb();
    final batch = db.batch();
    batch.delete('cached_coverage_requests', where: 'event_id = ?', whereArgs: [eventId]);
    for (final req in requests) {
      final id = req['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      batch.insert(
        'cached_coverage_requests',
        {
          'id': id,
          'event_id': eventId,
          'payload_json': jsonEncode(req),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedCoverageRequests({required String eventId}) async {
    final db = await getDb();
    final rows = await db.query(
      'cached_coverage_requests',
      where: 'event_id = ?',
      whereArgs: [eventId],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => jsonDecode(r['payload_json'] as String) as Map<String, dynamic>).toList();
  }

  Future<void> cacheShiftHandoffs({
    required String eventId,
    required List<Map<String, dynamic>> handoffs,
  }) async {
    final db = await getDb();
    final batch = db.batch();
    batch.delete('cached_shift_handoffs', where: 'event_id = ?', whereArgs: [eventId]);
    for (final h in handoffs) {
      final id = h['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      batch.insert(
        'cached_shift_handoffs',
        {
          'id': id,
          'event_id': eventId,
          'payload_json': jsonEncode(h),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedShiftHandoffs({required String eventId}) async {
    final db = await getDb();
    final rows = await db.query(
      'cached_shift_handoffs',
      where: 'event_id = ?',
      whereArgs: [eventId],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => jsonDecode(r['payload_json'] as String) as Map<String, dynamic>).toList();
  }

  // -------------------------------------------------------------------------
  // Block 2.5D: Event Awareness & Attention Caching
  // -------------------------------------------------------------------------

  Future<void> cacheAwarenessItems({
    required String eventId,
    required String volunteerId,
    required List<OperationalAwarenessItem> items,
  }) async {
    final db = await getDb();
    final batch = db.batch();
    batch.delete(
      'cached_awareness_items',
      where: 'event_id = ? AND volunteer_id = ?',
      whereArgs: [eventId, volunteerId],
    );
    for (final item in items) {
      final json = item.toJson();
      json['event_id'] = eventId;
      json['volunteer_id'] = volunteerId;
      json['is_cached'] = 1;
      batch.insert(
        'cached_awareness_items',
        json,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<OperationalAwarenessItem>> getCachedAwarenessItems({
    required String eventId,
    required String volunteerId,
  }) async {
    final db = await getDb();
    final rows = await db.query(
      'cached_awareness_items',
      where: 'event_id = ? AND volunteer_id = ?',
      whereArgs: [eventId, volunteerId],
      orderBy: 'timestamp DESC',
    );
    return rows.map((r) => OperationalAwarenessItem.fromJson(r)).toList();
  }

  Future<void> markAttentionKeyHandled(String key) async {
    final db = await getDb();
    await db.insert(
      'handled_attention_keys',
      {
        'key': key,
        'handled_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isAttentionKeyHandled(String key) async {
    final db = await getDb();
    final rows = await db.query(
      'handled_attention_keys',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> getHandledAttentionKeys() async {
    final db = await getDb();
    final rows = await db.query('handled_attention_keys');
    return rows.map((r) => r['key'] as String).toSet();
  }

  // -------------------------------------------------------------------------
  // Block 2.5E: Operational Health & Timeline Caching
  // -------------------------------------------------------------------------

  Future<void> cacheOperationalHealth(String eventId, String payloadJson) async {
    final db = await getDb();
    await db.insert(
      'cached_operational_health',
      {
        'event_id': eventId,
        'payload_json': payloadJson,
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCachedOperationalHealth(String eventId) async {
    final db = await getDb();
    final rows = await db.query(
      'cached_operational_health',
      where: 'event_id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final jsonStr = rows.first['payload_json'] as String;
      final cachedAt = rows.first['cached_at'] as String;
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      parsed['_cached_at'] = cachedAt;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheOperationalTimeline(String eventId, List<Map<String, dynamic>> items) async {
    final db = await getDb();
    final batch = db.batch();
    for (final item in items) {
      final id = item['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString();
      final ts = item['timestamp']?.toString() ?? DateTime.now().toIso8601String();
      batch.insert(
        'cached_operational_timeline',
        {
          'id': id,
          'event_id': eventId,
          'payload_json': jsonEncode(item),
          'timestamp': ts,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCachedOperationalTimeline(String eventId) async {
    final db = await getDb();
    final rows = await db.query(
      'cached_operational_timeline',
      where: 'event_id = ?',
      whereArgs: [eventId],
      orderBy: 'timestamp DESC',
      limit: 50,
    );
    final results = <Map<String, dynamic>>[];
    for (final r in rows) {
      try {
        final jsonStr = r['payload_json'] as String;
        results.add(jsonDecode(jsonStr) as Map<String, dynamic>);
      } catch (_) {}
    }
    return results;
  }

  // -------------------------------------------------------------------------
  // Teardown
  // -------------------------------------------------------------------------

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _syncInfoController.close();
    await _db?.close();
    _db = null;
  }
}
