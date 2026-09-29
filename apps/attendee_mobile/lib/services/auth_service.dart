import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'attendee_identity.dart';

/// Result of an atomic guest ticket claim operation.
class ClaimTicketsResult {
  final bool success;
  final int claimedCount;
  final int alreadyOwnedCount;
  final int conflictCount;
  final List<String> claimedTicketIds;
  final String? errorMessage;

  const ClaimTicketsResult({
    required this.success,
    this.claimedCount = 0,
    this.alreadyOwnedCount = 0,
    this.conflictCount = 0,
    this.claimedTicketIds = const [],
    this.errorMessage,
  });

  factory ClaimTicketsResult.fromRpc(Map<String, dynamic> json) {
    final ids = (json['claimed_ticket_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    return ClaimTicketsResult(
      success: json['success'] as bool? ?? false,
      claimedCount: json['claimed_count'] as int? ?? 0,
      alreadyOwnedCount: json['already_owned_count'] as int? ?? 0,
      conflictCount: json['conflict_count'] as int? ?? 0,
      claimedTicketIds: ids,
    );
  }

  factory ClaimTicketsResult.error(String message) {
    return ClaimTicketsResult(
      success: false,
      errorMessage: message,
    );
  }
}

/// Central authentication and session management service for Spatially Attendee.
///
/// Encapsulates Supabase Auth operations while preserving the four-tier identity
/// model:
/// 1. Local Device ID ([AttendeeIdentity.deviceId]): Preserved across login/logout.
/// 2. BLE Ephemeral ID: Strictly isolated from user accounts.
/// 3. Social Identity: Opt-in attendee profile.
/// 4. Supabase Auth UID: Authenticated cloud identity for RLS ownership.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Stream of Supabase Auth state changes (signedIn, signedOut, tokenRefreshed, etc.).
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  /// The currently authenticated Supabase user, or null if in guest mode.
  User? get currentUser => _supabase.auth.currentUser;

  /// True if the user is currently authenticated with a permanent cloud account.
  bool get isAuthenticated => _supabase.auth.currentUser != null;

  /// The authenticated user's unique cloud UUID (auth.uid()), or null if guest.
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// The authenticated user's email address, or null if guest.
  String? get currentEmail => _supabase.auth.currentUser?.email;

  /// Canonical deep link redirect URI for OAuth callbacks on Android.
  static const String kOAuthRedirectUri = 'io.supabase.spatially://login-callback';

  /// Initiates the standard Google OAuth sign-in flow.
  ///
  /// Opens the system browser / Chrome Custom Tab for Google authentication.
  /// Once the user approves, Supabase redirects to [kOAuthRedirectUri], which
  /// is captured by the deep-link intent filter in AndroidManifest.xml and
  /// resolved by the supabase_flutter client SDK.
  Future<bool> signInWithGoogle() async {
    try {
      final success = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : kOAuthRedirectUri,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return success;
    } on AuthException catch (e) {
      debugPrint('AuthException in signInWithGoogle: ${e.message} (code: ${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error in signInWithGoogle: $e');
      rethrow;
    }
  }

  /// Signs out of the authenticated Supabase cloud session.
  ///
  /// IMPORTANT: Does NOT clear or reset [AttendeeIdentity.deviceId].
  /// The local device installation identity survives logout.
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Error during signOut: $e');
      rethrow;
    }
  }

  /// Claims all unlinked guest tickets belonging to the current device installation
  /// for the currently authenticated user account using the canonical Phase 4B RPC.
  ///
  /// Calls `public.claim_guest_tickets(p_device_id, p_claim_token)`.
  /// Must be invoked while authenticated ([isAuthenticated] == true).
  Future<ClaimTicketsResult> claimGuestTickets() async {
    if (!isAuthenticated) {
      return ClaimTicketsResult.error('Authentication required to claim guest tickets.');
    }

    final deviceId = AttendeeIdentity.deviceId;
    if (deviceId == null || deviceId.isEmpty) {
      return ClaimTicketsResult.error('No local device installation ID found.');
    }

    try {
      final response = await _supabase.rpc(
        'claim_guest_tickets',
        params: {
          'p_device_id': deviceId,
          'p_claim_token': 'guest_installation_token',
        },
      ).timeout(const Duration(seconds: 8));

      if (response is Map<String, dynamic>) {
        return ClaimTicketsResult.fromRpc(response);
      }
      return const ClaimTicketsResult(success: true);
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException claiming guest tickets: ${e.message} (code: ${e.code})');
      return ClaimTicketsResult.error(e.message);
    } catch (e) {
      debugPrint('Unexpected error claiming guest tickets: $e');
      return ClaimTicketsResult.error(e.toString());
    }
  }
}
