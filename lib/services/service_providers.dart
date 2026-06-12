import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notifications/notification_service.dart';
import 'storage/storage_service.dart';

/// Riverpod handles to Vyra's app-wide singleton services. Both are initialized
/// in `main()` before the app runs, so these providers just expose the ready
/// instances for dependency injection and easy testing/overriding.
final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService.instance,
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService.instance,
);
