import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';


class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    super.initState();
    // auth.init() 是非同步的，先等 frame 完成後檢查
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  void _checkAuth() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/menu');
    } else {
      // 等 init() 完成後再次檢查
      auth.addListener(_onAuthChanged);
    }
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      auth.removeListener(_onAuthChanged);
      Navigator.pushReplacementNamed(context, '/menu');
    }
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 圓形 LOGO
            Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/image/logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome',
              style: GoogleFonts.mogra(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: buttonColor,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                final auth = context.read<AuthProvider>();
                if (auth.isLoggedIn) {
                  Navigator.pushReplacementNamed(context, '/menu');
                } else {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: buttonColor),
              child: Text(
                'Start',
                style: GoogleFonts.mogra(fontSize: 18, color: backgroundColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
