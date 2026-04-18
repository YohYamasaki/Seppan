import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gap/gap.dart';

/// Widget test for the amount-input bottom sheet pattern.
///
/// Regression test for a `_dependents.isEmpty` assertion that occurred
/// when a TextEditingController was disposed synchronously after
/// `showModalBottomSheet` completed — the TextField inside the sheet
/// still held listeners during the closing animation, and disposing
/// the controller while listeners were still attached crashed.
///
/// The fix: move the controller into a StatefulWidget so its
/// lifecycle is managed by the framework and it is disposed only
/// after the widget unmounts (i.e. after the animation completes).
void main() {
  group('_AmountInputSheet pattern', () {
    testWidgets(
      'entering amount and tapping confirm closes sheet without crash',
      (tester) async {
        int? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    result = await showModalBottomSheet<int>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const _TestAmountSheet(
                        total: 1000,
                        initialMyBurden: 500,
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Sheet should be visible
        expect(find.text('合計 ¥1,000'), findsOneWidget);

        // Enter amount
        await tester.enterText(find.byType(TextField), '300');
        await tester.pump();

        // Partner burden should be auto-calculated
        expect(find.text('¥700'), findsOneWidget);

        // Tap confirm
        await tester.tap(find.text('確定'));
        await tester.pumpAndSettle();

        // Sheet should close without crash, result returned
        expect(result, 300);
      },
    );

    testWidgets('invalid amount disables confirm button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showModalBottomSheet<int>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const _TestAmountSheet(
                      total: 1000,
                      initialMyBurden: 500,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Enter amount greater than total
      await tester.enterText(find.byType(TextField), '2000');
      await tester.pump();

      // Confirm button should be disabled
      final confirmButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '確定'),
      );
      expect(confirmButton.onPressed, isNull);

      // Error text should be shown
      expect(find.textContaining('範囲で入力'), findsOneWidget);
    });

    testWidgets('dismissing sheet without confirm disposes cleanly',
        (tester) async {
      // Regression test: ensure the controller dispose via framework
      // lifecycle works correctly even when the sheet is dismissed
      // without confirming (e.g. by tapping outside).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showModalBottomSheet<int>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const _TestAmountSheet(
                      total: 1000,
                      initialMyBurden: 500,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Dismiss by tapping on the barrier
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // No crash, no residual widgets
      expect(find.byType(TextField), findsNothing);
    });
  });
}

/// Test-only copy of the sheet pattern from expense_input_page.dart.
/// Duplicated here to test in isolation without the full app context.
class _TestAmountSheet extends StatefulWidget {
  const _TestAmountSheet({
    required this.total,
    required this.initialMyBurden,
  });

  final int total;
  final int initialMyBurden;

  @override
  State<_TestAmountSheet> createState() => _TestAmountSheetState();
}

class _TestAmountSheetState extends State<_TestAmountSheet> {
  late final TextEditingController _controller;
  int _myBurden = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initialMyBurden.toString());
    _myBurden = widget.initialMyBurden;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _myBurden >= 0 && _myBurden <= widget.total;
    final partnerBurden = isValid ? widget.total - _myBurden : 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('合計 ¥${widget.total.toString().replaceAllMapped(
                RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                (m) => '${m[1]},',
              )}'),
          const Gap(20),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() {
              _myBurden = int.tryParse(v.replaceAll(',', '')) ?? 0;
            }),
            decoration: InputDecoration(
              errorText: !isValid ? '0〜¥${widget.total} の範囲で入力してください' : null,
            ),
          ),
          const Gap(16),
          Text(
            isValid
                ? '¥${partnerBurden.toString().replaceAllMapped(
                      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                      (m) => '${m[1]},',
                    )}'
                : '-',
          ),
          const Gap(24),
          FilledButton(
            onPressed: isValid
                ? () => Navigator.pop(context, _myBurden)
                : null,
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }
}
