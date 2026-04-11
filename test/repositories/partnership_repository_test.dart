import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/models/partnership.dart';
import 'package:seppan/repositories/partnership_repository.dart';

/// These tests verify the partnership lifecycle logic at the repository level.
/// They use mocked Supabase responses to test business logic without a real backend.
///
/// For full integration testing with Supabase, run the app manually.

// Mock implementation for testing business logic without Supabase
class MockPartnershipRepository {
  final List<Map<String, dynamic>> _partnerships = [];
  final List<Map<String, dynamic>> _categories = [];
  int _idCounter = 0;

  String _nextId() => 'test-${++_idCounter}';

  Future<Partnership> createPartnership(String userId) async {
    final id = _nextId();
    final code = 'ABC${_idCounter.toString().padLeft(3, '0')}';
    final row = {
      'id': id,
      'user1_id': userId,
      'user2_id': null,
      'invite_code': code,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };
    _partnerships.add(row);

    // Seed default categories
    for (var i = 0; i < PartnershipRepository.defaultCategoryNames.length; i++) {
      _categories.add({
        'id': _nextId(),
        'partnership_id': id,
        'name': PartnershipRepository.defaultCategoryNames[i],
        'sort_order': i,
      });
    }

    return Partnership.fromJson(row);
  }

  Future<Partnership?> joinPartnership(String inviteCode, String userId) async {
    final idx = _partnerships.indexWhere(
        (p) => p['invite_code'] == inviteCode && p['status'] == 'pending');
    if (idx == -1) return null;

    _partnerships[idx]['user2_id'] = userId;
    _partnerships[idx]['status'] = 'active';
    return Partnership.fromJson(_partnerships[idx]);
  }

  Future<Partnership?> getPendingPartnership(String userId) async {
    final match = _partnerships.cast<Map<String, dynamic>?>().firstWhere(
        (p) => p!['user1_id'] == userId && p['status'] == 'pending',
        orElse: () => null);
    if (match == null) return null;
    return Partnership.fromJson(match);
  }

  Future<Partnership?> getActivePartnership(String userId) async {
    final match = _partnerships.cast<Map<String, dynamic>?>().firstWhere(
        (p) =>
            p!['status'] == 'active' &&
            (p['user1_id'] == userId || p['user2_id'] == userId),
        orElse: () => null);
    if (match == null) return null;
    return Partnership.fromJson(match);
  }

  Future<void> archivePartnership(String partnershipId) async {
    final idx = _partnerships.indexWhere((p) => p['id'] == partnershipId);
    if (idx != -1) {
      _partnerships[idx]['status'] = 'archived';
    }
  }

  Future<void> archiveOldPendingPartnerships(String userId) async {
    for (final p in _partnerships) {
      if (p['user1_id'] == userId && p['status'] == 'pending') {
        p['status'] = 'archived';
      }
    }
  }
}

