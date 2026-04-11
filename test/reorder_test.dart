import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/utils/reorder.dart';

void main() {
  group('applyReorder', () {
    test('move item forward (0 → 2)', () {
      // ReorderableListView convention: newIndex=2 means "insert before index 2
      // in the original list", which after removal becomes index 1.
      final result = applyReorder(['A', 'B', 'C'], 0, 2);
      expect(result, ['B', 'A', 'C']);
    });

    test('move item forward to end (0 → 3)', () {
      final result = applyReorder(['A', 'B', 'C'], 0, 3);
      expect(result, ['B', 'C', 'A']);
    });

    test('move item backward (2 → 0)', () {
      final result = applyReorder(['A', 'B', 'C'], 2, 0);
      expect(result, ['C', 'A', 'B']);
    });

    test('move item backward (2 → 1)', () {
      final result = applyReorder(['A', 'B', 'C'], 2, 1);
      expect(result, ['A', 'C', 'B']);
    });

    test('move to same position is no-op', () {
      final result = applyReorder(['A', 'B', 'C'], 1, 1);
      expect(result, ['A', 'B', 'C']);
    });

    test('adjacent swap forward (1 → 2) is no-op per convention', () {
      // newIndex=2 when oldIndex=1: after adjustment newIndex becomes 1,
      // so the item stays in place. This matches ReorderableListView behavior.
      final result = applyReorder(['A', 'B', 'C'], 1, 2);
      expect(result, ['A', 'B', 'C']);
    });

    test('adjacent swap forward (0 → 1) is no-op per convention', () {
      final result = applyReorder(['A', 'B', 'C'], 0, 1);
      expect(result, ['A', 'B', 'C']);
    });

    test('single item list', () {
      final result = applyReorder(['A'], 0, 0);
      expect(result, ['A']);
    });

    test('two items swap (1 → 0)', () {
      final result = applyReorder(['A', 'B'], 1, 0);
      expect(result, ['B', 'A']);
    });

    test('does not mutate original list', () {
      final original = ['A', 'B', 'C'];
      applyReorder(original, 0, 3);
      expect(original, ['A', 'B', 'C']);
    });

    test('five items - move middle to end', () {
      final result = applyReorder(['A', 'B', 'C', 'D', 'E'], 2, 5);
      expect(result, ['A', 'B', 'D', 'E', 'C']);
    });

    test('five items - move last to first', () {
      final result = applyReorder(['A', 'B', 'C', 'D', 'E'], 4, 0);
      expect(result, ['E', 'A', 'B', 'C', 'D']);
    });
  });
}
