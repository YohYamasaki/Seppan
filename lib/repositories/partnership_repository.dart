import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase.dart';
import '../models/category.dart';
import '../models/partnership.dart';

class PartnershipRepository {
  static const _table = 'partnerships';
  static const _categoriesTable = 'categories';

  static const defaultCategoryNames = [
    '食費',
    '日用品',
    '交通費',
    '光熱費',
    '娯楽',
    '医療',
    'その他',
  ];

  Future<Partnership> createPartnership(String userId) async {
    final code = await _generateUniqueInviteCode();
    final data = await _maybeSingle(
      supabase.from(_table).insert({
        'user1_id': userId,
        'invite_code': code,
        'status': 'pending',
      }).select(),
    );
    if (data == null) throw StateError('Failed to create partnership');

    final partnership = Partnership.fromJson(data);

    // Seed default categories
    final categories = defaultCategoryNames.asMap().entries.map((e) => {
          'partnership_id': partnership.id,
          'name': e.value,
          'sort_order': e.key,
        });
    await supabase.from(_categoriesTable).insert(categories.toList());

    return partnership;
  }

  Future<Partnership?> joinPartnership(
    String inviteCode,
    String userId,
  ) async {
    final data = await _maybeSingle(
      supabase
          .from(_table)
          .update({
            'user2_id': userId,
            'status': 'active',
          })
          .eq('invite_code', inviteCode)
          .eq('status', 'pending')
          .select(),
    );
    if (data == null) return null;
    return Partnership.fromJson(data);
  }

  Future<Partnership?> getPendingPartnership(String userId) async {
    final data = await _maybeSingle(
      supabase
          .from(_table)
          .select()
          .eq('user1_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false),
    );
    if (data == null) return null;
    return Partnership.fromJson(data);
  }

  /// Archives any old pending partnerships for the user before creating a new one.
  Future<void> archiveOldPendingPartnerships(String userId) async {
    await supabase
        .from(_table)
        .update({'status': 'archived'})
        .eq('user1_id', userId)
        .eq('status', 'pending');
  }

  Future<Partnership?> getActivePartnership(String userId) async {
    final data = await _maybeSingle(
      supabase
          .from(_table)
          .select()
          .eq('status', 'active')
          .or('user1_id.eq.$userId,user2_id.eq.$userId'),
    );
    if (data == null) return null;
    return Partnership.fromJson(data);
  }

  /// Returns the current partnership (active first, then pending).
  Future<Partnership?> getCurrentPartnership(String userId) async {
    final active = await getActivePartnership(userId);
    if (active != null) return active;
    return getPendingPartnership(userId);
  }

  /// Returns the most recently archived partnership where [userId] was a member.
  Future<Partnership?> getLastArchivedPartnership(String userId) async {
    final data = await _maybeSingle(
      supabase
          .from(_table)
          .select()
          .eq('status', 'archived')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .order('created_at', ascending: false),
    );
    if (data == null) return null;
    return Partnership.fromJson(data);
  }

  /// Detaches the partner from the partnership before account deletion.
  ///
  /// Clears user2_id and archives the partnership. This way the RPC
  /// delete_user_data (which looks up partnerships by user_id) will
  /// only see the deleting user — the partner's expenses are safe.
  ///
  /// - If the deleting user is user1: clear user2_id so the RPC won't
  ///   cascade-delete the partner's data via user2_id lookup.
  /// - If the deleting user is user2: clear user2_id (removes self).
  ///   The RPC won't find this partnership via user2_id anymore.
  ///
  /// We never change user1_id — that would violate RLS (the current
  /// user would be removed from the row mid-update).
  Future<void> detachUserFromPartnership(
    String partnershipId,
    String userId,
  ) async {
    await supabase.from(_table).update({
      'user2_id': null,
      'status': 'archived',
    }).eq('id', partnershipId);
  }

  Stream<Partnership> watchPartnership(String partnershipId) {
    return supabase
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('id', partnershipId)
        .map((rows) => Partnership.fromJson(rows.first));
  }

  Future<void> archivePartnership(String partnershipId) async {
    await supabase
        .from(_table)
        .update({'status': 'archived'})
        .eq('id', partnershipId);
  }

  // Categories

  Future<List<Category>> getCategories(String partnershipId) async {
    final data = await supabase
        .from(_categoriesTable)
        .select()
        .eq('partnership_id', partnershipId)
        .order('sort_order', ascending: true);
    return data.map((e) => Category.fromJson(e)).toList();
  }

  Future<void> addCategory({
    required String partnershipId,
    required String name,
    required int sortOrder,
  }) async {
    await supabase.from(_categoriesTable).insert({
      'partnership_id': partnershipId,
      'name': name,
      'sort_order': sortOrder,
    });
  }

  Future<void> reorderCategories(List<Category> categories) async {
    await Future.wait([
      for (var i = 0; i < categories.length; i++)
        supabase
            .from(_categoriesTable)
            .update({'sort_order': i})
            .eq('id', categories[i].id),
    ]);
  }

  Future<void> upsertCategory(Category category) async {
    await supabase.from(_categoriesTable).upsert(category.toJson());
  }

  Future<void> deleteCategory(String categoryId) async {
    await supabase.from(_categoriesTable).delete().eq('id', categoryId);
  }

  // Helpers

  /// PGRST116 safe version of maybeSingle
  Future<Map<String, dynamic>?> _maybeSingle(
    PostgrestBuilder query,
  ) async {
    try {
      final response = await query;
      if (response is List) {
        if (response.isEmpty) return null;
        return response.first as Map<String, dynamic>;
      }
      if (response is Map<String, dynamic>) return response;
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '406' || e.message.contains('PGRST116')) {
        return null;
      }
      rethrow;
    }
  }

  Future<String> _generateUniqueInviteCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    for (var attempt = 0; attempt < 10; attempt++) {
      final code = List.generate(
        6,
        (_) => chars[random.nextInt(chars.length)],
      ).join();

      final existing = await _maybeSingle(
        supabase.from(_table).select('id').eq('invite_code', code),
      );
      if (existing == null) return code;
    }
    throw StateError('Failed to generate unique invite code');
  }
}
