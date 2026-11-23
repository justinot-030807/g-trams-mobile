import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gtrams_mobile/app.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/storage/offline_wallet_cache.dart';
import 'package:gtrams_mobile/core/storage/wizard_draft_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final walletCache = await HiveOfflineWalletCache.init();
  final draftCache = await HiveWizardDraftCache.init();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        offlineWalletCacheProvider.overrideWithValue(walletCache),
        wizardDraftCacheProvider.overrideWithValue(draftCache),
      ],
      child: const GtramsMobileApp(),
    ),
  );
}
