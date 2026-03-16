import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pwa_install/pwa_install.dart';

import 'constants.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'widgets/auth_guard.dart';
import 'di/service_locator.dart';

import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/menu_page.dart';
import 'pages/monitor_page.dart';
import 'pages/stats_page.dart';
import 'pages/food_recognition_page.dart';
import 'pages/butler_chat_page.dart';

import 'services/kebbi_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PWAInstall().setup(installCallback: () {
    debugPrint('APP INSTALLED!');
  });

  KebbiService.init();
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();
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
