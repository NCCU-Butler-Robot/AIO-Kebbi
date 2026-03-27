import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/fraud_models.dart';

const Color _scamColor = Color(0xFFE74C3C);
const Color _safeColor = Color(0xFF27AE60);

class SsciPanel extends StatefulWidget {
  final SsciData? ssci;

  const SsciPanel({super.key, required this.ssci});

  @override
  State<SsciPanel> createState() => _SsciPanelState();
}

class _SsciPanelState extends State<SsciPanel> with TickerProviderStateMixin {
  late AnimationController _controller;

  double _fromConfidence = 0;
  double _fromEvidence = 0;
  double _fromAgreement = 0;
  double _fromStability = 0;

  late Animation<double> _confidenceAnim;
  late Animation<double> _evidenceAnim;
  late Animation<double> _agreementAnim;
  late Animation<double> _stabilityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _buildAnimations(0, 0, 0, 0);
  }

  void _buildAnimations(double c, double e, double a, double s) {
    _confidenceAnim = Tween<double>(begin: _fromConfidence, end: c)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _evidenceAnim = Tween<double>(begin: _fromEvidence, end: e)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _agreementAnim = Tween<double>(begin: _fromAgreement, end: a)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _stabilityAnim = Tween<double>(begin: _fromStability, end: s)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(SsciPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ssci = widget.ssci;
    if (ssci == null || !ssci.available || !ssci.updated) return;

    final c = ssci.confidence ?? 0;
    final e = ssci.evidence ?? 0;
    final a = ssci.agreement ?? 0;
    final s = ssci.stability ?? 0;

    _buildAnimations(c, e, a, s);
    _controller.forward(from: 0);

    _fromConfidence = c;
    _fromEvidence = e;
    _fromAgreement = a;
    _fromStability = s;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ssci = widget.ssci;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '詐騙風險指數 SSCI',
            style: GoogleFonts.itim(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          if (ssci == null || !ssci.available)
            _buildUnavailable()
          else
            _buildAvailable(ssci),
        ],
      ),
    );
  }

  Widget _buildUnavailable() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              color: Colors.white38, strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Text(
          '分析中...',
          style: GoogleFonts.itim(fontSize: 16, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildAvailable(SsciData ssci) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final displayScore = (_confidenceAnim.value * 100).round();
        final isScam = displayScore > 65;
        final color = isScam ? _scamColor : _safeColor;

        return Column(
          children: [
            // 主分數 + 狀態 badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$displayScore',
                  style: GoogleFonts.itim(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        isScam ? '疑似詐騙' : '正常通話',
                        style:
                            GoogleFonts.itim(fontSize: 14, color: color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '/ 100',
                      style: GoogleFonts.itim(
                          fontSize: 13, color: Colors.white38),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 三個環形圖
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RingChart(
                  label: '證據量',
                  value: _evidenceAnim.value,
                  color: const Color(0xFF3498DB),
                ),
                _RingChart(
                  label: '一致性',
                  value: _agreementAnim.value,
                  color: const Color(0xFF9B59B6),
                ),
                _RingChart(
                  label: '穩定度',
                  value: _stabilityAnim.value,
                  color: const Color(0xFFF39C12),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 計數器
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Counter(label: '累計句數', value: ssci.nK ?? 0),
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.white24,
                ),
                _Counter(label: '觸發次數', value: ssci.triggerCount),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RingChart extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _RingChart({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: CustomPaint(
            painter: _RingPainter(value: value, color: color),
            child: Center(
              child: Text(
                '${(value * 100).round()}%',
                style: GoogleFonts.itim(fontSize: 13, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.itim(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;

  _RingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;

    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * value.clamp(0.0, 1.0),
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;

  const _Counter({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: GoogleFonts.itim(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.itim(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }
}
