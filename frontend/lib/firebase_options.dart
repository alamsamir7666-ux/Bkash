// File generated for Firebase initialization without flutterfire CLI.
// Values come directly from android/app/google-services.json.
// Ignore this file — it's auto-overwritten if you ever run `flutterfire configure`.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for the current platform.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for Firebase in this app.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS is not configured for Firebase in this app.');
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for platform $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDR0LYFudaFjN1rBnwE8zaPz27OzoUtDqk',
    appId: '1:837630122314:android:a7135156110141b66b09b3',
    messagingSenderId: '837630122314',
    projectId: 'bkash-731a8',
    storageBucket: 'bkash-731a8.firebasestorage.app',
  );
}
