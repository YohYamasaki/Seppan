/// Pure router redirect logic, extracted for testability.
///
/// Returns the redirect path, or null if no redirect needed.
String? routerRedirect({
  required String location,
  required bool isLoggedIn,
  required bool isProfileLoading,
  required bool hasProfile,
  bool needsEncryptionUnlock = false,
  bool isEncryptionCheckLoading = false,
}) {
  final isAuthRoute = location.startsWith('/sign-in') ||
      location.startsWith('/profile-setup') ||
      location.startsWith('/invite');
  final isEncryptionRoute = location.startsWith('/encryption-') ||
      location.startsWith('/fingerprint-');

  // Not logged in
  if (!isLoggedIn) {
    return isAuthRoute || isEncryptionRoute ? null : '/sign-in';
  }

  // Still loading profile — stay on current route until resolved.
  // Redirecting during loading causes screen flashes (e.g. home → profile-setup → home).
  if (isProfileLoading) return null;

  // Logged in but no profile
  if (!hasProfile) {
    return location == '/profile-setup' ? null : '/profile-setup';
  }

  // Encryption check still loading — stay put until resolved.
  // Without this, the profile-loaded router refresh redirects from /sign-in
  // to /home before we know if /encryption-unlock is needed. This is a race
  // condition that manifests during Google OAuth (app resumes from background,
  // partnership query finishes after profile query).
  if (isEncryptionCheckLoading) return null;

  // Encryption key needs password unlock (local cache cleared on sign-out)
  // Skip for encryption/fingerprint routes — these are part of the
  // key exchange flow and must not be interrupted.
  if (needsEncryptionUnlock && !isEncryptionRoute) {
    return '/encryption-unlock';
  }

  // Fully set up — redirect away from auth routes (except /invite)
  if (isAuthRoute && !location.startsWith('/invite')) return '/home';

  return null;
}
