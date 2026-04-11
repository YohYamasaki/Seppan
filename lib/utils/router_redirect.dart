/// Pure router redirect logic, extracted for testability.
///
/// Returns the redirect path, or null if no redirect needed.
String? routerRedirect({
  required String location,
  required bool isLoggedIn,
  required bool isProfileLoading,
  required bool hasProfile,
}) {
  final isAuthRoute = location.startsWith('/sign-in') ||
      location.startsWith('/profile-setup') ||
      location.startsWith('/invite');

  // Not logged in
  if (!isLoggedIn) {
    return isAuthRoute ? null : '/sign-in';
  }

  // Still loading profile — don't redirect yet
  if (isProfileLoading) return null;

  // Logged in but no profile
  if (!hasProfile) {
    return location == '/profile-setup' ? null : '/profile-setup';
  }

  // Fully set up — redirect away from auth routes (except /invite)
  if (isAuthRoute && !location.startsWith('/invite')) return '/home';

  return null;
}
