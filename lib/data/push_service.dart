import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Web push needs the project's public VAPID key, from Firebase console →
/// Project settings → Cloud Messaging → Web Push certificates. Pass it at
/// build time: `flutter build web --dart-define=FCM_VAPID_KEY=...`.
const _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

/// Whether push could be turned on.
enum PushResult { enabled, denied, unavailable }

/// Asks for notification permission and stores this device's push token
/// on the user's profile (`users/{uid}.fcmTokens`).
class PushService {
  PushService(this._firestore);
  final FirebaseFirestore _firestore;

  Future<PushResult> enable(String userId) async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return PushResult.denied;
      }
      if (kIsWeb && _vapidKey.isEmpty) {
        debugPrint('PushService: FCM_VAPID_KEY is not set for web.');
        return PushResult.unavailable;
      }
      final token = await messaging.getToken(
        vapidKey: kIsWeb ? _vapidKey : null,
      );
      if (token == null) return PushResult.unavailable;
      await _firestore.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
      return PushResult.enabled;
    } catch (e) {
      debugPrint('PushService.enable failed: $e');
      return PushResult.unavailable;
    }
  }
}
