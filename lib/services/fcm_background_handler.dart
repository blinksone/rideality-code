import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Top-level isolate handler for background/killed FCM messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Must re-init Firebase in this isolate.
  try {
    if (Firebase.apps.isEmpty) {
      if (DefaultFirebaseOptions.isConfigured) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp();
      }
    }
  } catch (e) {
    debugPrint('[FCM bg] Firebase init: $e');
  }
  debugPrint(
    '[FCM bg] ${message.messageId} type=${message.data['type']} '
    'data=${message.data}',
  );
  // System tray shows notification payload when present.
  // Data-only messages rely on system/OS behavior; foreground shows local UI.
}
