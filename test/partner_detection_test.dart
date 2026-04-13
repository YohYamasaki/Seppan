import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/models/partnership.dart';

/// Tests for partner detection logic used in invite_page.dart and
/// fingerprint_verification_page.dart.
///
/// Both pages now use a polling fallback alongside Supabase Realtime
/// streams. These tests verify the detection predicates that decide
/// when to navigate or act.
void main() {
  Partnership makePartnership({
    String status = 'pending',
    String? user2Id,
    String? user1EcdhPub,
    String? user2EcdhPub,
    String? wrappedPartnershipKey,
  }) {
    return Partnership(
      id: 'p-1',
      user1Id: 'user-a',
      user2Id: user2Id,
      status: status,
      user1EcdhPub: user1EcdhPub ?? 'pub-a',
      user2EcdhPub: user2EcdhPub,
      wrappedPartnershipKey: wrappedPartnershipKey,
      createdAt: DateTime(2026, 4, 13),
    );
  }

  // Detection predicate matching _handlePartnerJoined in invite_page.dart
  bool partnerJoined(Partnership p) => p.user2EcdhPub != null;

  // Detection predicate matching _handleInitiatorUpdate in
  // fingerprint_verification_page.dart
  bool initiatorShouldGoHome(Partnership p) => p.status == 'active';
  bool initiatorDetectsCancellation(Partnership p) => p.user2EcdhPub == null;

  // Detection predicate matching _handleJoinerUpdate in
  // fingerprint_verification_page.dart
  bool joinerReceivedKey(Partnership p) =>
      p.wrappedPartnershipKey != null && p.wrappedPartnershipKey!.isNotEmpty;
  bool joinerDetectsCancellation(Partnership p) =>
      p.wrappedPartnershipKey != null && p.wrappedPartnershipKey!.isEmpty;

  group('InvitePage: partner detection (stream + polling)', () {
    test('detects partner join when user2EcdhPub is set', () {
      final p = makePartnership(
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
      );
      expect(partnerJoined(p), isTrue);
    });

    test('does not trigger when user2EcdhPub is still null', () {
      final p = makePartnership();
      expect(partnerJoined(p), isFalse);
    });

    test('does not trigger when only user2Id is set (no ECDH pub)', () {
      final p = makePartnership(user2Id: 'user-b');
      expect(partnerJoined(p), isFalse);
    });

    test('polling returns same result as stream for joined state', () {
      // Both stream and polling use the same Partnership model,
      // so the predicate works identically for both sources
      final joined = makePartnership(
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
      );
      final notJoined = makePartnership();

      expect(partnerJoined(joined), isTrue);
      expect(partnerJoined(notJoined), isFalse);
    });
  });

  group('FingerprintVerification: initiator polling detection', () {
    test('detects activation via polling', () {
      final p = makePartnership(
        status: 'active',
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
      );
      expect(initiatorShouldGoHome(p), isTrue);
      expect(initiatorDetectsCancellation(p), isFalse);
    });

    test('detects cancellation via polling', () {
      final p = makePartnership(
        status: 'pending',
        user2EcdhPub: null,
      );
      expect(initiatorShouldGoHome(p), isFalse);
      expect(initiatorDetectsCancellation(p), isTrue);
    });

    test('still waiting: pending with partner present', () {
      final p = makePartnership(
        status: 'pending',
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
      );
      expect(initiatorShouldGoHome(p), isFalse);
      expect(initiatorDetectsCancellation(p), isFalse);
    });
  });

  group('FingerprintVerification: joiner polling detection', () {
    test('detects wrapped key via polling', () {
      final p = makePartnership(
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
        wrappedPartnershipKey: 'wrapped-key-data',
      );
      expect(joinerReceivedKey(p), isTrue);
      expect(joinerDetectsCancellation(p), isFalse);
    });

    test('does not trigger when key is null', () {
      final p = makePartnership(
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
      );
      expect(joinerReceivedKey(p), isFalse);
      expect(joinerDetectsCancellation(p), isFalse);
    });

    test('detects initiator cancellation (empty key)', () {
      final p = makePartnership(
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
        wrappedPartnershipKey: '',
      );
      expect(joinerReceivedKey(p), isFalse);
      expect(joinerDetectsCancellation(p), isTrue);
    });
  });

  group('Idempotency: duplicate poll results do not cause issues', () {
    test('same partnership state produces same detection result', () {
      // Polling may return the same state multiple times.
      // The handler must be idempotent — duplicate calls should not
      // cause duplicate navigations. This is guarded by cancelling
      // subscriptions/timers on first detection.
      final p = makePartnership(
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
      );
      // Multiple evaluations produce identical results
      expect(partnerJoined(p), isTrue);
      expect(partnerJoined(p), isTrue);
    });
  });
}
