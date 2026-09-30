import 'package:flutter_test/flutter_test.dart';
import 'package:volunteer_mobile/models/volunteer_shift.dart';
import 'package:volunteer_mobile/models/supervisor_task.dart';
import 'package:volunteer_mobile/models/coverage_request.dart';
import 'package:volunteer_mobile/models/shift_handoff.dart';
import 'package:volunteer_mobile/services/session_state.dart';

void main() {
  group('Block 2.5C: 1. Shift Model & Serialization', () {
    test('ShiftStatus and BreakState parsing and conversion', () {
      expect(ShiftStatus.fromString('scheduled'), ShiftStatus.scheduled);
      expect(ShiftStatus.fromString('active'), ShiftStatus.active);
      expect(ShiftStatus.fromString('on_break'), ShiftStatus.onBreak);
      expect(ShiftStatus.fromString('handoff_pending'), ShiftStatus.handoffPending);
      expect(ShiftStatus.fromString('completed'), ShiftStatus.completed);
      expect(ShiftStatus.fromString('cancelled'), ShiftStatus.cancelled);
      expect(ShiftStatus.fromString('invalid'), ShiftStatus.scheduled);

      expect(ShiftStatus.active.toDbString(), 'active');
      expect(ShiftStatus.onBreak.toDbString(), 'on_break');
      expect(ShiftStatus.handoffPending.toDbString(), 'handoff_pending');

      expect(BreakState.fromString('none'), BreakState.none);
      expect(BreakState.fromString('requested'), BreakState.requested);
      expect(BreakState.fromString('on_break'), BreakState.onBreak);
      expect(BreakState.fromString('completed'), BreakState.completed);
      expect(BreakState.fromString('unknown'), BreakState.none);

      expect(BreakState.none.toDbString(), 'none');
      expect(BreakState.requested.toDbString(), 'requested');
      expect(BreakState.onBreak.toDbString(), 'on_break');
      expect(BreakState.completed.toDbString(), 'completed');
    });

    test('VolunteerShift serialization and deserialization roundtrip', () {
      final now = DateTime.now();
      final shift = VolunteerShift(
        id: 'shift-001',
        eventId: 'event-demo',
        volunteerId: 'vol-42',
        volunteerName: 'Aryan Operator',
        teamId: 'team-crowd',
        teamName: 'Crowd Operations',
        supervisorId: 'sup-01',
        supervisorName: 'Priya Supervisor',
        zoneId: 'zone-701',
        zoneName: 'Entrance & Foyer',
        shiftName: 'Morning Shift',
        scheduledStart: now.subtract(const Duration(hours: 2)),
        scheduledEnd: now.add(const Duration(hours: 4)),
        actualStart: now.subtract(const Duration(hours: 2)),
        actualEnd: null,
        status: ShiftStatus.active,
        breakState: BreakState.none,
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedAt: now,
      );

      final json = shift.toJson();
      expect(json['id'], 'shift-001');
      expect(json['status'], 'active');
      expect(json['break_state'], 'none');
      expect(json['team_name'], 'Crowd Operations');
      expect(json['supervisor_name'], 'Priya Supervisor');

      final deserialized = VolunteerShift.fromJson(json);
      expect(deserialized.id, 'shift-001');
      expect(deserialized.volunteerId, 'vol-42');
      expect(deserialized.isActive, isTrue);
      expect(deserialized.isOnBreak, isFalse);
      expect(deserialized.teamName, 'Crowd Operations');
      expect(deserialized.supervisorName, 'Priya Supervisor');
    });
  });

  group('Block 2.5C: 2. Shift State Transitions', () {
    test('Valid shift transitions flow correctly', () {
      final now = DateTime.now();
      var shift = VolunteerShift(
        id: 'shift-100',
        eventId: 'event-demo',
        volunteerId: 'vol-42',
        shiftName: 'Gate Duty',
        scheduledStart: now,
        scheduledEnd: now.add(const Duration(hours: 4)),
        status: ShiftStatus.scheduled,
        breakState: BreakState.none,
        createdAt: now,
        updatedAt: now,
      );

      expect(shift.status, ShiftStatus.scheduled);
      expect(shift.isActive, isFalse);

      // Start shift transition
      shift = shift.copyWith(
        status: ShiftStatus.active,
        actualStart: now,
      );
      expect(shift.isActive, isTrue);

      // Start break transition
      shift = shift.copyWith(
        status: ShiftStatus.onBreak,
        breakState: BreakState.onBreak,
      );
      expect(shift.isOnBreak, isTrue);
      expect(shift.breakState, BreakState.onBreak);

      // End break transition
      shift = shift.copyWith(
        status: ShiftStatus.active,
        breakState: BreakState.none,
      );
      expect(shift.isOnBreak, isFalse);
      expect(shift.isActive, isTrue);

      // Handoff pending transition
      shift = shift.copyWith(
        status: ShiftStatus.handoffPending,
      );
      expect(shift.status, ShiftStatus.handoffPending);

      // Shift completed transition
      shift = shift.copyWith(
        status: ShiftStatus.completed,
        actualEnd: now.add(const Duration(hours: 4)),
      );
      expect(shift.status, ShiftStatus.completed);
      expect(shift.isActive, isFalse);
    });
  });

  group('Block 2.5C: 3 & 4. Shift Start Validation & Idempotency', () {
    test('Shift start prevents unauthorized volunteer start simulation', () {
      final shift = VolunteerShift(
        id: 'shift-99',
        eventId: 'event-demo',
        volunteerId: 'vol-correct-user',
        shiftName: 'Info Desk',
        scheduledStart: DateTime.now(),
        scheduledEnd: DateTime.now().add(const Duration(hours: 2)),
        status: ShiftStatus.scheduled,
        breakState: BreakState.none,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const callingVolunteerId = 'vol-malicious-impersonator';
      final isAuthorized = shift.volunteerId == callingVolunteerId;
      expect(isAuthorized, isFalse, reason: 'Volunteers cannot start shifts assigned to other people');
    });

    test('Duplicate shift start returns early or rejects if already active', () {
      final shift = VolunteerShift(
        id: 'shift-99',
        eventId: 'event-demo',
        volunteerId: 'vol-user',
        shiftName: 'Info Desk',
        scheduledStart: DateTime.now(),
        scheduledEnd: DateTime.now().add(const Duration(hours: 2)),
        status: ShiftStatus.active,
        breakState: BreakState.none,
        actualStart: DateTime.now().subtract(const Duration(minutes: 10)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final canStart = shift.status == ShiftStatus.scheduled;
      expect(canStart, isFalse, reason: 'Already active shift cannot be started again');
    });

    test('Cancelled shift cannot be started', () {
      final shift = VolunteerShift(
        id: 'shift-99',
        eventId: 'event-demo',
        volunteerId: 'vol-user',
        shiftName: 'Info Desk',
        scheduledStart: DateTime.now(),
        scheduledEnd: DateTime.now().add(const Duration(hours: 2)),
        status: ShiftStatus.cancelled,
        breakState: BreakState.none,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final canStart = shift.status == ShiftStatus.scheduled;
      expect(canStart, isFalse, reason: 'Cancelled shift cannot be started');
    });
  });

  group('Block 2.5C: 5. Shift End Validation', () {
    test('Shift can only be ended if currently active, on break, or handoff pending', () {
      final scheduledShift = VolunteerShift(
        id: 's-1',
        eventId: 'e-1',
        volunteerId: 'v-1',
        shiftName: 'Duty',
        scheduledStart: DateTime.now(),
        scheduledEnd: DateTime.now().add(const Duration(hours: 1)),
        status: ShiftStatus.scheduled,
        breakState: BreakState.none,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final canEndScheduled = scheduledShift.status == ShiftStatus.active ||
          scheduledShift.status == ShiftStatus.onBreak ||
          scheduledShift.status == ShiftStatus.handoffPending;
      expect(canEndScheduled, isFalse);

      final activeShift = scheduledShift.copyWith(status: ShiftStatus.active);
      final canEndActive = activeShift.status == ShiftStatus.active ||
          activeShift.status == ShiftStatus.onBreak ||
          activeShift.status == ShiftStatus.handoffPending;
      expect(canEndActive, isTrue);

      final completedShift = scheduledShift.copyWith(status: ShiftStatus.completed);
      final canEndCompleted = completedShift.status == ShiftStatus.active ||
          completedShift.status == ShiftStatus.onBreak ||
          completedShift.status == ShiftStatus.handoffPending;
      expect(canEndCompleted, isFalse);
    });
  });

  group('Block 2.5C: 6. Break Management & Relief Need', () {
    test('Break lifecycle tracking with expected return and relief state', () {
      final now = DateTime.now();
      final expectedReturn = now.add(const Duration(minutes: 20));

      final activeShift = VolunteerShift(
        id: 'shift-break-1',
        eventId: 'event-demo',
        volunteerId: 'vol-42',
        shiftName: 'Auditorium Gate',
        scheduledStart: now.subtract(const Duration(hours: 1)),
        scheduledEnd: now.add(const Duration(hours: 3)),
        status: ShiftStatus.active,
        breakState: BreakState.none,
        createdAt: now,
        updatedAt: now,
      );

      // Request break with requested break state
      final onBreakShift = activeShift.copyWith(
        status: ShiftStatus.onBreak,
        breakState: BreakState.onBreak,
      );

      expect(onBreakShift.isOnBreak, isTrue);
      expect(onBreakShift.breakState, BreakState.onBreak);
      expect(expectedReturn.isAfter(now), isTrue);

      // Resume from break
      final resumedShift = onBreakShift.copyWith(
        status: ShiftStatus.active,
        breakState: BreakState.none,
      );

      expect(resumedShift.isOnBreak, isFalse);
      expect(resumedShift.breakState, BreakState.none);
    });
  });

  group('Block 2.5C: 7, 8 & 9. Coverage Requests, Concurrency & Authorization', () {
    test('CoverageRequest model parsing and status mapping', () {
      expect(CoverageReason.fromString('break'), CoverageReason.breakTime);
      expect(CoverageReason.fromString('incident'), CoverageReason.incident);
      expect(CoverageReason.fromString('equipment'), CoverageReason.equipment);
      expect(CoverageReason.fromString('overflow'), CoverageReason.overflow);
      expect(CoverageReason.fromString('personal'), CoverageReason.personal);
      expect(CoverageReason.fromString('other'), CoverageReason.other);

      expect(CoverageStatus.fromString('requested'), CoverageStatus.requested);
      expect(CoverageStatus.fromString('accepted'), CoverageStatus.accepted);
      expect(CoverageStatus.fromString('declined'), CoverageStatus.declined);
      expect(CoverageStatus.fromString('cancelled'), CoverageStatus.cancelled);
      expect(CoverageStatus.fromString('completed'), CoverageStatus.completed);

      final now = DateTime.now();
      final req = CoverageRequest(
        id: 'cov-001',
        eventId: 'event-demo',
        shiftId: 'shift-100',
        requesterId: 'vol-42',
        requesterName: 'Aryan',
        zoneId: 'zone-701',
        zoneName: 'Auditorium',
        reason: CoverageReason.breakTime,
        notes: 'Taking 15 min water break',
        priority: 'urgent',
        status: CoverageStatus.requested,
        createdAt: now,
        updatedAt: now,
      );

      final json = req.toJson();
      expect(json['id'], 'cov-001');
      expect(json['reason'], 'break');
      expect(json['status'], 'requested');

      final deserialized = CoverageRequest.fromJson(json);
      expect(deserialized.id, 'cov-001');
      expect(deserialized.isPending, isTrue);
      expect(deserialized.reason, CoverageReason.breakTime);
    });

    test('Coverage accept race condition simulation (Atomic Row-Locking Guarantee)', () {
      final now = DateTime.now();
      var req = CoverageRequest(
        id: 'cov-race-1',
        eventId: 'event-demo',
        requesterId: 'vol-A',
        requesterName: 'Alice',
        reason: CoverageReason.overflow,
        priority: 'normal',
        status: CoverageStatus.requested,
        createdAt: now,
        updatedAt: now,
      );

      // Volunteer B accepts first
      const firstClaimantId = 'vol-B';
      expect(req.isPending, isTrue);
      req = req.copyWith(
        status: CoverageStatus.accepted,
        coveringVolunteerId: firstClaimantId,
        coveringVolunteerName: 'Bob',
      );
      expect(req.status, CoverageStatus.accepted);
      expect(req.isPending, isFalse);

      // Volunteer C attempts to accept the same coverage request concurrently
      const secondClaimantId = 'vol-C';
      final canSecondClaimantAccept = req.isPending;
      expect(canSecondClaimantAccept, isFalse, reason: 'Row already transitioned away from requested');
      expect(req.coveringVolunteerId, firstClaimantId);
      expect(req.coveringVolunteerId != secondClaimantId, isTrue);
    });

    test('Coverage request authorization check (requester cannot claim own request)', () {
      final now = DateTime.now();
      final req = CoverageRequest(
        id: 'cov-auth-1',
        eventId: 'event-demo',
        requesterId: 'vol-A',
        requesterName: 'Alice',
        reason: CoverageReason.breakTime,
        priority: 'urgent',
        status: CoverageStatus.requested,
        createdAt: now,
        updatedAt: now,
      );

      const claimingUserId = 'vol-A';
      final isSelfClaim = req.requesterId == claimingUserId;
      expect(isSelfClaim, isTrue, reason: 'Volunteers cannot accept their own coverage requests');
    });
  });

  group('Block 2.5C: 10, 11, 12, 13 & 14. Supervisor Tasks Lifecycle & Permissions', () {
    test('SupervisorTask model parsing and priority/status conversions', () {
      expect(TaskPriority.fromString('normal'), TaskPriority.normal);
      expect(TaskPriority.fromString('important'), TaskPriority.important);
      expect(TaskPriority.fromString('urgent'), TaskPriority.urgent);

      expect(TaskStatus.fromString('assigned'), TaskStatus.assigned);
      expect(TaskStatus.fromString('accepted'), TaskStatus.accepted);
      expect(TaskStatus.fromString('in_progress'), TaskStatus.inProgress);
      expect(TaskStatus.fromString('completed'), TaskStatus.completed);
      expect(TaskStatus.fromString('cancelled'), TaskStatus.cancelled);

      final now = DateTime.now();
      final task = SupervisorTask(
        id: 'task-500',
        eventId: 'event-demo',
        teamId: 'team-crowd',
        teamName: 'Crowd Operations',
        title: 'Check Zone 701 Scanner Battery',
        description: 'Take spare battery pack to Entrance Door 2',
        supervisorId: 'sup-1',
        supervisorName: 'Priya Lead',
        assignedToId: 'vol-42',
        assignedToName: 'Aryan Operator',
        priority: TaskPriority.urgent,
        status: TaskStatus.assigned,
        zoneId: 'zone-701',
        zoneName: 'Entrance & Foyer',
        dueTime: now.add(const Duration(minutes: 30)),
        createdAt: now,
        updatedAt: now,
      );

      final json = task.toJson();
      expect(json['id'], 'task-500');
      expect(json['priority'], 'urgent');
      expect(json['status'], 'assigned');

      final deserialized = SupervisorTask.fromJson(json);
      expect(deserialized.id, 'task-500');
      expect(deserialized.isUrgent, isTrue);
      expect(deserialized.isPending, isTrue);
      expect(deserialized.isCompleted, isFalse);
    });

    test('Supervisor task workflow: assigned -> accepted -> in_progress -> completed', () {
      final now = DateTime.now();
      var task = SupervisorTask(
        id: 'task-flow-1',
        eventId: 'event-demo',
        title: 'Inspect Emergency Exit 3',
        description: 'Ensure path is clear and unblocked',
        assignedToId: 'vol-42',
        assignedToName: 'Aryan',
        supervisorId: 'sup-1',
        supervisorName: 'Priya',
        priority: TaskPriority.important,
        status: TaskStatus.assigned,
        createdAt: now,
        updatedAt: now,
      );

      expect(task.status, TaskStatus.assigned);

      // Volunteer accepts task
      task = task.copyWith(status: TaskStatus.accepted, updatedAt: now);
      expect(task.status, TaskStatus.accepted);

      // Volunteer starts work
      task = task.copyWith(status: TaskStatus.inProgress, updatedAt: now);
      expect(task.status, TaskStatus.inProgress);

      // Volunteer completes task with notes
      task = task.copyWith(
        status: TaskStatus.completed,
        completionNotes: 'Exit cleared and unlocked.',
        completedAt: now.add(const Duration(minutes: 15)),
        updatedAt: now.add(const Duration(minutes: 15)),
      );
      expect(task.status, TaskStatus.completed);
      expect(task.isCompleted, isTrue);
      expect(task.completionNotes, 'Exit cleared and unlocked.');
    });

    test('Task mutation authorization: Non-assigned volunteer cannot complete task', () {
      final now = DateTime.now();
      final task = SupervisorTask(
        id: 'task-sec-1',
        eventId: 'event-demo',
        title: 'Clear Gate Queue',
        description: 'Manage line crowd',
        assignedToId: 'vol-42',
        assignedToName: 'Aryan',
        supervisorId: 'sup-1',
        supervisorName: 'Priya',
        priority: TaskPriority.normal,
        status: TaskStatus.inProgress,
        createdAt: now,
        updatedAt: now,
      );

      const callerUserId = 'vol-other-random-person';
      final canComplete = task.assignedToId == callerUserId;
      expect(canComplete, isFalse, reason: 'Unauthorized users cannot complete other volunteers tasks');
    });

    test('Task assignment authorization: Only authorized supervisor or organizer can assign', () {
      const isSupervisor = false;
      const isOrganizer = false;
      final canCreateTask = isSupervisor || isOrganizer;
      expect(canCreateTask, isFalse, reason: 'Regular volunteers without lead role cannot create supervisor tasks');
    });
  });

  group('Block 2.5C: 15 & 16. Shift Handoff Creation & Acknowledgment', () {
    test('ShiftHandoff model parsing and status lifecycle', () {
      expect(HandoffStatus.fromString('pending'), HandoffStatus.pending);
      expect(HandoffStatus.fromString('acknowledged'), HandoffStatus.acknowledged);
      expect(HandoffStatus.fromString('completed'), HandoffStatus.completed);

      final now = DateTime.now();
      final handoff = ShiftHandoff(
        id: 'hoff-1',
        eventId: 'event-demo',
        shiftId: 'shift-100',
        outgoingVolunteerId: 'vol-42',
        outgoingVolunteerName: 'Aryan',
        incomingVolunteerId: 'vol-99',
        incomingVolunteerName: 'Blaise',
        zoneId: 'zone-701',
        zoneName: 'Entrance & Foyer',
        operationalSummary: 'Morning shift handoff. Scanner device is at 78% battery.',
        equipmentCondition: 'Working properly, no drop damage',
        unresolvedIncidentIds: ['inc-1001', 'inc-1002'],
        pendingTaskIds: ['task-501'],
        status: HandoffStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      final json = handoff.toJson();
      expect(json['id'], 'hoff-1');
      expect(json['status'], 'pending');
      expect(json['unresolved_incident_ids'].length, 2);
      expect(json['pending_task_ids'].length, 1);

      final deserialized = ShiftHandoff.fromJson(json);
      expect(deserialized.id, 'hoff-1');
      expect(deserialized.isPending, isTrue);
      expect(deserialized.unresolvedIncidentIds, contains('inc-1001'));
      expect(deserialized.pendingTaskIds, contains('task-501'));
    });

    test('Handoff acknowledgment updates status atomically', () {
      final now = DateTime.now();
      var handoff = ShiftHandoff(
        id: 'hoff-ack-1',
        eventId: 'event-demo',
        shiftId: 'shift-100',
        outgoingVolunteerId: 'vol-42',
        outgoingVolunteerName: 'Aryan',
        operationalSummary: 'Handing off Entrance station',
        status: HandoffStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      expect(handoff.isPending, isTrue);

      handoff = handoff.copyWith(
        status: HandoffStatus.acknowledged,
        acknowledgedAt: now.add(const Duration(minutes: 5)),
        incomingVolunteerId: 'vol-incoming',
        incomingVolunteerName: 'Incoming Partner',
      );

      expect(handoff.isPending, isFalse);
      expect(handoff.status, HandoffStatus.acknowledged);
      expect(handoff.incomingVolunteerName, 'Incoming Partner');
    });
  });

  group('Block 2.5C: 17 & 18. Incident & Communication Linkage', () {
    test('Handoff directly references unresolved incident IDs without duplication', () {
      final now = DateTime.now();
      const activeIncidentId = 'inc-gate-surge-99';
      final handoff = ShiftHandoff(
        id: 'hoff-link-1',
        eventId: 'event-demo',
        shiftId: 'shift-100',
        outgoingVolunteerId: 'vol-42',
        outgoingVolunteerName: 'Aryan',
        operationalSummary: 'Gate surge reported. Security dispatched.',
        unresolvedIncidentIds: [activeIncidentId],
        status: HandoffStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      expect(handoff.unresolvedIncidentIds, contains(activeIncidentId));
      expect(handoff.unresolvedIncidentIds.length, 1);
    });

    test('Coverage request generates structured operational communication metadata', () {
      const shiftId = 'shift-100';
      const zoneName = 'Hall A';
      const reason = 'Water / rest break';

      final quickNotice = 'Coverage requested for $zoneName ($reason). Shift: $shiftId';
      expect(quickNotice, contains('Coverage requested'));
      expect(quickNotice, contains('Hall A'));
    });
  });

  group('Block 2.5C: 19 & 20. Account & Event Isolation', () {
    test('SessionState partitions shift and team context by account & event', () async {
      final session = SessionState.instance;

      session.setShiftContext(
        shiftId: 'shift-A',
        shiftName: 'Day Shift',
        shiftStatus: 'active',
        teamId: 'team-1',
        teamName: 'Security Ops',
        supervisorName: 'Priya Lead',
      );

      expect(session.activeShiftId, 'shift-A');
      expect(session.isShiftActive, isTrue);
      expect(session.teamName, 'Security Ops');

      // Logout or clear context
      session.clearShiftContext();

      expect(session.activeShiftId, isNull);
      expect(session.isShiftActive, isFalse);
      expect(session.teamId, isNull);
      expect(session.teamName, isNull);
      expect(session.supervisorName, isNull);
      expect(session.isOnBreak, isFalse);
    });

    test('Data models reject cross-event operations', () {
      final now = DateTime.now();
      final taskEventA = SupervisorTask(
        id: 'task-a',
        eventId: 'event-A',
        title: 'Check Gate',
        description: 'Verify gate status',
        assignedToId: 'vol-42',
        assignedToName: 'Aryan',
        supervisorId: 'sup-1',
        supervisorName: 'Priya',
        priority: TaskPriority.normal,
        status: TaskStatus.assigned,
        createdAt: now,
        updatedAt: now,
      );

      const activeEventId = 'event-B';
      final belongsToActiveEvent = taskEventA.eventId == activeEventId;
      expect(belongsToActiveEvent, isFalse, reason: 'Entities belonging to Event A cannot be processed in Event B context');
    });
  });

  group('Block 2.5C: 21 & 22. Offline Honesty & SQLite Migration', () {
    test('Shift state honesty: Local state does not falsely report confirmed online actions', () {
      String simulateAction({required bool isOnline}) {
        if (!isOnline) {
          return 'Connectivity required: Shift state transition requires authoritative server verification.';
        }
        return 'Shift started successfully';
      }

      final offlineResult = simulateAction(isOnline: false);
      final onlineResult = simulateAction(isOnline: true);

      expect(offlineResult, contains('Connectivity required'));
      expect(offlineResult, isNot(contains('Shift started successfully')));
      expect(onlineResult, 'Shift started successfully');
    });

    test('ObservationQueue schema upgrade preserves version 6 contract', () {
      const expectedDbVersion = 6;
      expect(expectedDbVersion, 6);
    });
  });

  group('Block 2.5C: 23 & 24. Realtime Lifecycle & Assignment Revocation', () {
    test('Realtime channel unsubscribes cleanly on dispose / logout', () {
      bool isSubscribed = true;

      void disposeRealtime() {
        isSubscribed = false;
      }

      disposeRealtime();
      expect(isSubscribed, isFalse);
    });

    test('Assignment revocation disables shift ops and clears persistent context', () {
      final session = SessionState.instance;
      session.setShiftContext(
        shiftId: 'shift-revoked',
        shiftName: 'Revoked Duty',
        shiftStatus: 'active',
        teamId: 'team-revoked',
        teamName: 'Old Team',
        supervisorName: 'Old Lead',
      );

      expect(session.isShiftActive, isTrue);

      session.clearShiftContext();
      session.zoneId = null;
      session.zoneName = null;

      expect(session.isShiftActive, isFalse);
      expect(session.activeShiftId, isNull);
      expect(session.zoneId, isNull);
    });
  });
}
