// PATH: lib/firebase_options.dart
// KEEP THIS FILE PURE: only FirebaseOptions + platform switch.
// Re-run `flutterfire configure` if you change bundle IDs.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios; 
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'run flutterfire configure again for linux.',
        );
      default:
        throw UnsupportedError('Unsupported platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyACTP88SOcn8ChwEbLI1PJKhBOeqjuOkJw',
    appId: '1:555187629518:macos:31be58d18633ec36dbcf9f',
    messagingSenderId: '555187629518',
    projectId: 'feelbetterapp-3e60c',
    authDomain: 'feelbetterapp-3e60c.firebaseapp.com',
    storageBucket: 'feelbetterapp-3e60c.firebasestorage.app',
    measurementId: 'G-KNVGLH8YZS',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBmXreWUnIT4END1yOaxOLOxVwCTRcv68o',
    appId: '1:555187629518:android:e65b5e3bb1b3d3cedbcf9f',
    messagingSenderId: '555187629518',
    projectId: 'feelbetterapp-3e60c',
    storageBucket: 'feelbetterapp-3e60c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA51YwRXDa2J7KvgtM7msLyLBOHbjvKkS0',
    appId: '1:555187629518:ios:69406c984fed164edbcf9f',
    messagingSenderId: '555187629518',
    projectId: 'feelbetterapp-3e60c',
    storageBucket: 'feelbetterapp-3e60c.firebasestorage.app',
    iosBundleId: 'com.example.feelBetterApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA51YwRXDa2J7KvgtM7msLyLBOHbjvKkS0',
    appId: '1:555187629518:ios:69406c984fed164edbcf9f',
    messagingSenderId: '555187629518',
    projectId: 'feelbetterapp-3e60c',
    storageBucket: 'feelbetterapp-3e60c.firebasestorage.app',
    iosBundleId: 'com.example.feelBetterApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyACTP88SOcn8ChwEbLI1PJKhBOeqjuOkJw',
    appId: '1:555187629518:web:a7da301ce0e52bb4dbcf9f',
    messagingSenderId: '555187629518',
    projectId: 'feelbetterapp-3e60c',
    authDomain: 'feelbetterapp-3e60c.firebaseapp.com',
    storageBucket: 'feelbetterapp-3e60c.firebasestorage.app',
    measurementId: 'G-F21GKZLGC5',
  );
}