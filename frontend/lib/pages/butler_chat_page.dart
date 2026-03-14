import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants.dart';
import '../di/service_locator.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';

class ButlerChatPage extends StatefulWidget {
  const ButlerChatPage({super.key});

  @override
  State<ButlerChatPage> createState() => _ButlerChatPageState();
}

class _ButlerChatPageState extends State<ButlerChatPage> {
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      from: _Speaker.butler,
      text: "Good evening. I'm your Butler. How can I help you today?",
      time: _fmtTime(DateTime.now()),
    ),
  ];

  String? _conversationId;
  bool _isLoading = false;
  bool _isRecording = false;
  String _liveTranscript = 'Tap mic to start recording...';

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    AudioService.I.init();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollCtrl.dispose();
    if (_isRecording) {
      AudioService.I.stopRecord();
    }
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // 停止錄音
      setState(() {
        _isRecording = false;
        _liveTranscript = 'Recording stopped.';
      });
      final file = await AudioService.I.stopRecord();
      // 語音轉文字尚未整合（需 STT 服務），目前停止後不自動送出
      if (file != null) {
        setState(() => _liveTranscript = 'Recording ready. Type or send text.');
      }
    } else {
      final granted = await AudioService.I.ensureMicPermission();
      if (!granted) {
        setState(() => _liveTranscript = 'Microphone permission denied.');
        return;
      }
      await AudioService.I.startRecord();
      setState(() {
        _isRecording = true;
        _liveTranscript = 'Listening…';
      });
    }
  }

  Future<void> _sendText() async {
    final txt = _textController.text.trim();
    if (txt.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(
          from: _Speaker.user, text: txt, time: _fmtTime(DateTime.now())));
      _textController.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final result = await sl<ApiService>().sendChat(
        prompt: txt,
        conversationId: _conversationId,
      );

      _conversationId = result.conversationId.isNotEmpty
          ? result.conversationId
          : _conversationId;

      setState(() {
        _messages.add(_ChatMessage(
          from: _Speaker.butler,
          text: result.text.isNotEmpty ? result.text : '(no response)',
          time: _fmtTime(DateTime.now()),
        ));
      });
      _scrollToBottom();

      if (result.audioBytes != null) {
        await AudioService.I.playMp3Bytes(result.audioBytes!);
      }
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          from: _Speaker.butler,
          text: 'Error: $e',
          time: _fmtTime(DateTime.now()),
        ));
      });
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String _fmtTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              // ===== 訊息列表 =====
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) =>
                      _ChatBubble(message: _messages[i]),
                ),
              ),

              // ===== 錄音狀態區 =====
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
                          fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    FakeSiriWave(active: _isRecording),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _isLoading ? 'Butler is thinking…' : _liveTranscript,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.itim(
                            fontSize: 15, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // ===== 輸入列 =====
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
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
                                style: GoogleFonts.itim(
                                    color: textColor, fontSize: 16),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Type a message...',
                                  hintStyle: GoogleFonts.itim(
                                      color: textColor, fontSize: 16),
                                ),
                                onSubmitted: (_) => _sendText(),
                              ),
                            ),
                            _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : IconButton(
                                    onPressed: _sendText,
                                    icon: const Icon(Icons.send,
                                        color: iconColor),
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 麥克風
                    InkWell(
                      onTap: _isLoading ? null : _toggleRecording,
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _isRecording
                              ? const Color(0xff29d97a)
                              : kSeaBlue,
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
      ),
    );
  }
}

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
    final maxW = MediaQuery.of(context).size.width * 0.75;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isUser ? kSeaBlue : Colors.white12,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: GoogleFonts.itim(fontSize: 16, color: textColor),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      message.time,
                      style: GoogleFonts.itim(
                          fontSize: 12, color: Colors.white70),
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
          _heights[i] = 8.0 +
              (20.0 *
                  (0.3 + 0.7 * ((DateTime.now().millisecondsSinceEpoch + i * 137) % 1000) / 1000.0));
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
