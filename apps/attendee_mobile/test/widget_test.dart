import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendee_mobile/features/profile/models/user_profile.dart';
import 'package:attendee_mobile/features/profile/widgets/profile_header_card.dart';
import 'package:attendee_mobile/features/profile/widgets/profile_account_section.dart';

void main() {
  group('Phase 4C Profile & Account Widget Tests', () {
    testWidgets('ProfileHeaderCard displays Guest badge and device ID in guest mode', (tester) async {
      final guest = UserProfile.defaultGuest('test-device-uuid-1234');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileHeaderCard(
              profile: guest,
              onEditProfile: () {},
            ),
          ),
        ),
      );

      expect(find.text('Attendee Guest'), findsOneWidget);
      expect(find.text('GUEST'), findsOneWidget);
      expect(find.textContaining('DEVICE ID: test-device-uuid-1234'), findsOneWidget);
    });

    testWidgets('ProfileHeaderCard displays Account badge and email when authenticated', (tester) async {
      const authUser = UserProfile(
        name: 'Jane Attendee',
        headline: 'Designer',
        deviceId: 'device-999',
        userId: 'auth-user-123',
        email: 'jane@example.com',
        isAnonymous: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileHeaderCard(
              profile: authUser,
              onEditProfile: () {},
            ),
          ),
        ),
      );

      expect(find.text('Jane Attendee'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('jane@example.com'), findsOneWidget);
      expect(find.textContaining('DEVICE ID: device-999'), findsOneWidget);
    });

    testWidgets('ProfileAccountSection displays Google sign-in button in guest mode', (tester) async {
      final guest = UserProfile.defaultGuest('test-device-uuid-1234');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileAccountSection(
                profile: guest,
                onResetRequested: () {},
                onSignInWithGoogle: () {},
                onSignOutRequested: () {},
                onClaimTicketsRequested: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Guest-First Session (Unauthenticated)'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Reset Profile & Preferences'), findsOneWidget);
    });

    testWidgets('ProfileAccountSection displays connected account info and sign-out when authenticated', (tester) async {
      const authUser = UserProfile(
        name: 'Jane Attendee',
        deviceId: 'device-999',
        userId: 'auth-user-123',
        email: 'jane@example.com',
        isAnonymous: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileAccountSection(
                profile: authUser,
                onResetRequested: () {},
                onSignInWithGoogle: () {},
                onSignOutRequested: () {},
                onClaimTicketsRequested: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Google Account Connected'), findsOneWidget);
      expect(find.text('jane@example.com'), findsOneWidget);
      expect(find.text('Claim Unlinked Guest Tickets'), findsOneWidget);
      expect(find.text('Sign Out of Account'), findsOneWidget);
    });
  });
}
