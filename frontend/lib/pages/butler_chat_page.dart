import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

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

  // Speech-to-text
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  // true → auto-send when silence detected; false → manual stop, just fill text field
  bool _autoSendOnResult = false;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    AudioService.I.init();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    // Silent initialization at page load — no permission dialog yet
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => _isRecording = false);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isRecording = false;
            _autoSendOnResult = false;
            _liveTranscript = 'Voice error: ${error.errorMsg}';
          });
        }
      },
    );
    if (mounted) setState(() {});
  }

  /// Request mic permission and (re-)initialize STT if needed.
  /// Called lazily the first time the user taps the mic button.
  Future<bool> _ensureSpeechReady() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      if (mounted) setState(() => _liveTranscript = 'Microphone permission denied.');
      return false;
    }
    // Re-initialize if the silent init at page load failed (e.g. permission
    // was not yet granted at that point).
    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && mounted) {
            setState(() => _isRecording = false);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isRecording = false;
              _autoSendOnResult = false;
              _liveTranscript = 'Voice error: ${error.errorMsg}';
            });
          }
        },
      );
    }
    if (!_speechAvailable) {
      if (mounted) setState(() => _liveTranscript = 'Speech recognition not available on this device.');
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    _speech.cancel();
    _textController.dispose();
    _scrollCtrl.dispose();
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
    if (_isLoading) return;

    if (_isRecording) {
      // Manual stop → fill text field but DON'T auto-send
      _autoSendOnResult = false;
      await _speech.stop();
      setState(() {
        _isRecording = false;
        _liveTranscript = _textController.text.isNotEmpty
            ? _textController.text
            : 'Tap mic to start recording...';
      });
      return;
    }

    // Request permission and (re-)initialize lazily on first tap
    final ready = await _ensureSpeechReady();
    if (!ready) return;

    setState(() {
      _isRecording = true;
      _liveTranscript = 'Listening…';
      _textController.clear();
    });

    _autoSendOnResult = true;

    final started = await _speech.listen(
      onResult: (result) {
        if (!mounted) return;

        if (result.finalResult) {
          final words = result.recognizedWords;
          setState(() {
            _isRecording = false;
            _liveTranscript =
                words.isNotEmpty ? words : 'No speech detected.';
            if (words.isNotEmpty) _textController.text = words;
          });

          // Auto-send only when silence detection triggered (not manual stop)
          if (_autoSendOnResult && words.isNotEmpty) {
            _autoSendOnResult = false;
            _sendText();
          } else {
            _autoSendOnResult = false;
          }
        } else {
          // Live transcript while speaking
          setState(() {
            _liveTranscript = result.recognizedWords.isNotEmpty
                ? result.recognizedWords
                : 'Listening…';
          });
        }
      },
      pauseFor: const Duration(seconds: 2),
      listenFor: const Duration(seconds: 30),
      listenOptions: SpeechListenOptions(partialResults: true),
    );

    // listen() returns false if it couldn't start
    if (!started && mounted) {
      setState(() {
        _isRecording = false;
        _autoSendOnResult = false;
        _liveTranscript = 'Could not start recording. Please try again.';
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
      _liveTranscript = 'Butler is thinking…';
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
        _liveTranscript = 'Tap mic to start recording...';
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
        _liveTranscript = 'Tap mic to start recording...';
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
                        _liveTranscript,
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
                  (0.3 +
                      0.7 *
                          ((DateTime.now().millisecondsSinceEpoch + i * 137) %
                              1000) /
                          1000.0));
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
