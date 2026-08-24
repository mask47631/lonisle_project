import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 初始化（FCM 推送；桌面端无配置文件会抛错，回退 mock 渠道）
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase 初始化失败，推送回退 mock：$e');
  }
  await RustLib.init();
  runApp(const LonIsleApp());
}
