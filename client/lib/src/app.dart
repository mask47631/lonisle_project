import 'package:flutter/material.dart';

import 'state/app_state.dart';
import 'theme.dart';
import 'ui/home_screen.dart';
import 'ui/onboarding_screen.dart';

/// 应用根组件
class LonIsleApp extends StatefulWidget {
  const LonIsleApp({super.key});

  @override
  State<LonIsleApp> createState() => _LonIsleAppState();
}

class _LonIsleAppState extends State<LonIsleApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await AppState.instance.init();
    } catch (e) {
      // 初始化失败不阻塞进入 UI（本地库损坏等场景降级可用，数据可重新同步）
      // ignore: avoid_print
      print('AppState.init 失败（降级继续）：$e');
    }
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LonIsle',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: LonIsleTheme.dark(),
      home: !_initialized
          ? const _SplashScreen()
          : ListenableBuilder(
              listenable: AppState.instance,
              builder: (context, _) {
                final state = AppState.instance;
                // 有身份且（已完成引导或已加入过服务器）→ 进入主界面；
                // 否则显示 onboarding（内部处理「生成身份」与「连接服务器」两种状态）
                if (state.hasIdentity &&
                    (state.onboardingDone || state.servers.isNotEmpty)) {
                  return const HomeScreen();
                }
                return const OnboardingScreen();
              },
            ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: LonIsleTheme.primary),
      ),
    );
  }
}
