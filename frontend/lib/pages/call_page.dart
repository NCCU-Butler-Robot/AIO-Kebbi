import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../providers/call_provider.dart';
import '../services/audio_service.dart';

class CallPage extends StatefulWidget {
  const CallPage({super.key});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  StreamSubscription<Uint8List>? _audioSub;
  final _svc = AudioService.I;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cp = context.read<CallProvider>();
      _audioSub = cp.audioFrames.listen((bytes) {
        _svc.playBytes(bytes);
      });
    });
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _svc.stopPlay(); // 停止任何播放
    if (mounted) {
      context.read<CallProvider>().stopMicStream();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<CallProvider>();
    if (!cp.inCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }

    final dur = cp.callDuration;
    final callId = cp.callId ?? '-';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: Text('In Call',
            style: GoogleFonts.itim(fontSize: 24, color: textColor)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text('Call ID: $callId',
                style: GoogleFonts.itim(fontSize: 14, color: textColor)),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text('Talk time',
                      style: GoogleFonts.itim(
                          fontSize: 18, color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Text(_fmt(dur),
                      style: GoogleFonts.itim(fontSize: 36, color: textColor)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cp.streaming ? Colors.orange : Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: !cp.inCall
                      ? null
                      : () async {
                          final ctx = context;
                          final messenger = ScaffoldMessenger.of(ctx);
                          try {
                            if (!cp.streaming) {
                              await cp.startMicStream();
                              messenger.showSnackBar(const SnackBar(
                                  content: Text('Start streaming recording')));
                            } else {
                              await cp.stopMicStream();
                              messenger.showSnackBar(const SnackBar(
                                  content: Text('Stop streaming recording')));
                            }
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Streaming Error：$e')),
                            );
                          }
                        },
                  icon: Icon(
                    cp.streaming ? Icons.stop_circle : Icons.mic,
                    color: Colors.white,
                  ),
                  label: Text(
                    cp.streaming ? 'Stop streaming' : 'Start streaming',
                    style: GoogleFonts.itim(color: Colors.white),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 靜音切換
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Selector<CallProvider, bool>(
                  selector: (_, c) => c.micMuted,
                  builder: (context, muted, _) {
                    return OutlinedButton.icon(
                      onPressed: () =>
                          context.read<CallProvider>().toggleMicMute(),
                      icon: Icon(
                        muted ? Icons.mic_off : Icons.mic,
                        color: muted ? Colors.red : Colors.blue,
                      ),
                      label: Text(muted ? 'Mic Muted' : 'Mic On'),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 播放音量
            Row(
              children: [
                const Icon(Icons.volume_down),
                Expanded(
                  child: Selector<CallProvider, double>(
                    selector: (_, c) => c.playbackVolume,
                    builder: (context, vol, _) {
                      return Slider(
                        value: vol,
                        onChanged: (v) =>
                            context.read<CallProvider>().setPlaybackVolume(v),
                        min: 0.0,
                        max: 1.0,
                      );
                    },
                  ),
                ),
                const Icon(Icons.volume_up),
              ],
            ),

            const SizedBox(height: 12),

            // 連線狀態顯示
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle,
                          size: 10,
                          color: (cp.inCall && cp.streaming)
                              ? Colors.green
                              : Colors.grey),
                      const SizedBox(width: 6),
                      Text(cp.streaming ? 'LIVE' : 'Idle',
                          style: GoogleFonts.itim(fontSize: 14)),
                      const Spacer(),
                      Text(
                        'WS: ${context.read<CallProvider>().connected ? 'Connected' : 'Retrying...'}',
                        style:
                            GoogleFonts.itim(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Uplink: ${cp.uplinkKbps.toStringAsFixed(1)} kbps',
                          style: GoogleFonts.itim(fontSize: 14)),
                      Text('Jitter: ${cp.jitterMs.toStringAsFixed(0)} ms',
                          style: GoogleFonts.itim(fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // 掛斷
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () async {
                    final ctx = context;
                    final messenger = ScaffoldMessenger.of(ctx);
                    final provider = ctx.read<CallProvider>();
                    await provider.stopMicStream(); // 先停串流
                    await provider.hangup();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Hang up')),
                    );
                  },
                  icon: const Icon(Icons.call_end, color: Colors.white),
                  label: Text('Hang Up',
                      style:
                          GoogleFonts.itim(fontSize: 16, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
