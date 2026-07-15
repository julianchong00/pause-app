import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'providers/notification_provider.dart';
import 'providers/profile_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final notificationService = FlutterLocalNotificationService();
  await notificationService.init();

  final hasProfile = await ProfileNotifier.hasProfile();
  final initialEvaluation = await notificationService.initialEvaluation();

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: PauseApp(
        hasProfile: hasProfile,
        initialEvaluation: initialEvaluation,
      ),
    ),
  );
}
