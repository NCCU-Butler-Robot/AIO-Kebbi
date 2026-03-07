// 主選單
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  static const _icons  = [Icons.text_snippet, Icons.bar_chart, Icons.fastfood, Icons.support_agent];
  static const _labels = ['Call Monitor', 'Historical Probabilities','Food Recognition', 'Butler'];
  static const _routes = ['/monitor', '/stats','/food', '/butler'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        title: const Text('Menu'),
        actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.8,
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
            ),
            itemCount: _icons.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => Navigator.pushNamed(context, _routes[index]),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kSeaBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_icons[index], size: 48, color: iconColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _labels[index],
                      style: GoogleFonts.itim(fontSize: 17, color: textColor),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
