import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/supabase.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Explicitly deny all ad-related consent. Seppan does not use advertising,
  // and this tells Firebase Analytics not to collect advertising-related
  // data (AD_ID, attribution, personalization signals).
  await FirebaseAnalytics.instance.setConsent(
    adStorageConsentGranted: false,
    adPersonalizationSignalsConsentGranted: false,
    adUserDataConsentGranted: false,
    analyticsStorageConsentGranted: true, // keep basic analytics
  );

  await initSupabase();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const ProviderScope(child: SeppanApp()));
}
