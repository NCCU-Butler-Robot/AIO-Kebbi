import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';


class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

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
