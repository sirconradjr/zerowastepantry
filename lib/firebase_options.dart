import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA1QBCqFcHj61YiylxK1pQxO9W9ZuTou30',
    appId: '1:1095826886033:android:f7e499e1e2910613661e30',
    messagingSenderId: '1095826886033',
    projectId: 'zerowastepantry',
    databaseURL: 'https://zerowastepantry-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'zerowastepantry.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDp38x4J6agADTro_weudkWkUdBG6Xt2fI',
    appId: '1:1095826886033:ios:c5954c925863088a661e30',
    messagingSenderId: '1095826886033',
    projectId: 'zerowastepantry',
    databaseURL: 'https://zerowastepantry-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'zerowastepantry.firebasestorage.app',
    iosBundleId: 'com.example.zerowastepantry',
  );
}
