import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';

class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Seppan',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(48),
              _SignInButton(
                label: 'Googleでログイン',
                icon: Image.asset('assets/logos/google.png', height: 24),
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signInWithGoogle();
                },
              ),
              if (!Platform.isAndroid) ...[
                const Gap(16),
                _SignInButton(
                  label: 'Appleでサインイン',
                  icon: Image.asset('assets/logos/apple.png', height: 24),
                  backgroundColor: Colors.black,
                  textColor: Colors.white,
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signInWithApple();
                  },
                ),
              ],
              const Gap(16),
              _SignInButton(
                label: 'メールでログイン',
                icon: const Icon(Icons.mail_outline),
                backgroundColor: Theme.of(context).colorScheme.primary,
                textColor: Colors.white,
                onPressed: () => context.push('/sign-in/email'),
              ),
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
      height: 48,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor ?? Colors.black87,
          side: backgroundColor != null
              ? BorderSide.none
              : const BorderSide(color: Colors.black26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: icon,
        label: Text(label),
        onPressed: onPressed,
      ),
    );
  }
}