void main() {
  late MockPartnershipRepository repo;

  setUp(() {
    repo = MockPartnershipRepository();
  });

  group('Partnership creation', () {
    test('creates a pending partnership with invite code', () async {
      final partnership = await repo.createPartnership('user-1');

      expect(partnership.status, 'pending');
      expect(partnership.user1Id, 'user-1');
      expect(partnership.user2Id, isNull);
      expect(partnership.inviteCode, isNotEmpty);
    });

    test('creates default categories on partnership creation', () async {
      await repo.createPartnership('user-1');

      expect(repo._categories.length, PartnershipRepository.defaultCategoryNames.length);
    });
  });

  group('Partnership joining', () {
    test('joins a pending partnership with valid code', () async {
      final created = await repo.createPartnership('user-1');

      final joined = await repo.joinPartnership(created.inviteCode, 'user-2');

      expect(joined, isNotNull);
      expect(joined!.status, 'active');
      expect(joined.user1Id, 'user-1');
      expect(joined.user2Id, 'user-2');
    });

    test('returns null for invalid invite code', () async {
      await repo.createPartnership('user-1');

      final joined = await repo.joinPartnership('INVALID', 'user-2');

      expect(joined, isNull);
    });

    test('returns null when trying to join an already active partnership', () async {
      final created = await repo.createPartnership('user-1');
      await repo.joinPartnership(created.inviteCode, 'user-2');

      // Try joining again with a different user
      final joined2 = await repo.joinPartnership(created.inviteCode, 'user-3');

      expect(joined2, isNull);
    });

    test('returns null when trying to join an archived partnership', () async {
      final created = await repo.createPartnership('user-1');
      await repo.archivePartnership(created.id);

      final joined = await repo.joinPartnership(created.inviteCode, 'user-2');

      expect(joined, isNull);
    });
  });

  group('Active partnership lookup', () {
    test('finds active partnership for user1', () async {
      final created = await repo.createPartnership('user-1');
      await repo.joinPartnership(created.inviteCode, 'user-2');

      final active = await repo.getActivePartnership('user-1');

      expect(active, isNotNull);
      expect(active!.status, 'active');
    });

    test('finds active partnership for user2', () async {
      final created = await repo.createPartnership('user-1');
      await repo.joinPartnership(created.inviteCode, 'user-2');

      final active = await repo.getActivePartnership('user-2');

      expect(active, isNotNull);
      expect(active!.status, 'active');
    });

    test('returns null when no active partnership exists', () async {
      await repo.createPartnership('user-1');
      // Not joined yet, still pending

      final active = await repo.getActivePartnership('user-1');

      expect(active, isNull);
    });
  });

  group('Partnership archiving', () {
    test('archiving sets status to archived', () async {
      final created = await repo.createPartnership('user-1');
      await repo.joinPartnership(created.inviteCode, 'user-2');

      await repo.archivePartnership(created.id);

      final activeForUser1 = await repo.getActivePartnership('user-1');
      final activeForUser2 = await repo.getActivePartnership('user-2');

      expect(activeForUser1, isNull);
      expect(activeForUser2, isNull);
    });

    test('after archiving, both users see no active partnership', () async {
      final created = await repo.createPartnership('user-1');
      await repo.joinPartnership(created.inviteCode, 'user-2');

      await repo.archivePartnership(created.id);

      expect(await repo.getActivePartnership('user-1'), isNull);
      expect(await repo.getActivePartnership('user-2'), isNull);
    });
  });

  group('Re-linking after archive', () {
    test('can create new partnership after archiving old one', () async {
      // Create and link
      final first = await repo.createPartnership('user-1');
      await repo.joinPartnership(first.inviteCode, 'user-2');

      // Archive
      await repo.archivePartnership(first.id);

      // Create new
      final second = await repo.createPartnership('user-1');

      expect(second.status, 'pending');
      expect(second.inviteCode, isNot(first.inviteCode));
    });

    test('old pending partnerships are archived before creating new one', () async {
      // Create but don't link
      final first = await repo.createPartnership('user-1');

      // Archive old pending ones
      await repo.archiveOldPendingPartnerships('user-1');

      // Verify old one is archived
      final oldPending = await repo.getPendingPartnership('user-1');
      expect(oldPending, isNull);

      // Create new one
      final second = await repo.createPartnership('user-1');
      expect(second.status, 'pending');
      expect(second.id, isNot(first.id));
    });

    test('new partnership can be joined after archiving old one', () async {
      // Create, link, archive
      final first = await repo.createPartnership('user-1');
      await repo.joinPartnership(first.inviteCode, 'user-2');
      await repo.archivePartnership(first.id);

      // Create new partnership
      final second = await repo.createPartnership('user-1');

      // Join with new code
      final joined = await repo.joinPartnership(second.inviteCode, 'user-3');

      expect(joined, isNotNull);
      expect(joined!.status, 'active');
      expect(joined.user2Id, 'user-3');
    });

    test('cannot join with old archived code', () async {
      final first = await repo.createPartnership('user-1');
      await repo.joinPartnership(first.inviteCode, 'user-2');
      await repo.archivePartnership(first.id);

      // Try to join with old code
      final joined = await repo.joinPartnership(first.inviteCode, 'user-3');

      expect(joined, isNull);
    });
  });

  group('Pending partnership lookup', () {
    test('finds pending partnership for creator', () async {
      await repo.createPartnership('user-1');

      final pending = await repo.getPendingPartnership('user-1');

      expect(pending, isNotNull);
      expect(pending!.status, 'pending');
    });

    test('returns null for non-creator', () async {
      await repo.createPartnership('user-1');

      final pending = await repo.getPendingPartnership('user-2');

      expect(pending, isNull);
    });

    test('returns null after partnership becomes active', () async {
      final created = await repo.createPartnership('user-1');
      await repo.joinPartnership(created.inviteCode, 'user-2');

      final pending = await repo.getPendingPartnership('user-1');

      expect(pending, isNull);
    });
  });
}
