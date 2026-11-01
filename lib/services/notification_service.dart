import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/notification_config.dart';
import '../firebase_options.dart';
import '../models/app_user.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}
}

/// Push Notification Service using Firebase Cloud Messaging (FCM).
/// - Respects the global On/Off toggle set from the Admin panel.
/// - Subscribes the device to topic `all` as well as `country_<country>` and `city_<city>` topics for targeted campaigns.
/// - Displays a native OS system notification even when the app is open in the foreground.
/// - Notifications carrying a `url` in `data` open it automatically when tapped.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const MethodChannel _nativeChannel =
      MethodChannel('com.allohalal.app/notifications');

  static const String _prefPrevCountryTopic = 'fcm_topic_country';
  static const String _prefPrevCityTopic = 'fcm_topic_city';

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        if (defaultTargetPlatform == TargetPlatform.android &&
            NotificationConfig.isConfigured) {
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: NotificationConfig.firebaseApiKey,
              appId: NotificationConfig.firebaseAppId,
              messagingSenderId: NotificationConfig.firebaseMessagingSenderId,
              projectId: NotificationConfig.firebaseProjectId,
            ),
          );
        } else {
          // Use DefaultFirebaseOptions (safely selects iOS or Android configuration)
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
      }

      // Apply global feature toggle from the Admin panel
      await applyGlobalToggle();

      // Show foreground notifications on iOS
      try {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {}

      // Listen for incoming messages safely
      try {
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

        final initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageTap(initialMessage);
        }
      } catch (_) {}

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ℹ️ NotificationService (Firebase) init info: $e');
      }
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (!NotificationConfig.isEnabled) return;

    final notification = message.notification;
    final title =
        notification?.title ?? (message.data['title'] as String? ?? '');
    final body = notification?.body ?? (message.data['body'] as String? ?? '');
    final urlStr = (message.data['url'] as String? ?? '').trim();

    if (title.isEmpty && body.isEmpty) return;

    // Trigger only Native OS System Notification (Android Notification Tray)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        _nativeChannel.invokeMethod('showSystemNotification', {
          'title': title,
          'body': body,
          'url': urlStr,
        });
      } catch (_) {}
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    final urlStr = (message.data['url'] as String? ?? '').trim();
    if (urlStr.isNotEmpty) {
      _openUrl(urlStr);
    }
  }

  void _openUrl(String urlStr) {
    final uri = Uri.tryParse(urlStr);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Enable/disable receiving notifications according to the remote toggle.
  Future<void> applyGlobalToggle() async {
    if (Firebase.apps.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;
      if (NotificationConfig.isEnabled) {
        await messaging.setAutoInitEnabled(true);
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        if (kDebugMode) {
          debugPrint('ℹ️ Push permission status: ${settings.authorizationStatus}');
        }

        try {
          await messaging.subscribeToTopic('all');
          await messaging.subscribeToTopic('global_alerts');
        } catch (e) {
          if (kDebugMode) debugPrint('ℹ️ Topic subscribe note: $e');
        }
      } else {
        try {
          await messaging.unsubscribeFromTopic('all');
          await messaging.unsubscribeFromTopic('global_alerts');
        } catch (_) {}
        await messaging.setAutoInitEnabled(false);
        await messaging.deleteToken();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ℹ️ applyGlobalToggle: $e');
    }
  }

  static String _sanitizeTopic(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\-_.~%]'), '_');
  }

  /// Subscribe this device to the signed-in user's Country & City topics for targeting.
  Future<void> syncUserTags(AppUser? user) async {
    if (!_isInitialized || Firebase.apps.isEmpty) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final prefs = await SharedPreferences.getInstance();

      final prevCountry = prefs.getString(_prefPrevCountryTopic) ?? '';
      final prevCity = prefs.getString(_prefPrevCityTopic) ?? '';

      if (prevCountry.isNotEmpty) {
        await messaging.unsubscribeFromTopic(prevCountry);
        await prefs.remove(_prefPrevCountryTopic);
      }
      if (prevCity.isNotEmpty) {
        await messaging.unsubscribeFromTopic(prevCity);
        await prefs.remove(_prefPrevCityTopic);
      }

      if (user == null || !NotificationConfig.isEnabled) return;

      if (user.country.trim().isNotEmpty && user.country != 'Unknown') {
        final countryTopic = 'country_${_sanitizeTopic(user.country)}';
        await messaging.subscribeToTopic(countryTopic);
        await prefs.setString(_prefPrevCountryTopic, countryTopic);
      }
      if (user.city.trim().isNotEmpty) {
        final cityTopic = 'city_${_sanitizeTopic(user.city)}';
        await messaging.subscribeToTopic(cityTopic);
        await prefs.setString(_prefPrevCityTopic, cityTopic);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ℹ️ syncUserTags: $e');
    }
  }
}
