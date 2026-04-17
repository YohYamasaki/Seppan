import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  bool _signingIn = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _signingIn = true);
    try {
      final success = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (!success && mounted) {
        // ユーザーがキャンセルした場合はスピナーを解除
        setState(() => _signingIn = false);
      }
      // 成功時は意図的にリセットしない。
      // ルーター遷移までスピナーを表示し続ける。
    } catch (e) {
      if (mounted) {
        setState(() => _signingIn = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('認証に失敗しました: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    // Signing in — show centered icon + spinner (like loading page)
    if (_signingIn) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/icon.png'),
                ),
              ),
              const Gap(24),
              Text(
                'Seppan',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 32,
                  letterSpacing: -0.5,
                ),
              ),
              const Gap(32),
              const CircularProgressIndicator(),
              const Gap(12),
              const Text('ログイン中...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // App icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/icon.png'),
                ),
              ),
              const Gap(24),

              // App name
              Text(
                'Seppan',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 32,
                  letterSpacing: -0.5,
                ),
              ),
              const Gap(8),
              Text(
                'ふたりの支出をシンプルに',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const Spacer(flex: 3),

              // Section label
              Text('ログイン / 新規登録', style: theme.textTheme.bodySmall),
              const Gap(16),
              _SignInButton(
                label: 'Googleで続ける',
                icon: Image.asset('assets/logos/google.png', height: 20),
                backgroundColor: colorScheme.surfaceContainerHigh,
                textColor: colorScheme.onSurface,
                onPressed: _signInWithGoogle,
              ),
              const Gap(12),
              _SignInButton(
                label: 'メールで続ける',
                icon: Icon(
                  Icons.mail_outline,
                  size: 20,
                  color: colorScheme.onSurface,
                ),
                backgroundColor: colorScheme.surfaceContainerHigh,
                textColor: colorScheme.onSurface,
                onPressed: () => context.push('/sign-in/email'),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const Gap(12),
            Text(label, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
