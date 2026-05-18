import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCj4Oow8N7HJ1ZbtUvrV6fUMDi3Zi_6jok',
    appId: '1:500259007502:web:2bb3d589f83ac0c4f0a05f',
    messagingSenderId: '500259007502',
    projectId: 'petcage-abb2f',
    authDomain: 'petcage-abb2f.firebaseapp.com',
    storageBucket: 'petcage-abb2f.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDnH2HtvBTNkLz4qcTFev3zomGbndiL97M',
    appId: '1:500259007502:android:280e2eba37d92513f0a05f',
    messagingSenderId: '500259007502',
    projectId: 'petcage-abb2f',
    storageBucket: 'petcage-abb2f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDsxvQbWzRObEsx81ogJzDBxoEzx9MpoWI',
    appId: '1:500259007502:ios:265db93beebdb096f0a05f',
    messagingSenderId: '500259007502',
    projectId: 'petcage-abb2f',
    storageBucket: 'petcage-abb2f.firebasestorage.app',
    androidClientId: '500259007502-eleimhscojqbdmrm623q0f0de9qmh9n0.apps.googleusercontent.com',
    iosClientId: '500259007502-thu54tqplkf107gcjonbitqpm1dpr0bj.apps.googleusercontent.com',
    iosBundleId: 'com.xuanting.dogApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDsxvQbWzRObEsx81ogJzDBxoEzx9MpoWI',
    appId: '1:500259007502:ios:0519eafac0f04921f0a05f',
    messagingSenderId: '500259007502',
    projectId: 'petcage-abb2f',
    storageBucket: 'petcage-abb2f.firebasestorage.app',
    androidClientId: '500259007502-eleimhscojqbdmrm623q0f0de9qmh9n0.apps.googleusercontent.com',
    iosClientId: '500259007502-pibnjhgbsgb6tcurtun7l10ktpbcu8j8.apps.googleusercontent.com',
    iosBundleId: 'com.example.flutterApplication1',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCj4Oow8N7HJ1ZbtUvrV6fUMDi3Zi_6jok',
    appId: '1:500259007502:web:2118f5dc85e3d7daf0a05f',
    messagingSenderId: '500259007502',
    projectId: 'petcage-abb2f',
    authDomain: 'petcage-abb2f.firebaseapp.com',
    storageBucket: 'petcage-abb2f.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_WITH_LINUX_API_KEY',
    appId: 'REPLACE_WITH_LINUX_APP_ID',
    messagingSenderId: 'REPLACE_WITH_MESSAGING_SENDER_ID',
    projectId: 'petcage-abb2f',
    authDomain: 'petcage-abb2f.firebaseapp.com',
    storageBucket: 'petcage-abb2f.appspot.com',
  );
}