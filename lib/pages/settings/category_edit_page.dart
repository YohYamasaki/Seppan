import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/category.dart';
import '../../providers/auth_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../utils/reorder.dart';

class CategoryEditPage extends ConsumerStatefulWidget {
  const CategoryEditPage({super.key});

  @override
  ConsumerState<CategoryEditPage> createState() => _CategoryEditPageState();
}

class _CategoryEditPageState extends ConsumerState<CategoryEditPage> {
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await ref.read(categoriesProvider.future);
    setState(() {
      _categories = List.of(cats);
      _loading = false;
    });
  }

  Future<String?> _resolvePartnershipId() async {
    final active = await ref.read(activePartnershipProvider.future);
    if (active != null) return active.id;

    final user = ref.read(currentUserProvider);
    if (user == null) return null;

    final repo = ref.read(partnershipRepositoryProvider);
    final pending = await repo.getPendingPartnership(user.id);
    if (pending != null) return pending.id;

    await repo.archiveOldPendingPartnerships(user.id);
    final created = await repo.createPartnership(user.id);
    return created.id;
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新しいジャンル'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ジャンル名',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    // Do NOT dispose controller here — the dialog's TextField may still
    // reference it during unmount (focus change → clearComposing).
    // It's a local variable; GC will reclaim it.

    if (name == null || name.isEmpty) return;

    final partnershipId = await _resolvePartnershipId();
    if (partnershipId == null) return;

    await ref.read(partnershipRepositoryProvider).addCategory(
          partnershipId: partnershipId,
          name: name,
          sortOrder: _categories.length,
        );
    ref.invalidate(categoriesProvider);
    _loadCategories();
  }

  Future<void> _saveReorder() async {
    await ref.read(partnershipRepositoryProvider).reorderCategories(_categories);
    ref.invalidate(categoriesProvider);
  }

  Future<void> _deleteCategory(Category category) async {
    await ref.read(partnershipRepositoryProvider).deleteCategory(category.id);
    ref.invalidate(categoriesProvider);
    _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ジャンルの編集'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addCategory,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(child: Text('ジャンルがありません'))
              : ReorderableListView.builder(
                  itemCount: _categories.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      _categories = applyReorder(_categories, oldIndex, newIndex);
                    });
                    _saveReorder();
                  },
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    return Dismissible(
                      key: ValueKey(cat.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child:
                            const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteCategory(cat),
                      child: ListTile(
                        key: ValueKey(cat.id),
                        leading: const Icon(Icons.drag_handle),
                        title: Text(cat.name),
                      ),
                    );
                  },
                ),
    );
  }
}
