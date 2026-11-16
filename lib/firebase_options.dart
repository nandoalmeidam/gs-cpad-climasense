// Configuração pública dos clientes Firebase. O acesso aos dados depende das regras.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    return null;
  }

  static const web = FirebaseOptions(
    apiKey: "AIzaSyAVUpFKaSBp7EVIcApRZFJejatYVy49ZJE",
    appId: "1:565445458255:web:9f8f572780d07dcc682d3a",
    messagingSenderId: "565445458255",
    projectId: "climasense-gs26-b27e91",
    authDomain: "climasense-gs26-b27e91.firebaseapp.com",
    storageBucket: "climasense-gs26-b27e91.firebasestorage.app",
  );
  static const android = FirebaseOptions(
    apiKey: "AIzaSyCPwCcsJj604rn6BHbsNHm5EVM3Tz_14EQ",
    appId: "1:565445458255:android:18f67e6ceb5fc402682d3a",
    messagingSenderId: "565445458255",
    projectId: "climasense-gs26-b27e91",
    storageBucket: "climasense-gs26-b27e91.firebasestorage.app",
  );
}
