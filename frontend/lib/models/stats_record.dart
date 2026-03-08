import 'scam_event.dart';

class StatsRecord {
  final String title;
  final DateTime time;
  final String decision;     
  final int? stage;          

  final String riskLabel;
  final double percent;

  StatsRecord({
    required this.title,
    required this.time,
    required this.decision,
    this.stage,
    this.riskLabel = '',
    this.percent = 0.0,
  });

  factory StatsRecord.fromEvent({
    required ScamEvent event,
    required String decision,
  }) {
    return StatsRecord(
      title: event.callId.isNotEmpty
          ? 'Call ${event.callId}'
          : 'Call ${event.time.toLocal().toString().split(".").first}',
      time: DateTime.now(),
      decision: decision,
      stage: event.stage,
      riskLabel: event.riskLabel,
      percent: event.stage == null ? 0.0 : (event.stage!.clamp(0, 3) / 3.0),
    );
  }
}
