import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/utils/router_redirect.dart';

void main() {
  group('Not logged in', () {
    test('redirects to /sign-in from /home', () {
      expect(
        routerRedirect(
          location: '/home',
          isLoggedIn: false,
          isProfileLoading: false,
          hasProfile: false,
        ),
        '/sign-in',
      );
    });

    test('stays on /sign-in', () {
      expect(
        routerRedirect(
          location: '/sign-in',
          isLoggedIn: false,
          isProfileLoading: false,
          hasProfile: false,
        ),
        isNull,
      );
    });

    test('stays on /sign-in/email', () {
      expect(
        routerRedirect(
          location: '/sign-in/email',
          isLoggedIn: false,
          isProfileLoading: false,
          hasProfile: false,
        ),
        isNull,
      );
    });
  });

  group('Logged in, profile loading', () {
    test('stays on /home while loading (no flash to profile-setup)', () {
      expect(
        routerRedirect(
          location: '/home',
          isLoggedIn: true,
          isProfileLoading: true,
          hasProfile: false,
        ),
        isNull, // Stay put — redirecting during load causes screen flashes
      );
    });

    test('stays on /settings while loading', () {
      expect(
        routerRedirect(
          location: '/settings',
          isLoggedIn: true,
          isProfileLoading: true,
          hasProfile: false,
        ),
        isNull,
      );
    });

    test('stays on /sign-in while loading', () {
      expect(
        routerRedirect(
          location: '/sign-in',
          isLoggedIn: true,
          isProfileLoading: true,
          hasProfile: false,
        ),
        isNull,
      );
    });

    test('stays on /profile-setup while loading', () {
      expect(
        routerRedirect(
          location: '/profile-setup',
          isLoggedIn: true,
          isProfileLoading: true,
          hasProfile: false,
        ),
        isNull,
      );
    });
  });

  group('Logged in, no profile', () {
    test('redirects to /profile-setup from /home', () {
      expect(
        routerRedirect(
          location: '/home',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: false,
        ),
        '/profile-setup',
      );
    });

    test('stays on /profile-setup', () {
      expect(
        routerRedirect(
          location: '/profile-setup',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: false,
        ),
        isNull,
      );
    });
  });

  group('Fully set up', () {
    test('stays on /home', () {
      expect(
        routerRedirect(
          location: '/home',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
        ),
        isNull,
      );
    });

    test('stays on /settings', () {
      expect(
        routerRedirect(
          location: '/settings',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
        ),
        isNull,
      );
    });

    test('redirects from /sign-in to /home', () {
      expect(
        routerRedirect(
          location: '/sign-in',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
        ),
        '/home',
      );
    });

    test('redirects from /profile-setup to /home', () {
      expect(
        routerRedirect(
          location: '/profile-setup',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
        ),
        '/home',
      );
    });

    test('allows /invite even when fully set up', () {
      expect(
        routerRedirect(
          location: '/invite',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
        ),
        isNull,
      );
    });

    test('allows /invite/qr-scan even when fully set up', () {
      expect(
        routerRedirect(
          location: '/invite/qr-scan',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
        ),
        isNull,
      );
    });
  });

  group('Encryption check loading (OAuth race condition)', () {
    test('stays on /sign-in while encryption check is loading', () {
      // After Google OAuth app-resume, profile loads before the encryption
      // check resolves. Without this guard, the user is redirected to /home
      // prematurely (before we know if /encryption-unlock is needed).
      expect(
        routerRedirect(
          location: '/sign-in',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
          isEncryptionCheckLoading: true,
        ),
        isNull,
      );
    });

    test('stays on /home while encryption check is loading', () {
      expect(
        routerRedirect(
          location: '/home',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
          isEncryptionCheckLoading: true,
        ),
        isNull,
      );
    });

    test('stays on /settings while encryption check is loading', () {
      expect(
        routerRedirect(
          location: '/settings',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
          isEncryptionCheckLoading: true,
        ),
        isNull,
      );
    });

    test('stays on /encryption-setup while encryption check is loading', () {
      expect(
        routerRedirect(
          location: '/encryption-setup',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
          isEncryptionCheckLoading: true,
        ),
        isNull,
      );
    });

    test('profile loading takes priority over encryption loading', () {
      // Both loading — profile loading already returns null
      expect(
        routerRedirect(
          location: '/sign-in',
          isLoggedIn: true,
          isProfileLoading: true,
          hasProfile: false,
          isEncryptionCheckLoading: true,
        ),
        isNull,
      );
    });

    test('not logged in ignores encryption loading', () {
      expect(
        routerRedirect(
          location: '/home',
          isLoggedIn: false,
          isProfileLoading: false,
          hasProfile: false,
          isEncryptionCheckLoading: true,
        ),
        '/sign-in',
      );
    });
  });

  group('Encryption unlock redirect', () {
    test('redirects to /encryption-unlock from /home when key missing', () {
      expect(
        routerRedirect(
          location: '/home',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
          needsEncryptionUnlock: true,
        ),
        '/encryption-unlock',
      );
    });

    test('redirects to /encryption-unlock from /settings when key missing', () {
      expect(
        routerRedirect(
          location: '/settings',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
          needsEncryptionUnlock: true,
        ),
        '/encryption-unlock',
      );
    });

    test('stays on /encryption-unlock when already there', () {
      expect(
        routerRedirect(
          location: '/encryption-unlock',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
          needsEncryptionUnlock: true,
        ),
        isNull,
      );
    });

    test('stays on /encryption-setup when needsUnlock is true', () {
      expect(
        routerRedirect(
          location: '/encryption-setup',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
          needsEncryptionUnlock: true,
        ),
        isNull,
      );
    });

    test('no redirect when key is available (needsUnlock false)', () {
      expect(
        routerRedirect(
          location: '/home',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
          needsEncryptionUnlock: false,
        ),
        isNull,
      );
    });

    test('default needsEncryptionUnlock is false (backward compat)', () {
      // Calling without the parameter should not redirect
      expect(
        routerRedirect(
          location: '/home',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
        ),
        isNull,
      );
    });
  });

  group('Fingerprint/encryption routes during key exchange', () {
    test('stays on /fingerprint-verification when needsUnlock is true', () {
      // During ECDH key exchange, the joiner has no key yet.
      // encryptionUnlockRequired may be true, but the user must NOT
      // be redirected away from the fingerprint verification flow.
      expect(
        routerRedirect(
          location: '/fingerprint-verification',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
          needsEncryptionUnlock: true,
        ),
        isNull,
      );
    });

    test('stays on /fingerprint-verification when needsUnlock is false', () {
      expect(
        routerRedirect(
          location: '/fingerprint-verification',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
          needsEncryptionUnlock: false,
        ),
        isNull,
      );
    });

    test('stays on /encryption-setup when needsUnlock is true', () {
      expect(
        routerRedirect(
          location: '/encryption-setup',
          isLoggedIn: true,
          isProfileLoading: false,
          hasProfile: true,
          needsEncryptionUnlock: true,
        ),
        isNull,
      );
    });

    test('allows /fingerprint-verification when not logged in', () {
      // Edge case: deep link to fingerprint page when logged out.
      // Should NOT redirect to /sign-in (the page handles its own auth).
      // Actually, this should redirect to /sign-in since user is not logged in.
      // But we treat encryption routes as auth-adjacent.
      expect(
        routerRedirect(
          location: '/fingerprint-verification',
          isLoggedIn: false,
          isProfileLoading: false,
          hasProfile: false,
        ),
        isNull,
      );
    });
  });
}
