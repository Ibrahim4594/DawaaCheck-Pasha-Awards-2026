import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/app_notification.dart';
import 'auth_provider.dart';

/// Whether push notifications are enabled (persisted in SharedPreferences)
final notificationsEnabledProvider =
    StateNotifierProvider<NotificationsNotifier, AsyncValue<bool>>((ref) {
  final notifier = NotificationsNotifier();
  notifier._load();
  return notifier;
});

class NotificationsNotifier extends StateNotifier<AsyncValue<bool>> {
  NotificationsNotifier() : super(const AsyncValue.loading());

  final _service = NotificationService();

  Future<void> _load() async {
    final enabled = await _service.isEnabled();
    state = AsyncValue.data(enabled);
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? true;
    final newValue = !current;
    state = AsyncValue.data(newValue);
    await _service.setEnabled(newValue);
  }
}

/// Stores FCM token whenever user auth state changes
final fcmTokenSyncProvider = Provider<void>((ref) {
  ref.listen(authStateProvider, (prev, next) {
    final user = next.valueOrNull;
    if (user != null) {
      NotificationService().storeTokenForUser(user.uid);
    }
  });
});

/// Notification history — list of all past notifications
final notificationHistoryProvider =
    StateNotifierProvider<NotificationHistoryNotifier, AsyncValue<List<AppNotification>>>((ref) {
  final notifier = NotificationHistoryNotifier();
  notifier.load();
  return notifier;
});

class NotificationHistoryNotifier
    extends StateNotifier<AsyncValue<List<AppNotification>>> {
  NotificationHistoryNotifier() : super(const AsyncValue.loading());

  final _service = NotificationService();

  Future<void> load() async {
    final history = await _service.getHistory();
    state = AsyncValue.data(history);
  }

  Future<void> markAllRead() async {
    await _service.markAllRead();
    await load();
  }

  Future<void> markRead(String id) async {
    await _service.markRead(id);
    await load();
  }

  Future<void> clearAll() async {
    await _service.clearHistory();
    state = const AsyncValue.data([]);
  }

  Future<void> refresh() async => load();
}

/// Unread notification count
final unreadNotificationCountProvider = Provider<int>((ref) {
  final history = ref.watch(notificationHistoryProvider);
  return history.when(
    data: (list) => list.where((n) => !n.isRead).length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});
