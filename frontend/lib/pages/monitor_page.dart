// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../providers/call_provider.dart';
import '../services/alert_service.dart';
import '../services/fcm_service.dart';
import '../services/kebbi_service.dart';
import '../providers/auth_provider.dart';
import 'call_page.dart';

class MonitorPage extends StatefulWidget {
  /// 從 initiate_socketio 或 FCM 點通知收到的 call_token
  final String? callToken;

  const MonitorPage({super.key, this.callToken});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  StreamSubscription<CallDecision>? _decSub;
  StreamSubscription<UiNotice>? _noticeSub;

  bool _bound = false;
  bool _showDebug = false;

  ScaffoldMessengerState? _messenger;

  Color _stageColor(int? s) {
    final v = s ?? -1;
    if (v <= 0) return const Color(0xff4cab4f); // green
    if (v == 1) return const Color(0xfff2c037); // yellow
    if (v == 2) return const Color(0xffea8526); // orange
    return const Color(0xfff7433c); // red (>= 3)
  }

  String _fmt(DateTime t) => t.toLocal().toString().split('.').first;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bound) return;
    _bound = true;

    _messenger = ScaffoldMessenger.maybeOf(context);

    // 每次進入頁面時從 SharedPreferences 補讀背景通知（App 從背景恢復時 initialize 不會重跑）
    FcmService.I.loadPersistedNotif();

    // 若帶有 callToken，自動建立 Socket.IO 連線
    final callToken = widget.callToken;
    if (callToken != null && callToken.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final cp = context.read<CallProvider>();
        final auth = context.read<AuthProvider>();
        final token = auth.token;
        final uuid = auth.uuid;
        if (token != null && token.isNotEmpty && uuid != null && uuid.isNotEmpty) {
          await cp.startMonitoring(token: token, uuid: uuid, callToken: callToken);
        }
      });
    }

    // 3-minute decision stream
    _decSub = context.read<CallProvider>().decisions.listen((d) async {
      if (!mounted) return;
      final messenger = _messenger;
      if (messenger == null) return;

      if (!mounted) return;

      if (d.type == CallDecisionType.fraudBlocked) {
        await AlertService.fraudAlert();
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('Suspected fraud call blocked'),
            content: Text('High-risk content detected. Please stay alert.'),
          ),
        );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Risk reminder completed')),
        );
      }
       else {
        await AlertService.safeAlert();
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('Call is safe'),
            content: Text('Risk threshold not reached. Call was transferred.'),
          ),
        );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Call transfer completed')),
        );
      }
    });

    // General UI notices
    _noticeSub = context.read<CallProvider>().notices.listen((n) {
      if (!mounted) return;
      final messenger = _messenger;
      if (messenger == null) return;

      messenger.showSnackBar(SnackBar(content: Text(n.message)));

      // If the other side accepted the call, navigate to call page
      if (n.type == UiNoticeType.callAccepted) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CallPage()),
        );
      }
    });
  }

  Widget _buildFcmNotifCard() {
    return ValueListenableBuilder<List<FcmNotifData>>(
      valueListenable: FcmService.I.notifHistory,
      builder: (_, history, __) {
        if (history.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('推播通知紀錄 (${history.length})',
                style: GoogleFonts.itim(fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            ...history.reversed.map(_buildSingleNotif),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }

  Widget _buildSingleNotif(FcmNotifData notif) {
    final encoder = const JsonEncoder.withIndent('  ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xffe8f4fd),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff90caf9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, size: 16, color: Color(0xff1565c0)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  notif.title ?? '來電通知',
                  style: GoogleFonts.itim(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff1565c0)),
                ),
              ),
            ],
          ),
          if (notif.body != null && notif.body!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(notif.body!,
                style: GoogleFonts.itim(fontSize: 13, color: const Color(0xff1a237e))),
          ],
          const SizedBox(height: 6),
          Text('data:',
              style: GoogleFonts.itim(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xfff0f4f8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              encoder.convert(notif.data),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingCallCard(BuildContext context) {
    final inc = context.watch<CallProvider>().incoming;

    // No incoming call
    if (inc == null) return const SizedBox.shrink();

    // Expired -> clear on next frame and hide
    if (inc.expired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<CallProvider>().clearIncoming();
      });
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xfffff3cd),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffffeeba)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.call, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                inc.llmOnly
                    ? 'Suspected fraud: AI will continue to answer'
                    : 'Incoming call request: Answer?',
                style: GoogleFonts.itim(fontSize: 16, color: textColor),
              ),
              const Spacer(),
              Text(
                '${inc.remainingSeconds}s',
                style: GoogleFonts.itim(fontSize: 14, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final messenger = _messenger;
                  if (messenger == null) return;

                  final cp = context.read<CallProvider>();
                  await cp.acceptCall();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Accepted call')),
                  );
                },
                child: Text('Accept', style: GoogleFonts.itim(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () async {
                  final messenger = _messenger;
                  if (messenger == null) return;

                  final cp = context.read<CallProvider>();
                  await cp.declineCall(reason: 'busy');
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Rejected call')),
                  );
                },
                child: Text('Reject', style: GoogleFonts.itim(color: textColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _decSub?.cancel();
    _noticeSub?.cancel();
    _decSub = null;
    _noticeSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = context.watch<CallProvider>();
    final e = call.latest;

    final statusText =
        call.monitoring && call.connected ? 'Connected' : 'Disconnected';
    final statusColor = statusText == 'Connected' ? Colors.green : Colors.grey;

    // Latest WS message keywords
    final keywords = call.lastMsg?.keywords ?? const <String>[];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: Text('Call Monitor',
            style: GoogleFonts.itim(fontSize: 24, color: textColor)),
        actions: [
          IconButton(
            tooltip: _showDebug ? 'Hide Debug' : 'Show Debug',
            onPressed: () => setState(() => _showDebug = !_showDebug),
            icon: Icon(
              _showDebug ? Icons.bug_report : Icons.bug_report_outlined,
              color: _showDebug ? Colors.redAccent : Colors.grey,
            ),
          ),
          if (!call.monitoring)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: buttonColor),
              onPressed: () async {
                final cp = context.read<CallProvider>();
                final auth = context.read<AuthProvider>();
                final messenger = _messenger ?? ScaffoldMessenger.of(context);

                final token = auth.token;
                final uuid = auth.uuid;

                if (token == null ||
                    token.isEmpty ||
                    uuid == null ||
                    uuid.isEmpty) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text('Not logged in or token/uuid missing')));
                  return;
                }

                await KebbiService.init();
                if (!mounted) return;

                messenger
                    .showSnackBar(const SnackBar(content: Text('Starting monitoring...')));

                await cp.startMonitoring(
                    token: token, uuid: uuid,
                    callToken: widget.callToken);
                await cp.startMicStream();

                await Future.delayed(const Duration(milliseconds: 300));
                cp.wsSend('hello from echo ${DateTime.now().toIso8601String()}');
              },
              child: const Text('Start'),
            )
          else
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                final cp = context.read<CallProvider>();
                final messenger = _messenger ?? ScaffoldMessenger.of(context);

                await cp.stopMicStream();
                await cp.stopMonitoring();

                if (!mounted) return;
                messenger
                    .showSnackBar(const SnackBar(content: Text('Monitoring stopped')));
              },
              child: const Text('Stop'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection info row
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: statusColor),
                const SizedBox(width: 6),
                Text(statusText,
                    style: GoogleFonts.itim(fontSize: 14, color: statusColor)),
                const Spacer(),
                if (call.connectionId != null)
                  Text('ConnID: ${call.connectionId}',
                      style: GoogleFonts.itim(fontSize: 12, color: textColor)),
                const SizedBox(width: 12),
                if (call.clientUuid != null)
                  Text('UUID: ${call.clientUuid}',
                      style: GoogleFonts.itim(fontSize: 12, color: textColor)),
              ],
            ),
            const SizedBox(height: 12),

            _buildFcmNotifCard(),
            _buildIncomingCallCard(context),

            // Transcript
            Text('Transcript:',
                style: GoogleFonts.itim(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: (e == null || e.transcript.isEmpty)
                  ? Center(
                      child: Text(
                        call.monitoring
                            ? 'Waiting for the call...'
                            : 'Monitoring has not started yet',
                        style:
                            GoogleFonts.itim(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Text(
                        e.transcript,
                        style: GoogleFonts.itim(fontSize: 18, color: textColor),
                      ),
                    ),
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Text('Events: ${call.history.length}',
                    style: GoogleFonts.itim(
                        fontSize: 14, color: Colors.grey.shade700)),
                const SizedBox(width: 16),
                if (e != null)
                  Text('Last update: ${_fmt(e.time)}',
                      style: GoogleFonts.itim(
                          fontSize: 14, color: Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 16),

            if (e != null) ...[
              // Stage Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: _stageColor(e.stage).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _stageColor(e.stage), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield, color: _stageColor(e.stage)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (e.stage ?? 0) <= 0 ? 'Non-fraud' : 'Stage: ${e.stage}',
                        style: GoogleFonts.itim(
                          fontSize: 16,
                          color: _stageColor(e.stage),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (keywords.isNotEmpty)
                Text('Keywords: ${keywords.join(", ")}',
                    style: GoogleFonts.itim(fontSize: 14, color: textColor)),
            ],

            // Debug panel (latest WS message)
            if (_showDebug) ...[
              const SizedBox(height: 12),
              Text('Debug (latest WS message)',
                  style: GoogleFonts.itim(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xfff4f4f4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: call.lastMsg == null
                    ? Text('—',
                        style:
                            GoogleFonts.itim(fontSize: 13, color: Colors.grey))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('type: ${call.lastMsg!.type}',
                              style: GoogleFonts.itim(fontSize: 13)),
                          if (call.lastMsg!.sentence != null)
                            Text('sentence: ${call.lastMsg!.sentence}',
                                style: GoogleFonts.itim(fontSize: 13)),
                          if (call.lastMsg!.stage != null)
                            Text('stage: ${call.lastMsg!.stage}',
                                style: GoogleFonts.itim(fontSize: 13)),
                          if (call.lastMsg!.keywords.isNotEmpty)
                            Text(
                              'keywords: ${call.lastMsg!.keywords.join(", ")}',
                              style: GoogleFonts.itim(fontSize: 13),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            const JsonEncoder.withIndent('  ')
                                .convert(call.lastMsg!.raw),
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 11),
                          ),
                        ],
                      ),
              ),
            ],

            const Spacer(),

            // Demo buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    final messenger = _messenger ?? ScaffoldMessenger.of(context);
                    await AlertService.alert();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Demo response: confirm_fraud')),
                    );
                  },
                  child: Text('Confirm Fraud',
                      style: GoogleFonts.itim(color: Colors.white)),
                ),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    final messenger = _messenger ?? ScaffoldMessenger.of(context);
                    await AlertService.alert();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Demo response: not fraud')),
                    );
                  },
                  child: Text('Not Fraud',
                      style: GoogleFonts.itim(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
