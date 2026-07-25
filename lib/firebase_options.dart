import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBv6G1RLyjzwaRlKoQC0arys7MkXUWCFuY',
    appId: '1:396369034947:android:73ccb2a3df8921342aec76',
    messagingSenderId: '396369034947',
    projectId: 'replyai-749f7',
    storageBucket: 'replyai-749f7.firebasestorage.app',
  );
}
