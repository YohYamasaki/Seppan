import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/models/partnership.dart';

/// Tests for the two-phase fingerprint verification handshake.
///
/// The linking flow has two phases to prevent one-sided linking:
///
///   Phase 1 — A (initiator) confirms:
///     Stores wrapped_partnership_key (status stays 'pending').
///     Watches for status='active' (B's confirmation) or
///     user2EcdhPub=null (B cancelled).
///
///   Phase 2 — B (joiner) confirms:
///     Receives key via Realtime, unwraps, caches, then sets status='active'.
///
/// Cancel at any point:
///   B cancels → clears user2_id/user2_ecdh_pub → A detects via watch.
///   A cancels → clears wrapped_partnership_key → B never receives key.
void main() {
  Partnership makePartnership({
    String status = 'pending',
    String? user2Id,
    String? user2EcdhPub,
    String? wrappedPartnershipKey,
  }) {
    return Partnership(
      id: 'p-1',
      user1Id: 'user-a',
      user2Id: user2Id,
      status: status,
      user1EcdhPub: 'pub-a',
      user2EcdhPub: user2EcdhPub,
      wrappedPartnershipKey: wrappedPartnershipKey,
      createdAt: DateTime(2026, 4, 13),
    );
  }

  // Guard function matching _onConfirmInitiator logic
  bool initiatorShouldAbort(Partnership? p) =>
      p == null || p.user2EcdhPub == null;

  // Status check matching A's watch handler
  bool linkIsComplete(Partnership p) => p.status == 'active';
  bool joinerCancelled(Partnership p) => p.user2EcdhPub == null;

  // Key availability check matching B's watch handler.
  // Non-null AND non-empty = real key. Empty string = A cancelled.
  bool keyIsAvailable(Partnership p) =>
      p.wrappedPartnershipKey != null && p.wrappedPartnershipKey!.isNotEmpty;
  bool initiatorCancelled(Partnership p) =>
      p.wrappedPartnershipKey != null && p.wrappedPartnershipKey!.isEmpty;

  group('Phase 1: A (initiator) confirm guard', () {
    test('aborts when partnership not found', () {
      expect(initiatorShouldAbort(null), isTrue);
    });

    test('aborts when user2EcdhPub is null (B cancelled)', () {
      final p = makePartnership(user2EcdhPub: null);
      expect(initiatorShouldAbort(p), isTrue);
    });

    test('proceeds when B is present', () {
      final p = makePartnership(
          user2Id: 'user-b', user2EcdhPub: 'pub-b');
      expect(initiatorShouldAbort(p), isFalse);
    });
  });

  group('Phase 1: A watches for B\'s response', () {
    test('detects link completion (status=active)', () {
      final p = makePartnership(
        status: 'active',
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
        wrappedPartnershipKey: 'wrapped-key',
      );
      expect(linkIsComplete(p), isTrue);
      expect(joinerCancelled(p), isFalse);
    });

    test('detects B cancelled (user2EcdhPub cleared)', () {
      final p = makePartnership(
        status: 'pending',
        user2EcdhPub: null,
        wrappedPartnershipKey: 'wrapped-key',
      );
      expect(linkIsComplete(p), isFalse);
      expect(joinerCancelled(p), isTrue);
    });

    test('pending with B present: still waiting', () {
      final p = makePartnership(
        status: 'pending',
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
        wrappedPartnershipKey: 'wrapped-key',
      );
      expect(linkIsComplete(p), isFalse);
      expect(joinerCancelled(p), isFalse);
    });
  });

  group('Phase 2: B (joiner) key reception', () {
    test('key available when wrappedPartnershipKey is set', () {
      final p = makePartnership(
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
        wrappedPartnershipKey: 'wrapped-key',
      );
      expect(keyIsAvailable(p), isTrue);
    });

    test('key not available when wrappedPartnershipKey is null', () {
      final p = makePartnership(
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
      );
      expect(keyIsAvailable(p), isFalse);
    });

    test('A cancelled: empty wrappedPartnershipKey is not a real key', () {
      final p = makePartnership(
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
        wrappedPartnershipKey: '',
      );
      expect(keyIsAvailable(p), isFalse);
      expect(initiatorCancelled(p), isTrue);
    });
  });

  group('Cancel scenarios', () {
    test('B cancels before A confirms: A sees user2EcdhPub=null', () {
      // B pressed cancel → unjoinPartnership clears user2
      final afterBCancel = makePartnership(
        user2EcdhPub: null,
        user2Id: null,
      );
      // A's confirm guard checks this
      expect(initiatorShouldAbort(afterBCancel), isTrue);
    });

    test('B cancels after A confirms: A detects via watch', () {
      // A stored wrapped key (status=pending), B then cancels
      final afterBCancel = makePartnership(
        wrappedPartnershipKey: 'wrapped-key',
        user2EcdhPub: null,
        user2Id: null,
      );
      // A's watch handler checks user2EcdhPub
      expect(joinerCancelled(afterBCancel), isTrue);
      expect(linkIsComplete(afterBCancel), isFalse);
    });

    test('A cancels: B detects empty wrappedPartnershipKey', () {
      final afterACancel = makePartnership(
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
        wrappedPartnershipKey: '',
      );
      expect(initiatorCancelled(afterACancel), isTrue);
      expect(keyIsAvailable(afterACancel), isFalse);
    });

    test('neither cancels, both confirm: status becomes active', () {
      // Full happy path end state
      final completed = makePartnership(
        status: 'active',
        user2Id: 'user-b',
        user2EcdhPub: 'pub-b',
        wrappedPartnershipKey: 'wrapped-key',
      );
      expect(linkIsComplete(completed), isTrue);
      expect(joinerCancelled(completed), isFalse);
      expect(initiatorShouldAbort(completed), isFalse);
    });
  });
}
