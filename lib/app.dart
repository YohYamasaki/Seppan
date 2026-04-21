import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/router.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';

/// Global scaffold messenger key used to show error snackbars from any
/// screen in response to reactive provider errors (e.g. profile fetch
/// failures). Declared at module scope so provider listeners can
/// display messages without needing a specific BuildContext.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class SeppanApp extends ConsumerWidget {
  const SeppanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(routerProvider);

    // Surface profile fetch failures to the user in Japanese.
    // Other providers could hook in the same way if needed.
    ref.listen(currentProfileProvider, (prev, next) {
      final error = next.error;
      if (error == null) return;
      if (error is ProfileFetchException) {
        rootMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(error.message),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });

    return MaterialApp.router(
      title: 'Seppan',
      debugShowCheckedModeBanner: false,
      theme: seppanLightTheme(),
      routerConfig: goRouter,
      scaffoldMessengerKey: rootMessengerKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja')],
      locale: const Locale('ja'),
    );
  }
}
