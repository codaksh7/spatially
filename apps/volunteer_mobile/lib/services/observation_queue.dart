import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ble_observation.dart';

/// Manages offline storage and cloud sync for BLE observations.
///
/// Architecture:
/// - Writes first attempt the Supabase insert directly (online-first).
/// - If that insert throws, the row is written to the local SQLite table
///   `pending_observations` instead of being silently dropped.
/// - A [Connectivity] listener triggers a flush whenever the device regains
///   connectivity (any non-none result).
/// - A startup flush also runs once, catching leftovers from a previous
///   offline session.
///
/// Only the observation write path uses this service.
/// volunteer_counts (periodic upsert) is intentionally excluded — a missed
/// tick self-heals on the next one.
class ObservationQueue {
  static final ObservationQueue _instance = ObservationQueue._internal();
  factory ObservationQueue() => _instance;
  ObservationQueue._internal();

  static const String _tableName = 'pending_observations';

  Database? _db;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // -------------------------------------------------------------------------
  // Initialisation
  // -------------------------------------------------------------------------

  /// Opens (or creates) the SQLite database and registers the connectivity
  /// listener. Call once from [TelemetryService.init].
  Future<void> init() async {
    await _openDb();
    _startConnectivityListener();
    // Flush any rows left from a previous offline session.
    await _flushPending();
  }

  Future<void> _openDb() async {
    _db = await openDatabase(
      'spatially_queue.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
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
      },
    );
    print('ObservationQueue: SQLite database opened (pending_observations table ready).');
  }

  void _startConnectivityListener() {
    // connectivity_plus v7 delivers List<ConnectivityResult>
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final hasConnection = results.any(
        (r) => r != ConnectivityResult.none,
      );
      if (hasConnection) {
        print('ObservationQueue: Connectivity restored — flushing pending observations.');
        _flushPending();
      }
    });
  }

  // -------------------------------------------------------------------------
  // Write path
  // -------------------------------------------------------------------------

  /// Attempts a direct Supabase insert. On failure, falls back to local queue.
  Future<void> sendOrQueue(BleObservation observation) async {
    try {
      final supabaseInstance = Supabase.instance;
      final client = supabaseInstance.client;
      final table = client.from('observations');
      final row = observation.toMap();
      await table.insert(row);
      print('TelemetryService: Successfully sent observation for ${observation.ephemeralId}');
    } catch (e) {
      print('TelemetryService ERROR: Failed to send observation, queuing offline: $e');
      await _enqueue(observation);
    }
  }

  Future<void> _enqueue(BleObservation obs) async {
    final db = _db;
    if (db == null) {
      print('ObservationQueue ERROR: Cannot queue — database not initialised.');
      return;
    }
    await db.insert(_tableName, {
      'ephemeral_id': obs.ephemeralId,
      'rssi': obs.rssi,
      'scanned_at': obs.scannedAt.toIso8601String(),
      'is_spatially_device': obs.isSpatiallyDevice ? 1 : 0,
      'volunteer_id': obs.volunteerId,
      'event_id': obs.eventId,
      'zone': obs.zone,
    });
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    ) ?? 0;
    print('DEBUG: Queued observation offline, pending_observations count=$count');
  }

  // -------------------------------------------------------------------------
  // Flush path
  // -------------------------------------------------------------------------

  bool _isFlushing = false;

  Future<void> _flushPending() async {
    if (_isFlushing) return; // prevent concurrent flush runs
    _isFlushing = true;

    try {
      final db = _db;
      if (db == null) return;

      final rows = await db.query(_tableName, orderBy: 'id ASC');
      if (rows.isEmpty) return;

      print('ObservationQueue: Attempting to flush ${rows.length} queued observation(s).');

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
          // Only delete after confirmed Supabase success.
          await db.delete(
            _tableName,
            where: 'id = ?',
            whereArgs: [row['id']],
          );
          flushed++;
        } catch (e) {
          // Leave the row in the queue; next flush will retry.
          print('ObservationQueue: Failed to flush row id=${row['id']}, will retry: $e');
          break; // If one fails, stop — subsequent ones will also fail.
        }
      }

      if (flushed > 0) {
        print('DEBUG: Flushed $flushed queued observations to Supabase');
      }
    } finally {
      _isFlushing = false;
    }
  }

  // -------------------------------------------------------------------------
  // Teardown
  // -------------------------------------------------------------------------

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _db?.close();
    _db = null;
  }
}
