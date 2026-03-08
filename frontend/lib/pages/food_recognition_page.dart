
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
// ignore: unused_import
import '../pages/webview_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


import '../constants.dart';

class FoodRecognitionPage extends StatefulWidget {
  const FoodRecognitionPage({super.key});

  @override
  State<FoodRecognitionPage> createState() => _FoodRecognitionPageState();
}

class _FoodRecognitionPageState extends State<FoodRecognitionPage> {
  final _picker = ImagePicker();

  XFile? _file;
  // ignore: prefer_final_fields
  bool _loading = false;

  int? _countdown; // null = 沒倒數；3/2/1 = 倒數中
  String? _error;

  Future<void> _startCameraCountdown() async {
    setState(() {
      _error = null;
      _countdown = 3;
      _file = null;
    });

    for (int i = 3; i >= 1; i--) {
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    setState(() => _countdown = null);

    // 倒數完 → 開相機（使用者按快門）
    await _pick(ImageSource.camera);
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final f = await _picker.pickImage(source: source, imageQuality: 90);
      if (f == null) return;

      setState(() {
        _file = f;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Image selection failed：$e');
    }
  }

 Future<void> _onStartIdentifyPressed() async {
  const recipeUrl = 'https://food.bestweiwei.dpdns.org'; //demo test

  final go = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return AlertDialog(
        title: const Text('Open Recipe Website?'),
        content: const Text('Do you want to open the recipe website now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      );
    },
  );

  if (go == true) {
    await _openRecipeUrl(recipeUrl);
  }
}

Future<void> _openRecipeUrl(String url) async {
  final uri = Uri.parse(url);

  if (kIsWeb) {
    final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!ok) {
      setState(() => _error = 'Failed to open url: $url');
    }
    return;
  }

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    setState(() => _error = 'Failed to open url: $url');
  }
}



  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSeaBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: iconColor),
              const SizedBox(height: 10),
              Text(title, style: GoogleFonts.itim(fontSize: 16, color: textColor)),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: GoogleFonts.itim(fontSize: 13, color: textColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview() {
    if (_file == null) {
      return Container(
        height: 220,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white),
        ),
        child: Text(
          'No image selected',
          style: GoogleFonts.itim(fontSize: 16, color: textColor),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(_file!.path),
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final countdown = _countdown;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: Text(
          'Food Recognition',
          style: GoogleFonts.itim(fontSize: 24, color: textColor),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ===== 倒數顯示=====
            if (countdown != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white),
                ),
                child: Text(
                  '$countdown',
                  style: GoogleFonts.itim(fontSize: 48, color: textColor),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ===== 圖片預覽）=====
            _preview(),
            const SizedBox(height: 14),

            // ===== 開始辨識按鈕=====
            InkWell(
              onTap: (_loading) ? null : _onStartIdentifyPressed,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: (_file == null || _loading) ? Colors.white24 : kSeaBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Start Identify (API)',
                  style: GoogleFonts.itim(fontSize: 16, color: textColor),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: GoogleFonts.itim(
                  fontSize: 14,
                  color: const Color(0xfff7433c),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ===== 拍照 / 上傳按鈕=====
            Row(
              children: [
                _actionTile(
                  icon: Icons.photo_camera,
                  title: 'Camera',
                  subtitle: 'Open camera in 3 seconds',
                  onTap: _loading ? null : _startCameraCountdown,
                ),
                const SizedBox(width: 12),
                _actionTile(
                  icon: Icons.photo_library,
                  title: 'Upload Photo',
                  subtitle: 'Select a picture from album',
                  onTap: _loading ? null : () => _pick(ImageSource.gallery),
                ),
              ],
            ),
          ],

        ),
      ),
    );
  }
}
