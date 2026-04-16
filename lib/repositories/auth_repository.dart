import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase.dart';

class AuthRepository {
  Future<bool> signInWithGoogle() async {
    return supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.seppan://login-callback/',
      authScreenLaunchMode: LaunchMode.inAppBrowserView,
      queryParams: {'prompt': 'select_account'},
    );
  }

  Future<bool> signInWithApple() async {
    if (!Platform.isIOS) {
      throw UnsupportedError('Apple sign-in is only supported on iOS');
    }
    return supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.seppan://login-callback/',
    );
  }

  Future<void> signInWithEmail(String email) async {
    await supabase.auth.signInWithOtp(email: email);
  }

  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    return supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  /// Deletes all user data then signs out.
  ///
  /// Uses the server-side `delete_user_data` RPC (SECURITY DEFINER)
  /// to bypass RLS and cleanly remove all data in FK-safe order:
  ///   expenses → categories → partnerships → profiles
  Future<void> deleteAccount() async {
    final userId = currentUser?.id;
    if (userId == null) throw StateError('Not logged in');

    await supabase.rpc(
      'delete_user_data',
      params: {'target_user_id': userId},
    );

    await supabase.auth.signOut();
  }

  Stream<AuthState> get authStateChanges =>
      supabase.auth.onAuthStateChange;

  User? get currentUser => supabase.auth.currentUser;
}
