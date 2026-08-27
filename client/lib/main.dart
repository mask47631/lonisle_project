import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

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
  await RustLib.init(externalLibrary: _loadRustLibrary());
  runApp(const LonIsleApp());
}

/// Rust core 加载策略。
///
/// cargokit 将 core 以静态库 `-force_load` 进 rust_lib_lonisle_client，
/// 因此打包产物内不存在独立的 lonisle_client_core 动态库（FRB 默认加载器
/// 只会找它，找不到即启动崩溃）。按以下顺序探测：
/// - Apple 端：rust_lib_lonisle_client.framework（pod 标准动态产物）→ process()
/// - Windows/Linux：产物目录内的 cdylib（与 FRB 默认行为一致）
/// - 其余（开发/web）：交回 FRB 默认加载逻辑
ExternalLibrary _loadRustLibrary() {
  if (!kIsWeb && (Platform.isMacOS || Platform.isIOS)) {
    try {
      return ExternalLibrary.open(
        'rust_lib_lonisle_client.framework/rust_lib_lonisle_client',
      );
    } catch (_) {
      return ExternalLibrary.process(iKnowHowToUseIt: true);
    }
  }
  if (!kIsWeb && Platform.isWindows) {
    return ExternalLibrary.open('lonisle_client_core.dll');
  }
  if (!kIsWeb && Platform.isLinux) {
    return ExternalLibrary.open('liblonisle_client_core.so');
  }
  final lib = loadExternalLibrary(RustLib.kDefaultExternalLibraryLoaderConfig);
  if (lib is ExternalLibrary) return lib;
  // IO 平台加载实为同步；此处仅为满足类型兜底
  return ExternalLibrary.process(iKnowHowToUseIt: true);
}
