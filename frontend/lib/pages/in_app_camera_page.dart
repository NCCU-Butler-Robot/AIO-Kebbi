import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Full-screen in-app camera.
/// Returns an [XFile] when the user captures a photo, or null if cancelled.
class InAppCameraPage extends StatefulWidget {
  const InAppCameraPage({super.key});

  @override
  State<InAppCameraPage> createState() => _InAppCameraPageState();
}

class _InAppCameraPageState extends State<InAppCameraPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _initializing = true;
  bool _capturing = false;
  String? _error;
  int _cameraIndex = 0; // 0 = back, 1 = front

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera({int index = 0}) async {
    setState(() {
      _initializing = true;
      _error = null;
    });

    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      setState(() {
        _initializing = false;
        _error = 'Camera permission denied. Please enable in Settings.';
      });
      return;
    }

    try {
      _cameras ??= await availableCameras();

      if (_cameras!.isEmpty) {
        setState(() {
          _initializing = false;
          _error = 'No camera found on this device.';
        });
        return;
      }

      final camIndex = index.clamp(0, _cameras!.length - 1);
      final controller = CameraController(
        _cameras![camIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      // Dispose old controller after new one is ready
      await _controller?.dispose();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _cameraIndex = camIndex;
        _initializing = false;
      });
    } catch (e) {
      setState(() {
        _initializing = false;
        _error = 'Camera error: $e';
      });
    }
  }

  Future<void> _capture() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _capturing) return;

    setState(() => _capturing = true);
    try {
      final xfile = await ctrl.takePicture();
      if (mounted) Navigator.pop(context, XFile(xfile.path));
    } catch (e) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _error = 'Capture failed: $e';
        });
      }
    }
  }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    final next = (_cameraIndex + 1) % _cameras!.length;
    _initCamera(index: next);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Camera preview ──────────────────────────────────────────
            if (_initializing)
              const Center(
                  child: CircularProgressIndicator(color: Colors.white))
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Center(child: CameraPreview(_controller!)),

            // ── Top: back button ────────────────────────────────────────
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context, null),
              ),
            ),

            // ── Top: switch camera ──────────────────────────────────────
            if ((_cameras?.length ?? 0) > 1)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.flip_camera_ios,
                      color: Colors.white, size: 28),
                  onPressed: _initializing ? null : _switchCamera,
                ),
              ),

            // ── Bottom: shutter button ──────────────────────────────────
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: (_initializing || _capturing) ? null : _capture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _capturing ? Colors.grey : Colors.white24,
                    ),
                    child: _capturing
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
