import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants.dart';
import '../di/service_locator.dart';
import '../models/fraud_models.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/kebbi_service.dart';
import '../services/web_speech_service.dart';
import '../widgets/ssci_panel.dart';
import 'monitor_page.dart';

class ButlerChatPage extends StatefulWidget {
  const ButlerChatPage({super.key});

  @override
  State<ButlerChatPage> createState() => _ButlerChatPageState();
}

class _ButlerChatPageState extends State<ButlerChatPage> {
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      from: _Speaker.butler,
      text: '請在下方輸入目標電話號碼後開始對話。\nAI 將扮演該號碼對應的用戶，同時監控詐騙風險指數。',
      time: _fmtTime(DateTime.now()),
    ),
  ];

  // 詐騙對話狀態
  String _phoneNumber = '';
  bool _conversationStarted = false;
  SsciData? _ssci;

  bool _isLoading = false;
  bool _isRecording = false;
  bool _isBusy = false;
  String _liveTranscript = 'Tap mic to start recording...';

  bool _autoSendOnResult = false;

  // STT backend: null = not yet detected, true = Kebbi NuwaSDK, false = Vosk
  bool? _useKebbi;

  // Vosk model state
  bool _voskModelReady = false;
  int? _voskDownloadProgress;

  // Microphone permission state
  bool _micPermissionGranted = false;
  bool _isPermanentlyDenied = false;

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    AudioService.I.init();
    KebbiService.setupCallbackHandler();
    KebbiService.setSTTCallback(_onSTTResult);
    KebbiService.setVoskProgressCallback(_onVoskProgress);

    if (kIsWeb) {
      WebSpeechService.I.setCallback(_onSTTResult);
    }

    _checkVoskModelCached();
    _checkMicPermission();
  }

  Future<void> _checkMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      setState(() {
        _micPermissionGranted = true;
        _isPermanentlyDenied = false;
      });
    } else if (status.isDenied) {
      final result = await Permission.microphone.request();
      setState(() {
        _micPermissionGranted = result.isGranted;
        _isPermanentlyDenied = false;
      });
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _micPermissionGranted = false;
        _isPermanentlyDenied = true;
      });
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  Future<void> _checkVoskModelCached() async {
    final ready = await KebbiService.isVoskModelReady();
    if (mounted && ready) setState(() => _voskModelReady = true);
  }

  @override
  void dispose() {
    KebbiService.setSTTCallback(null);
    KebbiService.setVoskProgressCallback(null);
    if (kIsWeb) {
      WebSpeechService.I.stopListening();
      WebSpeechService.I.setCallback(null);
    } else if (_useKebbi == true) {
      KebbiService.stopSTT();
    } else if (_useKebbi == false) {
      KebbiService.stopVoskSTT();
    }
    _textController.dispose();
    _phoneController.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Callbacks ────────────────────────────────────────────────────────────

  void _onSTTResult(String text, bool isFinal) {
    if (!mounted) return;

    if (isFinal) {
      setState(() {
        _isRecording = false;
        _liveTranscript = text.isNotEmpty ? text : 'No speech detected.';
        if (text.isNotEmpty) _textController.text = text;
      });

      if (_autoSendOnResult && text.isNotEmpty) {
        _autoSendOnResult = false;
        _sendText();
      } else {
        _autoSendOnResult = false;
      }
    } else {
      setState(() {
        _liveTranscript = text.isNotEmpty ? text : 'Listening…';
      });
    }
  }

  void _onVoskProgress(int percent) {
    if (!mounted) return;
    setState(() {
      _voskDownloadProgress = percent;
      _liveTranscript = percent == -1
          ? 'Extracting model…'
          : 'Downloading voice model… $percent%';
    });
  }

  // ── Recording toggle ──────────────────────────────────────────────────────

  Future<void> _startSTT() async {
    if (kIsWeb) {
      final ok = await WebSpeechService.I.startListening();
      if (!ok) {
        if (mounted) {
          setState(() {
            _isBusy = false;
            _liveTranscript = 'Web speech not available';
          });
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _isRecording = true;
        _liveTranscript = 'Listening…';
        _textController.clear();
      });
      _autoSendOnResult = true;
      return;
    }

    _useKebbi ??= await KebbiService.isKebbiAvailable();

    if (_useKebbi!) {
      try {
        await KebbiService.startSTT();
      } catch (e) {
        if (mounted) {
          setState(() {
            _isBusy = false;
            _liveTranscript = 'NuwaSDK STT error: $e';
          });
        }
        return;
      }
    } else {
      if (!_voskModelReady) {
        setState(() {
          _voskDownloadProgress = 0;
          _liveTranscript = 'Preparing voice model…';
        });

        try {
          await KebbiService.initVosk();
          setState(() {
            _voskModelReady = true;
            _voskDownloadProgress = null;
          });
        } catch (e) {
          if (mounted) {
            setState(() {
              _isBusy = false;
              _voskDownloadProgress = null;
              _liveTranscript = 'Model download failed: $e';
            });
          }
          return;
        }
      }

      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) {
          final isPermanentlyDenied =
              await Permission.microphone.isPermanentlyDenied;
          setState(() {
            _isBusy = false;
            _micPermissionGranted = false;
            _isPermanentlyDenied = isPermanentlyDenied;
            _liveTranscript = isPermanentlyDenied
                ? 'Microphone permission denied. Tap settings icon to open Settings.'
                : 'Microphone permission is required.';
          });
        }
        return;
      }
      _micPermissionGranted = true;
      _isPermanentlyDenied = false;

      await KebbiService.startVoskSTT();
    }

    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _isRecording = true;
      _liveTranscript = 'Listening…';
      _textController.clear();
    });
    _autoSendOnResult = true;
  }

  Future<void> _toggleRecording() async {
    if (_isLoading || _isBusy) return;

    if (_isRecording) {
      _autoSendOnResult = false;

      if (kIsWeb) {
        await WebSpeechService.I.stopListening();
      } else if (_useKebbi == true) {
        await KebbiService.stopSTT();
      } else {
        await KebbiService.stopVoskSTT();
      }

      setState(() {
        _isRecording = false;
        _liveTranscript = _textController.text.isNotEmpty
            ? _textController.text
            : 'Tap mic to start recording...';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _liveTranscript = 'Starting microphone…';
    });

    try {
      await _startSTT();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isRecording = false;
          _autoSendOnResult = false;
          _liveTranscript = 'Mic error: $e';
        });
      }
    }
  }

  // ── 確認電話號碼 ────────────────────────────────────────────────────────────

  void _confirmPhone() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    setState(() {
      _phoneNumber = phone;
    });
  }

  // ── 傳送文字至詐騙 API ─────────────────────────────────────────────────────

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

  Future<void> _sendText() async {
    final txt = _textController.text.trim();
    if (txt.isEmpty || _isLoading) return;
    if (_phoneNumber.isEmpty) return;

    // 停止 STT
    if (kIsWeb) {
      await WebSpeechService.I.stopListening();
    } else if (_useKebbi == true) {
      await KebbiService.stopSTT();
    } else if (_useKebbi == false) {
      await KebbiService.stopVoskSTT();
    }

    setState(() {
      _messages.add(_ChatMessage(
          from: _Speaker.user, text: txt, time: _fmtTime(DateTime.now())));
      _textController.clear();
      _isLoading = true;
      _isRecording = false;
      _liveTranscript = 'AI 思考中…';
    });
    _scrollToBottom();

    try {
      final result = await sl<ApiService>().sendFraud(
        prompt: txt,
        phoneNumber: _phoneNumber,
        isFirst: !_conversationStarted,
      );

      // 標記對話已開始
      if (!_conversationStarted) {
        setState(() => _conversationStarted = true);
      }

      // 處理特殊狀態
      if (result.isInitiateSocketIo) {
        _handleInitiateSocketIo(result);
        return;
      }

      // 更新 SSCI（只在 updated=true 時觸發動畫）
      setState(() {
        _messages.add(_ChatMessage(
          from: _Speaker.butler,
          text: result.message.isNotEmpty ? result.message : '(no response)',
          time: _fmtTime(DateTime.now()),
        ));
        _liveTranscript = 'Tap mic to start recording...';
        if (result.ssci.available || !result.ssci.updated) {
          _ssci = result.ssci;
        } else {
          _ssci = result.ssci;
        }
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          from: _Speaker.butler,
          text: 'Error: $e',
          time: _fmtTime(DateTime.now()),
        ));
        _liveTranscript = 'Tap mic to start recording...';
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _handleInitiateSocketIo(FraudResult result) {
    if (!mounted) return;

    final reason = result.reason ?? '';
    final msg = reason == 'ssci_below_threshold_normal_conversation'
        ? '判定為正常通話，已通知真實用戶接手。'
        : 'SSCI 無法計算，已預設通知真實用戶。';

    setState(() {
      _ssci = result.ssci;
      _isLoading = false;
      _messages.add(_ChatMessage(
        from: _Speaker.butler,
        text: '[系統] $msg',
        time: _fmtTime(DateTime.now()),
      ));
      _liveTranscript = 'Tap mic to start recording...';
    });
    _scrollToBottom();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A38),
        title: Text(
          '切換至即時監控',
          style: GoogleFonts.itim(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          '$msg\n\n即將建立即時通話連線...',
          style: GoogleFonts.itim(color: Colors.white70, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 關閉 dialog
              // 導到 MonitorPage，帶入 call_token 自動建立 Socket.IO 連線
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => MonitorPage(callToken: result.callToken),
                ),
              );
            },
            child: Text(
              '切換監控',
              style: GoogleFonts.itim(color: kSeaBlue),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 只關閉 dialog，留在此頁
            },
            child: Text(
              '取消',
              style: GoogleFonts.itim(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: Text(
          _phoneNumber.isEmpty
              ? '反詐騙 AI'
              : '反詐騙 AI · $_phoneNumber',
          style: GoogleFonts.itim(fontSize: 20, color: textColor),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              // ===== 電話號碼設定區（未設定時顯示）=====
              if (_phoneNumber.isEmpty) _buildPhoneSetup(),

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

              // ===== SSCI 面板 =====
              if (_phoneNumber.isNotEmpty)
                SsciPanel(ssci: _ssci),

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

                    // Vosk 下載進度條
                    if (_voskDownloadProgress != null &&
                        _voskDownloadProgress! >= 0) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _voskDownloadProgress! / 100,
                            minHeight: 6,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xff29d97a)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

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
                                enabled: _phoneNumber.isNotEmpty,
                                style: GoogleFonts.itim(
                                    color: textColor, fontSize: 16),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: _phoneNumber.isEmpty
                                      ? '請先設定電話號碼'
                                      : 'Type a message...',
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
                                    onPressed: _phoneNumber.isNotEmpty
                                        ? _sendText
                                        : null,
                                    icon: Icon(Icons.send,
                                        color: _phoneNumber.isNotEmpty
                                            ? iconColor
                                            : Colors.grey),
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 麥克風
                    InkWell(
                      onTap: () async {
                        if (_isLoading || _isBusy) return;
                        if (_phoneNumber.isEmpty) return;
                        if (_isPermanentlyDenied && !_micPermissionGranted) {
                          _openSettings();
                        } else {
                          _toggleRecording();
                        }
                      },
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _isRecording
                              ? const Color(0xff29d97a)
                              : _isBusy || _phoneNumber.isEmpty
                                  ? Colors.grey
                                  : kSeaBlue,
                          shape: BoxShape.circle,
                        ),
                        child: _isBusy
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Icon(
                                (_isPermanentlyDenied &&
                                            !_micPermissionGranted)
                                    ? Icons.settings
                                    : (_isRecording
                                        ? Icons.mic
                                        : (_micPermissionGranted
                                            ? Icons.mic
                                            : Icons.mic_off)),
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

  Widget _buildPhoneSetup() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone, color: Colors.white54, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.itim(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '輸入目標電話號碼（如 0911000001）',
                hintStyle:
                    GoogleFonts.itim(color: Colors.white38, fontSize: 14),
                isDense: true,
              ),
              onSubmitted: (_) => _confirmPhone(),
            ),
          ),
          TextButton(
            onPressed: _confirmPhone,
            child: Text(
              '確認',
              style: GoogleFonts.itim(color: kSeaBlue, fontSize: 15),
            ),
          ),
        ],
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
                    style:
                        GoogleFonts.itim(fontSize: 16, color: textColor),
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
