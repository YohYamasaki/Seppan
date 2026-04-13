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
}
