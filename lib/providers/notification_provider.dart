import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';

/// Overridden in `main()` with the initialized concrete service, and in tests
/// with a fake.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('notificationServiceProvider must be overridden');
});
