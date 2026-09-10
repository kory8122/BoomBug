import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:boombug/Screen/splashscreen.dart';
import 'package:boombug/notification_service.dart';
import 'package:boombug/progress_store.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await MobileAds.instance.initialize();
  }
  try {
    await NotificationService.instance.initialize();
  } catch (_) {
    // Notifications are optional; they must not prevent the game from starting.
  }
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.instance.cancelDailyMissYouNotification();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      NotificationService.instance.scheduleDailyMissYouNotification(
        ProgressStore.instance.level,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BoomBug',
      theme: theme,
      home: const SplashScreen(),
    );
  }
}
