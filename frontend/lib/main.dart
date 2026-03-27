import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pwa_install/pwa_install.dart';

import 'constants.dart';
import 'di/service_locator.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'services/fcm_service.dart';
import 'services/kebbi_service.dart';
import 'widgets/auth_guard.dart';

import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/menu_page.dart';
import 'pages/monitor_page.dart';
import 'pages/stats_page.dart';
import 'pages/food_recognition_page.dart';
import 'pages/butler_chat_page.dart';

/// 全域 NavigatorKey — 供 FcmService 在 widget tree 外部導航使用
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 初始化（FCM 需要）
  await Firebase.initializeApp();

  PWAInstall().setup(installCallback: () {
    debugPrint('APP INSTALLED!');
  });

  KebbiService.init();
  setupServiceLocator();

  // FCM 初始化 — 前台收到訊息時顯示 AlertDialog
  FcmService.I.onRawMessage = (title, body, data) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title ?? 'FCM 訊息收到'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (body != null) ...[
                Text(body, style: const TextStyle(fontSize: 14)),
                const Divider(),
              ],
              ...data.entries.map(
                (e) => Text('${e.key}: ${e.value}',
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  };

  // FCM 初始化 — 設定 incoming_call 處理
  FcmService.I.onIncomingCall = (callToken, callerName) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    // 若目前已在 MonitorPage 就不重複 push
    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MonitorPage(callToken: callToken),
      ),
      (route) => route.isFirst, // 保留第一頁（WelcomePage/MenuPage）
    );
  };

  // 初始化並取得 FCM token（非同步，不阻擋啟動）
  FcmService.I.initialize().then((token) {
    if (token != null) {
      // token 等到登入後由 AuthProvider 負責送到後端
      debugPrint('[main] FCM token ready: $token');
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      title: 'Fraud Detect App',
      theme: ThemeData(
        textTheme: GoogleFonts.itimTextTheme(),
        primaryTextTheme: GoogleFonts.itimTextTheme(),
        scaffoldBackgroundColor: backgroundColor,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/menu': (context) => const MenuPage(),
        '/monitor': (context) => const AuthGuard(child: MonitorPage()),
        '/stats': (context) => const AuthGuard(child: StatsPage()),
        '/food': (_) => const FoodRecognitionPage(),
        '/butler': (_) => const ButlerChatPage(),
      },
    );
  }
}
