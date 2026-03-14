import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../constants.dart';
import '../di/service_locator.dart';
import '../pages/webview_page.dart';
import '../services/api_service.dart';

class FoodRecognitionPage extends StatefulWidget {
  const FoodRecognitionPage({super.key});

  @override
  State<FoodRecognitionPage> createState() => _FoodRecognitionPageState();
}

class _FoodRecognitionPageState extends State<FoodRecognitionPage> {
  final _picker = ImagePicker();

  XFile? _file;
  Uint8List? _fileBytes; // 供 Web 平台預覽用
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Auto-open camera when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pick(ImageSource.camera);
    });
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final f = await _picker.pickImage(source: source, imageQuality: 90);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      setState(() {
        _file = f;
        _fileBytes = bytes;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Image selection failed: $e');
    }
  }

  Future<void> _onStartIdentifyPressed() async {
    if (_file == null || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detectUrl = await sl<ApiService>().uploadFoodImage(_file!);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeWebViewPage(url: detectUrl),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Recognition failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
              Text(title,
                  style: GoogleFonts.itim(fontSize: 16, color: textColor)),
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

    final imageWidget = kIsWeb && _fileBytes != null
        ? Image.memory(_fileBytes!,
            height: 220, width: double.infinity, fit: BoxFit.cover)
        : Image.file(File(_file!.path),
            height: 220, width: double.infinity, fit: BoxFit.cover);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canIdentify = _file != null && !_loading;

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
            // ===== 圖片預覽 =====
            _preview(),
            const SizedBox(height: 14),

            // ===== 開始辨識按鈕 =====
            InkWell(
              onTap: canIdentify ? _onStartIdentifyPressed : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: canIdentify ? kSeaBlue : Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Start Identify',
                        style:
                            GoogleFonts.itim(fontSize: 16, color: textColor),
                      ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: GoogleFonts.itim(
                    fontSize: 14, color: const Color(0xfff7433c)),
              ),
            ],

            const SizedBox(height: 24),

            // ===== 拍照 / 上傳按鈕 =====
            Row(
              children: [
                _actionTile(
                  icon: Icons.photo_camera,
                  title: 'Camera',
                  subtitle: 'Take a photo',
                  onTap: _loading ? null : () => _pick(ImageSource.camera),
                ),
                const SizedBox(width: 12),
                _actionTile(
                  icon: Icons.photo_library,
                  title: 'Upload Photo',
                  subtitle: 'Select from album',
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
