// Firebase options for Rideality App.
// Android values from android/app/google-services.json (package com.rideality.app).
// iOS: add GoogleService-Info.plist and update ios options when available.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// True when this platform has real Firebase config.
  static bool get isConfigured {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return true;
      case TargetPlatform.iOS:
        // Set true after adding GoogleService-Info.plist + filling ios options.
        return false;
      default:
        return false;
    }
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase is not configured for web. Add a Firebase web app and options.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        if (!isConfigured) {
          throw UnsupportedError(
            'Firebase not configured for iOS. Add GoogleService-Info.plist '
            'and run flutterfire configure or update DefaultFirebaseOptions.ios.',
          );
        }
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAT3nOsrj_u6fDmqECkRGPJMXkNWrp75uk',
    appId: '1:261821276239:android:2546f1b0a12d4b27bcca3a',
    messagingSenderId: '261821276239',
    projectId: 'rideality',
    storageBucket: 'rideality.firebasestorage.app',
  );

  /// Placeholder until iOS Firebase app is registered for com.rideality.app.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: '261821276239',
    projectId: 'rideality',
    storageBucket: 'rideality.firebasestorage.app',
    iosBundleId: 'com.rideality.app',
  );
}
