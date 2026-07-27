import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyREPLACE_WITH_YOUR_OWN_FIREBASE_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-firebase-project',
    authDomain: 'your-firebase-project.firebaseapp.com',
    storageBucket: 'your-firebase-project.firebasestorage.app',
    measurementId: 'G-7TEBJKYL1Q',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyREPLACE_WITH_YOUR_OWN_FIREBASE_API_KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-firebase-project',
    storageBucket: 'your-firebase-project.firebasestorage.app',
  );

  // TODO: Add iOS config after creating iOS app in Firebase console
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyREPLACE_WITH_YOUR_OWN_FIREBASE_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-firebase-project',
    storageBucket: 'your-firebase-project.firebasestorage.app',
    iosBundleId: 'com.dawaacheck.app',
  );
}
