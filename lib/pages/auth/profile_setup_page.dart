import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/avatar_icon.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _selectedIconId = 1;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      await ref.read(profileRepositoryProvider).upsertProfile(
            Profile(
              id: user.id,
              displayName: _nameController.text.trim(),
              iconId: _selectedIconId,
              createdAt: now,
              updatedAt: now,
            ),
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) context.go('/invite');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール設定')),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: AvatarIcon(iconId: _selectedIconId, radius: 48),
              ),
              const Gap(24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名前',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '名前を入力してください';
                  }
                  return null;
                },
              ),
              const Gap(24),
              const Text('アイコンを選択',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Gap(8),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final iconId = index + 1;
                    final isSelected = iconId == _selectedIconId;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIconId = iconId),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: AvatarIcon(iconId: iconId, radius: 30),
                      ),
                    );
                  },
                ),
              ),
              const Gap(16),
              ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('次へ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
