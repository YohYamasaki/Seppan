import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';

part 'auth_provider.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository();
}

@riverpod
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepository();
}

@riverpod
Stream<AuthState> authStateChanges(Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
}

@riverpod
User? currentUser(Ref ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = ref.read(authRepositoryProvider).currentUser;
  debugPrint('[currentUser] authState=${authState.valueOrNull?.event}, uid=${user?.id}');
  return user;
}

@riverpod
Future<Profile?> currentProfile(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  try {
    return await ref.watch(profileRepositoryProvider).getProfile(user.id);
  } catch (_) {
    return null;
  }
}
