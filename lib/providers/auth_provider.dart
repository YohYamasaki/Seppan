import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';

part 'auth_provider.g.dart';

/// User-facing exception for profile fetch failures.
/// The UI should catch [ProfileFetchException] and display [message]
/// to the user in Japanese.
class ProfileFetchException implements Exception {
  const ProfileFetchException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => 'ProfileFetchException: $message';
}

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

/// Current user's profile.
///
/// Returns `null` if the user has not yet created a profile (row not
/// found). For all other failures — network errors, auth errors,
/// server errors — throws a [ProfileFetchException] with a Japanese
/// message so the UI can display it to the user without mis-identifying
/// the state as "profile not yet created".
@riverpod
Future<Profile?> currentProfile(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  try {
    return await ref.watch(profileRepositoryProvider).getProfile(user.id);
  } on SocketException catch (e) {
    debugPrint('[currentProfile] network error: $e');
    throw ProfileFetchException(
      'ネットワークに接続できませんでした。接続状況を確認して再度お試しください。',
      cause: e,
    );
  } on AuthException catch (e) {
    debugPrint('[currentProfile] auth error: $e');
    throw ProfileFetchException(
      '認証エラーが発生しました。もう一度ログインしてください。',
      cause: e,
    );
  } on PostgrestException catch (e) {
    debugPrint('[currentProfile] postgrest error: $e');
    throw ProfileFetchException(
      'サーバーからプロフィールを取得できませんでした: ${e.message}',
      cause: e,
    );
  } catch (e) {
    debugPrint('[currentProfile] unexpected error: $e');
    throw ProfileFetchException(
      'プロフィールの取得中に予期しないエラーが発生しました。',
      cause: e,
    );
  }
}
