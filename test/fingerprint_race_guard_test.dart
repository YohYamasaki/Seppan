import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural tests verifying that the fingerprint verification page
/// guards against race conditions in _handleJoinerUpdate by using
/// a _handlingUpdate flag.
void main() {
  final file = File('lib/pages/auth/fingerprint_verification_page.dart');
  late String content;

  setUpAll(() {
    content = file.readAsStringSync();
  });

  group('Race guard in FingerprintVerificationPage._handleJoinerUpdate', () {
    test('_handlingUpdate field is declared', () {
      expect(
        content.contains('_handlingUpdate'),
        isTrue,
        reason: 'FingerprintVerificationPage must declare a '
            '_handlingUpdate field to guard against race conditions.',
      );
    });

    test('_handlingUpdate check exists at the start of _handleJoinerUpdate',
        () {
      final methodIdx = content.indexOf('_handleJoinerUpdate');
      expect(methodIdx, greaterThan(-1));

      // Find the check within _handleJoinerUpdate
      final checkIdx =
          content.indexOf('if (_handlingUpdate) return', methodIdx);
      expect(
        checkIdx,
        greaterThan(methodIdx),
        reason: '_handleJoinerUpdate must check _handlingUpdate at '
            'the start and return early if already handling.',
      );
    });

    test('_handlingUpdate = true is set after the check', () {
      final checkIdx = content.indexOf('if (_handlingUpdate) return');
      expect(checkIdx, greaterThan(-1));

      final setIdx = content.indexOf('_handlingUpdate = true', checkIdx);
      expect(
        setIdx,
        greaterThan(checkIdx),
        reason: '_handlingUpdate must be set to true after the early '
            'return check to prevent concurrent execution.',
      );
    });
  });
}
