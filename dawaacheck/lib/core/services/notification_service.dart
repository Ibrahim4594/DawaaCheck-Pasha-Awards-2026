import 'dart:math';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/remote/supabase_service.dart';
import '../../data/models/app_notification.dart';

/// Top-level background message handler — must be outside any class.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

/// Singleton push notification service for DawaaCheck.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _prefKey = 'notifications_enabled';
  static const _historyKey = 'notification_history';
  static const _lastTipKey = 'last_safety_tip_date';
  static const _maxHistory = 50;

  String? _token;
  String? get token => _token;

  bool _initialized = false;

  /// Callback for in-app overlay banner — set by the app shell
  void Function(AppNotification notification)? onForegroundNotification;

  // ─────────────────────────────────────────────────────────────────────────
  // Safety tips pool
  // ─────────────────────────────────────────────────────────────────────────

  static const _safetyTips = [
    'Always check the DRAP registration number on medicine packaging before use.',
    'Buy medicines only from licensed pharmacies — avoid street vendors and unverified online stores.',
    'Check expiry dates before taking any medicine. Expired drugs can be harmful.',
    'Report suspicious medicines to DRAP helpline: 0800-02345. Your report saves lives.',
    'Store medicines in a cool, dry place away from direct sunlight.',
    'Never share prescription medicines — what works for you may harm someone else.',
    'Keep medicines out of reach of children. Use child-proof containers.',
    'If a medicine looks different than usual (color, shape, taste), do NOT take it — scan it first.',
    'Always complete the full course of antibiotics, even if you feel better.',
    'Counterfeit medicines kill over 1 million people globally each year. Stay vigilant.',
    'Check if the medicine box seal is intact before purchase.',
    'Generic medicines are just as effective as branded ones — verify them with DawaaCheck.',
    'Never crush or split tablets unless your doctor says it\'s safe.',
    'Pakistan\'s DRAP has recalled over 160 medicines. Stay updated with DawaaCheck.',
    'If you experience side effects, report them through DawaaCheck\'s ADR feature.',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      debugPrint('[FCM] Notification permission denied');
      return;
    }

    await _initLocalNotifications();

    try {
      _token = await _fcm.getToken();
      debugPrint('[FCM] Token: $_token');
    } catch (e) {
      debugPrint('[FCM] Token error: $e');
    }

    _fcm.onTokenRefresh.listen((newToken) {
      _token = newToken;
      debugPrint('[FCM] Token refreshed: $newToken');
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

    final initial = await _fcm.getInitialMessage();
    if (initial != null) _onNotificationTap(initial);

    await subscribeToTopic('all_users');
    await subscribeToTopic('recall_alerts');

    // Schedule daily safety tip if not already sent today
    await _maybeShowDailySafetyTip();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local notification setup
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    // Scan results channel
    const scanChannel = AndroidNotificationChannel(
      'dawaacheck_scans',
      'Scan Results',
      description: 'Medicine scan verification results',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Recall alerts channel
    const recallChannel = AndroidNotificationChannel(
      'dawaacheck_recalls',
      'Recall Alerts',
      description: 'Urgent medicine recall notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // Safety tips channel
    const tipsChannel = AndroidNotificationChannel(
      'dawaacheck_tips',
      'Safety Tips',
      description: 'Daily medicine safety tips',
      importance: Importance.defaultImportance,
      playSound: false,
    );

    // General channel
    const generalChannel = AndroidNotificationChannel(
      'dawaacheck_general',
      'General',
      description: 'Welcome messages, reminders, and updates',
      importance: Importance.high,
      playSound: true,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        debugPrint('[Notification] Tapped: ${response.payload}');
      },
    );

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(scanChannel);
    await androidPlugin?.createNotificationChannel(recallChannel);
    await androidPlugin?.createNotificationChannel(tipsChannel);
    await androidPlugin?.createNotificationChannel(generalChannel);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Notification details per type
  // ─────────────────────────────────────────────────────────────────────────

  NotificationDetails _detailsForType(NotificationType type) {
    switch (type) {
      case NotificationType.scanVerified:
      case NotificationType.scanDanger:
      case NotificationType.scanUnverified:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'dawaacheck_scans',
            'Scan Results',
            channelDescription: 'Medicine scan verification results',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF1A6FE8),
            groupKey: 'dawaacheck_scans',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        );
      case NotificationType.recallAlert:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'dawaacheck_recalls',
            'Recall Alerts',
            channelDescription: 'Urgent medicine recall notifications',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFFDC2626),
            groupKey: 'dawaacheck_recalls',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        );
      case NotificationType.safetyTip:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'dawaacheck_tips',
            'Safety Tips',
            channelDescription: 'Daily medicine safety tips',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF1A6FE8),
            groupKey: 'dawaacheck_tips',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: false,
          ),
        );
      case NotificationType.welcome:
      case NotificationType.scanReminder:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            'dawaacheck_general',
            'General',
            channelDescription: 'Welcome messages, reminders, and updates',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF1A6FE8),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Core: show + store notification
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showAndStore({
    required String title,
    required String body,
    required NotificationType type,
    String? route,
    bool showSystemNotification = true,
  }) async {
    if (kIsWeb) return;
    final enabled = await isEnabled();
    if (!enabled) return;

    final notification = AppNotification(
      id: '${type.name}_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
      route: route,
    );

    // Store in history
    await _addToHistory(notification);

    // Show system notification
    if (showSystemNotification && _initialized) {
      await _local.show(
        notification.hashCode,
        title,
        body,
        _detailsForType(type),
        payload: route,
      );
    }

    // Trigger in-app overlay banner
    onForegroundNotification?.call(notification);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Foreground FCM message → show as local + store
  // ─────────────────────────────────────────────────────────────────────────

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _showAndStore(
      title: notification.title ?? 'DawaaCheck',
      body: notification.body ?? '',
      type: NotificationType.recallAlert,
      route: message.data['route'],
    );
  }

  void _onNotificationTap(RemoteMessage message) {
    final route = message.data['route'];
    debugPrint('[FCM] Notification tapped, route: $route');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // History storage (SharedPreferences)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _addToHistory(AppNotification notification) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    history.insert(0, notification);
    // Keep only the latest N
    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }
    await prefs.setString(_historyKey, AppNotification.listToJson(history));
  }

  Future<List<AppNotification>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return AppNotification.listFromJson(raw);
    } catch (_) {
      return [];
    }
  }

  Future<int> getUnreadCount() async {
    final history = await getHistory();
    return history.where((n) => !n.isRead).length;
  }

  Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    for (final n in history) {
      n.isRead = true;
    }
    await prefs.setString(_historyKey, AppNotification.listToJson(history));
  }

  Future<void> markRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    for (final n in history) {
      if (n.id == id) n.isRead = true;
    }
    await prefs.setString(_historyKey, AppNotification.listToJson(history));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Token storage
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> storeTokenForUser(String userId) async {
    if (_token == null) return;
    try {
      await SupabaseService().updateDeviceToken(userId, _token!);
      debugPrint('[FCM] Token stored for user $userId');
    } catch (e) {
      debugPrint('[FCM] Token storage error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Topic subscriptions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) return;
    try {
      await _fcm.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('[FCM] Subscribe error: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return;
    try {
      await _fcm.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('[FCM] Unsubscribe error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Preferences
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
    if (enabled) {
      await subscribeToTopic('all_users');
      await subscribeToTopic('recall_alerts');
    } else {
      await unsubscribeFromTopic('all_users');
      await unsubscribeFromTopic('recall_alerts');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public notification triggers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> showWelcomeNotification(String userName) async {
    await _showAndStore(
      title: 'Welcome to DawaaCheck!',
      body:
          'Hi $userName! Your medicine safety guardian is active. Scan any medicine to verify its authenticity.',
      type: NotificationType.welcome,
      route: '/home',
    );
  }

  Future<void> showScanResultNotification({
    required String medicineName,
    required String verdict,
    required int riskScore,
  }) async {
    late NotificationType type;
    late String title;
    late String body;

    switch (verdict.toUpperCase()) {
      case 'VERIFIED':
        type = NotificationType.scanVerified;
        title = 'Verified — $medicineName';
        body =
            'All safety checks passed. Risk score: $riskScore/100. Safe to use.';
      case 'DANGER':
        type = NotificationType.scanDanger;
        title = 'DANGER — $medicineName';
        body =
            'Critical issues found! Risk: $riskScore/100. Do NOT use this medicine. Return to pharmacy immediately.';
      default:
        type = NotificationType.scanUnverified;
        title = 'Unverified — $medicineName';
        body =
            'Could not fully verify. Risk: $riskScore/100. Exercise caution and consult your pharmacist.';
    }

    await _showAndStore(title: title, body: body, type: type, route: '/history');
  }

  Future<void> showRecallNotification(String medicineName) async {
    await _showAndStore(
      title: 'Recall Alert — $medicineName',
      body:
          'DRAP has issued an active recall for $medicineName. Stop using and consult your pharmacist immediately.',
      type: NotificationType.recallAlert,
      route: '/recalls',
    );
  }

  /// Fired when DRAP recalls a medicine the user previously SCANNED (proactive
  /// recall). This is the "I bought it, they recalled it a week later" alert.
  Future<void> showProactiveRecallNotification({
    required String medicineName,
    required String reason,
    bool exactBatch = false,
  }) async {
    final scope = exactBatch
        ? 'Your exact batch of $medicineName has been recalled by DRAP.'
        : 'A medicine you scanned — $medicineName — has been recalled by DRAP.';
    await _showAndStore(
      title: 'Recall affects your medicine',
      body: '$scope Stop using it and consult your pharmacist. $reason',
      type: NotificationType.recallAlert,
      route: '/recalls',
    );
  }

  Future<void> showScanReminder() async {
    await _showAndStore(
      title: 'Time for a Safety Check',
      body:
          'You haven\'t scanned any medicines recently. Stay safe — verify your medicines with a quick scan.',
      type: NotificationType.scanReminder,
      route: '/home',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Scheduled: daily safety tip
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _maybeShowDailySafetyTip() async {
    final prefs = await SharedPreferences.getInstance();
    final lastTipDate = prefs.getString(_lastTipKey);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (lastTipDate == today) return; // Already shown today

    final enabled = await isEnabled();
    if (!enabled) return;

    await prefs.setString(_lastTipKey, today);

    final tip = _safetyTips[Random().nextInt(_safetyTips.length)];
    await _showAndStore(
      title: 'Daily Safety Tip',
      body: tip,
      type: NotificationType.safetyTip,
      route: '/home',
    );
  }

  /// Call after a scan to potentially schedule a reminder later.
  /// Stores last scan date. On next app open, if >3 days, remind.
  Future<void> recordScanActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'last_scan_date', DateTime.now().toIso8601String().substring(0, 10));
  }

  /// Call on app startup to check inactivity
  Future<void> checkScanInactivity() async {
    final prefs = await SharedPreferences.getInstance();
    final lastScan = prefs.getString('last_scan_date');
    if (lastScan == null) return;

    final lastDate = DateTime.parse(lastScan);
    final daysSince = DateTime.now().difference(lastDate).inDays;

    if (daysSince >= 3) {
      final lastReminder = prefs.getString('last_scan_reminder');
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (lastReminder == today) return;

      await prefs.setString('last_scan_reminder', today);
      await showScanReminder();
    }
  }
}
