import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';


import '../constants.dart';

class ButlerChatPage extends StatefulWidget {
  const ButlerChatPage({super.key});

  @override
  State<ButlerChatPage> createState() => _ButlerChatPageState();
}

class _ButlerChatPageState extends State<ButlerChatPage> {
  // --- Demo ---
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      from: _Speaker.butler,
      text: "Good evening. I’m your Butler. How can I help you today?",
      time: "10:31",
    ),
    _ChatMessage(
      from: _Speaker.user,
      text: "Hi. I want to check if my recent message looks suspicious.",
      time: "10:32",
    ),
    _ChatMessage(
      from: _Speaker.butler,
      text: "Sure. Please tell me what happened, and I’ll analyze the risk.",
      time: "10:32",
    ),
  ];

  // --- 逐字稿 / 錄音狀態 / 播放狀態---
  bool _isRecording = true; 
  bool _isPlaying = false;

  // Demo
  String _liveTranscript = "Listening…";

  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Demo
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _liveTranscript = "I received a message asking for urgent money transfer…");
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      _liveTranscript = _isRecording ? "Listening…" : "Recording stopped.";
    });
  }

  // ignore: unused_element
  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
  }

  void _sendText() {
    final txt = _textController.text.trim();
    if (txt.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(from: _Speaker.user, text: txt, time: _nowHHmm()));
      _textController.clear();

      // Demo
      _messages.add(_ChatMessage(
        from: _Speaker.butler,
        text: "Thanks. I will review it. If it asks for money or secrecy, it may be a scam.",
        time: _nowHHmm(),
      ));
    });
  }

  String _nowHHmm() {
    final t = TimeOfDay.now();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: Text(
          'Butler',
          style: GoogleFonts.itim(fontSize: 24, color: textColor),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ===== 上方 =====
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  return _ChatBubble(message: m);
                },
              ),
            ),

            // ===== 中間=====
           Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.blueGrey,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                Text(
                  _isRecording ? 'Listening…' : 'Paused',
                  style: GoogleFonts.itim(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),

                FakeSiriWave(active: _isRecording),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _liveTranscript,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.itim(
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),


            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              style: GoogleFonts.itim(color: textColor, fontSize: 16),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Type a message...',
                                hintStyle: GoogleFonts.itim(
                                  color: textColor,
                                  fontSize: 16,
                                ),
                              ),
                              onSubmitted: (_) => _sendText(),
                            ),
                          ),
                          IconButton(
                            onPressed: _sendText,
                            icon: const Icon(Icons.send, color: iconColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 麥克風
                  InkWell(
                    onTap: _toggleRecording,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _isRecording ? const Color(0xff29d97a) : kSeaBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecording ? Icons.mic : Icons.mic_off,
                        color: Colors.black,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Demo=====
enum _Speaker { user, butler }

class _ChatMessage {
  final _Speaker from;
  final String text;
  final String time;

  _ChatMessage({required this.from, required this.text, required this.time});
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.from == _Speaker.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isUser
                    ? kSeaBlue
                    : Colors.white12, 
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white24, 
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: GoogleFonts.itim(
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      message.time,
                      style: GoogleFonts.itim(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FakeSiriWave extends StatefulWidget {
  final bool active;
  const FakeSiriWave({super.key, required this.active});

  @override
  State<FakeSiriWave> createState() => _FakeSiriWaveState();
}

class _FakeSiriWaveState extends State<FakeSiriWave> {
  final List<double> _heights = [10, 20, 30, 20, 10];
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (!mounted || !widget.active) return;

      setState(() {
        for (int i = 0; i < _heights.length; i++) {
          _heights[i] = 8 + (i.isEven ? 22 : 14);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_heights.length, (i) {
          return Container(
            width: 6,
            height: widget.active ? _heights[i] : 10,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}

