import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase.dart';
import '../models/profile.dart';

class ProfileRepository {
  static const _table = 'profiles';

  Future<Profile?> getProfile(String userId) async {
    final data = await _maybeSingle(
      supabase.from(_table).select().eq('id', userId),
    );
    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<void> upsertProfile(Profile profile) async {
    await supabase.from(_table).upsert(profile.toJson());
  }

  Future<void> updateProfile({
    required String userId,
    String? displayName,
    int? iconId,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (displayName != null) updates['display_name'] = displayName;
    if (iconId != null) updates['icon_id'] = iconId;

    await supabase.from(_table).update(updates).eq('id', userId);
  }

  Future<void> deleteProfile(String userId) async {
    await supabase.from(_table).delete().eq('id', userId);
  }

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
}
