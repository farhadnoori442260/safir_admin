import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  // 🌐 تنظیمات وب و FlutLab (مخصوص پنل ادمین)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyCKFg_5aX6Eqjm64srhfKdOR_neGUTek5w",
    appId: "1:983174537944:web:ae78969821766429822dad",
    messagingSenderId: "983174537944",
    projectId: "afghantaxi-de039",
    authDomain: "afghantaxi-de039.firebaseapp.com",
    storageBucket: "afghantaxi-de039.firebasestorage.app",
    measurementId: "G-LW39H9ZV4Y",
    // 👈 اضافه شدن لینک دیتابیس برای رفع خطای قرمز
    databaseURL: "https://afghantaxi-default-rtdb.firebaseio.com",
  );

  // 📱 تنظیمات اندروید
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "اینجا_API_KEY_را_بگذارید",
    appId: "اینجا_APP_ID_را_بگذارید",
    messagingSenderId: "اینجا_MESSAGING_SENDER_ID_را_بگذارید",
    projectId: "اینجا_PROJECT_ID_را_بگذارید",
    storageBucket: "اینجا_STORAGE_BUCKET_را_بگذارید",
    databaseURL: "https://afghantaxi-default-rtdb.firebaseio.com",
  );
}
