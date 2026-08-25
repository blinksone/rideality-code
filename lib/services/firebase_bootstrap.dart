import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'push_notification_service.dart';

/// Initializes Firebase Core, Storage auth, and FCM push.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _initialized = false;
  static bool _firebaseReady = false;

  static bool get isReady => _firebaseReady;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint(
        '[Firebase] Skipped — not configured for this platform.',
      );
      _firebaseReady = false;
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _firebaseReady = true;
      debugPrint(
        '[Firebase] Ready (project: ${DefaultFirebaseOptions.android.projectId})',
      );

      try {
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance.signInAnonymously();
          debugPrint('[Firebase] Signed in anonymously for Storage');
        }
      } catch (e) {
        debugPrint(
          '[Firebase] Anonymous auth failed (Storage may need rules): $e',
        );
      }

      await PushNotificationService.instance.start();
    } catch (e, st) {
      debugPrint('[Firebase] Init failed: $e\n$st');
      _firebaseReady = false;
    }
  }
}
