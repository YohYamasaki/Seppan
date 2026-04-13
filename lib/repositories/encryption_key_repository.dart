import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase.dart';

class EncryptionKeyRepository {
  static const _table = 'encryption_keys';

  Future<void> storeWrappedKey({
    required String partnershipId,
    required String userId,
    required String wrappedKey,
    required String salt,
    required String nonce,
  }) async {
    await supabase.from(_table).upsert({
      'partnership_id': partnershipId,
      'user_id': userId,
      'wrapped_key': wrappedKey,
      'key_salt': salt,
      'key_nonce': nonce,
    }, onConflict: 'partnership_id,user_id');
  }

  Future<Map<String, dynamic>?> getWrappedKey(
    String partnershipId,
    String userId,
  ) async {
    try {
      final data = await supabase
          .from(_table)
          .select('wrapped_key, key_salt, key_nonce')
          .eq('partnership_id', partnershipId)
          .eq('user_id', userId)
          .single();
      return data;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        return null;
      }
      rethrow;
    }
  }

  Future<void> deleteWrappedKey(
    String partnershipId,
    String userId,
  ) async {
    await supabase
        .from(_table)
        .delete()
        .eq('partnership_id', partnershipId)
        .eq('user_id', userId);
  }
}
