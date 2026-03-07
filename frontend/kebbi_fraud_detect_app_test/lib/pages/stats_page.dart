import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../providers/call_provider.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  String _fmt(DateTime t) => t.toLocal().toString().split('.').first;

  // Stage 對色：非詐騙/未提供→綠；0黃、1橘、2紅、3深紅
  Color _stageColor(int? s) {
    if (s == null) return const Color(0xff4cab4f);
    switch (s) {
      case 0:
        return const Color(0xFFF7D154);
      case 1:
        return const Color(0xFFEA8526);
      case 2:
        return const Color(0xFFE74C3C);
      case 3:
        return const Color(0xFFC0392B);
      default:
        return const Color(0xFFE74C3C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<CallProvider>().stats;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: Text(
          'Stats',
          style: GoogleFonts.itim(fontSize: 24, color: textColor),
        ),
        actions: [
          if (stats.isNotEmpty)
            IconButton(
              tooltip: 'Clear statistics records',
              icon: const Icon(Icons.delete_outline),
              color: Colors.redAccent,
              onPressed: () {
                context.read<CallProvider>().clearStats();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Statistics records have been cleared')));
              },
            ),
        ],
      ),
      body: stats.isEmpty
          ? Center(
              child: Text(
                'There is currently no report record.\nPlease click the button below to report in Call Monitor.',
                textAlign: TextAlign.center,
                style: GoogleFonts.itim(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: stats.length,
              itemBuilder: (context, index) {
                final r = stats[index];
                final color = _stageColor(r.stage); // 以 stage 分色
                final stageText = r.stage == null ? 'Non-fraud' : 'Stage: ${r.stage}';
                final isFraud = r.decision == 'confirm_fraud';

                return Card(
                  color: iconColor,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: Icon(Icons.circle, size: 14, color: color),
                    title: Text(
                      r.title,
                      style: GoogleFonts.itim(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            // Stage 標籤
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha : 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                stageText,
                                style: GoogleFonts.itim(fontSize: 13, color: color),
                              ),
                            ),
                            // 使用者判定標籤
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isFraud ? Colors.red : Colors.green)
                                    .withValues(alpha : 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isFraud ? 'User judgment: fraud' : 'User judgment: not fraud',
                                style: GoogleFonts.itim(
                                  fontSize: 13,
                                  color: isFraud ? Colors.red : Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _fmt(r.time),
                          style: GoogleFonts.itim(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove this record',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        context.read<CallProvider>().removeStatAt(index);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('1 record removed')));
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
