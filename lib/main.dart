import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'providers/profile_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final hasProfile = await ProfileNotifier.hasProfile();

  runApp(
    ProviderScope(
      child: PauseApp(hasProfile: hasProfile),
    ),
  );
}
