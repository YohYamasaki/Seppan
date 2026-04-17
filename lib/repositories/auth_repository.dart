import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase.dart';

const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

class AuthRepository {
  /// Returns `true` if sign-in succeeded, `false` if user cancelled.
  Future<bool> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(serverClientId: _googleWebClientId);
    await googleSignIn.signOut(); // 前回の選択をクリアしてアカウント選択を毎回表示
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return false; // ユーザーがキャンセル

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null) throw StateError('No ID token received');

    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    return true;
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
