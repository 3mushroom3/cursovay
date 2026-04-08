// File: firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'FirebaseOptions have not been configured for Web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// ANDROID CONFIG (must match android/app/google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDRkEAPVBectcc6nBbj4EvECrEcH8zp_lA',
    appId: '1:939356990596:android:09f52cac8574d5ef3026d1',
    messagingSenderId: '939356990596',
    projectId: 'dgtu-ff8cf',
    storageBucket: 'dgtu-ff8cf.appspot.com',
  );

  /// IOS CONFIG
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBN0yJZD_DI071G9V2yHVy3MJoY7qiDi_Q',
    appId: '1:519764547564:ios:d740b731c20547ebd952c9',
    messagingSenderId: '519764547564',
    projectId: 'kasabov-dgtu',
    storageBucket: 'kasabov-dgtu.firebasestorage.app',
    iosBundleId: 'com.example.kasabovDgtu',
  );
}