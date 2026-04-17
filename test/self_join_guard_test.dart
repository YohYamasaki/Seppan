import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural tests verifying that the QR scanner page prevents
/// a user from pairing with their own partnership (self-join guard).
void main() {
  final file = File('lib/pages/auth/qr_scanner_page.dart');
  late String content;

  setUpAll(() {
    content = file.readAsStringSync();
  });

  group('Self-join guard in QrScannerPage', () {
    test('user1Id check exists', () {
      expect(
        content.contains('user1Id'),
        isTrue,
        reason: 'QrScannerPage must check user1Id to prevent '
            'self-join (pairing with your own partnership).',
      );
    });

    test('guard appears before joinPartnership call', () {
      final guardIdx = content.indexOf('user1Id');
      final joinIdx = content.indexOf('joinPartnership');
      expect(guardIdx, greaterThan(-1));
      expect(
        joinIdx,
        greaterThan(guardIdx),
        reason: 'The self-join guard (user1Id check) must appear '
            'before the joinPartnership call.',
      );
    });

    test('error message about self-join exists', () {
      expect(
        content.contains('自分自身'),
        isTrue,
        reason: 'QrScannerPage must show an error message containing '
            '"自分自身" when a user tries to scan their own QR code.',
      );
    });
  });
}
