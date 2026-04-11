/// Applies a ReorderableListView reorder operation to a list.
/// Returns a new list with the item moved from [oldIndex] to [newIndex].
///
/// [newIndex] follows Flutter's ReorderableListView convention:
/// it is the index in the original list before the item is removed.
List<T> applyReorder<T>(List<T> items, int oldIndex, int newIndex) {
  final result = List<T>.of(items);
  if (newIndex > oldIndex) newIndex--;
  final item = result.removeAt(oldIndex);
  result.insert(newIndex, item);
  return result;
}
