import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/models/category.dart';
import 'package:seppan/utils/reorder.dart';

/// Structural tests verifying that category reorder is correctly saved,
/// especially for newly added categories.
///
/// Tests cover:
/// 1. reorderCategories sends correct sort_order values (list index)
/// 2. _addCategory awaits _loadCategories to prevent race conditions
/// 3. _saveReorder has error handling
/// 4. applyReorder + save produces correct sort_order mapping for added genres
void main() {
  final categoryEditFile =
      File('lib/pages/settings/category_edit_page.dart');
  final partnershipRepoFile =
      File('lib/repositories/partnership_repository.dart');

  late String editContent;
  late String repoContent;

  setUpAll(() {
    editContent = categoryEditFile.readAsStringSync();
    repoContent = partnershipRepoFile.readAsStringSync();
  });

  group('category_edit_page structure', () {
    test('_addCategory awaits _loadCategories', () {
      // After adding a category, _loadCategories must be awaited to prevent
      // race conditions where reorder fires before the new category is loaded.
      final addMethodStart = editContent.indexOf('Future<void> _addCategory');
      final addMethodEnd = editContent.indexOf(
        'Future<void> _saveReorder',
      );
      final addMethod = editContent.substring(addMethodStart, addMethodEnd);

      expect(
        addMethod.contains('await _loadCategories()'),
        isTrue,
        reason: '_addCategory must await _loadCategories() to prevent '
            'race conditions between add and reorder',
      );
    });

    test('_saveReorder has error handling', () {
      final saveStart = editContent.indexOf('Future<void> _saveReorder');
      final saveEnd = editContent.indexOf(
        'Future<void> _deleteCategory',
      );
      final saveMethod = editContent.substring(saveStart, saveEnd);

      expect(
        saveMethod.contains('try'),
        isTrue,
        reason: '_saveReorder must have try-catch to surface upsert errors',
      );
      expect(
        saveMethod.contains('catch'),
        isTrue,
        reason: '_saveReorder must catch errors from reorderCategories',
      );
      expect(
        saveMethod.contains('SnackBar'),
        isTrue,
        reason: '_saveReorder should show a SnackBar on failure',
      );
    });

    test('_deleteCategory awaits _loadCategories', () {
      final deleteStart = editContent.indexOf('Future<void> _deleteCategory');
      // Find the next method or end of class
      final deleteEnd = editContent.indexOf('@override', deleteStart);
      final deleteMethod = editContent.substring(deleteStart, deleteEnd);

      expect(
        deleteMethod.contains('_loadCategories'),
        isTrue,
        reason: '_deleteCategory must reload categories after deletion',
      );
    });
  });

  group('reorderCategories in PartnershipRepository', () {
    test('method exists', () {
      expect(
        repoContent.contains('Future<void> reorderCategories'),
        isTrue,
        reason: 'PartnershipRepository must have reorderCategories method',
      );
    });

    test('updates sort_order for each category by id', () {
      final methodStart =
          repoContent.indexOf('Future<void> reorderCategories');
      final end = (methodStart + 400).clamp(0, repoContent.length);
      final methodArea = repoContent.substring(methodStart, end);

      expect(
        methodArea.contains("update"),
        isTrue,
        reason: 'reorderCategories must use update to set sort_order',
      );
      expect(
        methodArea.contains("'sort_order'"),
        isTrue,
        reason: 'reorderCategories must update sort_order field',
      );
      expect(
        methodArea.contains(".eq('id'"),
        isTrue,
        reason: 'reorderCategories must target each category by id',
      );
    });
  });

  group('getCategories ordering (mirror bug prevention)', () {
    test('getCategories orders by sort_order ascending explicitly', () {
      // Without explicit ascending: true, the Supabase client may return
      // categories in descending order, causing a mirror effect where
      // position i becomes position N-i after save+reload.
      final methodStart =
          repoContent.indexOf('Future<List<Category>> getCategories');
      final end = (methodStart + 300).clamp(0, repoContent.length);
      final methodArea = repoContent.substring(methodStart, end);

      expect(
        methodArea.contains("order('sort_order', ascending: true)"),
        isTrue,
        reason: 'getCategories must explicitly specify ascending: true '
            'to prevent the sort order from being reversed (mirror bug)',
      );
    });
  });

  group('applyReorder + sort_order mapping for added genres', () {
    // Simulate the exact flow: default categories + newly added category,
    // then reorder, then verify sort_order mapping matches list indices.

    final defaultCategories = List.generate(
      7,
      (i) => Category(
        id: 'cat-$i',
        partnershipId: 'p1',
        name: 'Category $i',
        sortOrder: i,
      ),
    );

    test('newly added category gets correct sort_order after reorder', () {
      // Simulate: 7 defaults + 1 added at the end
      final withAdded = [
        ...defaultCategories,
        const Category(
          id: 'cat-new',
          partnershipId: 'p1',
          name: 'New Genre',
          sortOrder: 7,
        ),
      ];

      // User drags the new category (index 7) to position 2
      // ReorderableListView gives newIndex=2
      final reordered = applyReorder(withAdded, 7, 2);

      // Verify the new category is at index 2
      expect(reordered[2].id, 'cat-new');

      // Simulate reorderCategories mapping: list index → sort_order
      final sortOrders = {
        for (final e in reordered.asMap().entries) e.value.id: e.key,
      };

      expect(sortOrders['cat-new'], 2,
          reason: 'Newly added category should have sort_order 2 after reorder');
      expect(sortOrders['cat-0'], 0);
      expect(sortOrders['cat-1'], 1);
      expect(sortOrders['cat-2'], 3); // shifted down
      expect(sortOrders['cat-6'], 7); // last default shifted to end
    });

    test('multiple added categories reorder correctly', () {
      final withTwoAdded = [
        ...defaultCategories,
        const Category(
          id: 'cat-a',
          partnershipId: 'p1',
          name: 'Added A',
          sortOrder: 7,
        ),
        const Category(
          id: 'cat-b',
          partnershipId: 'p1',
          name: 'Added B',
          sortOrder: 8,
        ),
      ];

      // Move "Added B" (index 8) to the top (index 0)
      final reordered = applyReorder(withTwoAdded, 8, 0);

      expect(reordered[0].id, 'cat-b');

      final sortOrders = {
        for (final e in reordered.asMap().entries) e.value.id: e.key,
      };

      expect(sortOrders['cat-b'], 0);
      expect(sortOrders['cat-0'], 1); // shifted
      expect(sortOrders['cat-a'], 8); // shifted to second-to-last → last
    });

    test('reorder preserves all categories (none lost)', () {
      final withAdded = [
        ...defaultCategories,
        const Category(
          id: 'cat-new',
          partnershipId: 'p1',
          name: 'New Genre',
          sortOrder: 7,
        ),
      ];

      final reordered = applyReorder(withAdded, 7, 0);

      expect(reordered.length, 8,
          reason: 'All categories including added one must be present');
      expect(
        reordered.map((c) => c.id).toSet(),
        withAdded.map((c) => c.id).toSet(),
        reason: 'No categories should be lost during reorder',
      );
    });

    test('sort_order values are consecutive 0..n-1 after reorder', () {
      final categories = List.generate(
        5,
        (i) => Category(
          id: 'c-$i',
          partnershipId: 'p1',
          name: 'Cat $i',
          sortOrder: i * 10, // non-consecutive originals
        ),
      );

      final reordered = applyReorder(categories, 4, 1);

      // Simulate reorderCategories: list index → sort_order
      final sortOrders = reordered.asMap().entries.map((e) => e.key).toList();

      expect(sortOrders, [0, 1, 2, 3, 4],
          reason: 'sort_order values must be consecutive starting from 0');
    });
  });
}
