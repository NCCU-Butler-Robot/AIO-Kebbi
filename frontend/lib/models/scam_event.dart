class ScamEvent {
  final String callId;
  final String transcript;
  final String riskLabel;     // e.g. low/medium/high/critical
  final double riskScore;     // 0.0 ~ 1.0
  final String suggestion;
  final DateTime time;

  final int? stage;

  ScamEvent({
    required this.callId,
    required this.transcript,
    required this.riskLabel,
    required this.riskScore,
    required this.suggestion,
    required this.time,
    this.stage,               

  });

  // 統一把 stage 轉成顯示字與「估算分數」
  static String _labelFromStage(int? s) =>
      s == null ? 'Non-fraud' : 'Stage $s';
  static double _scoreFromStage(int? s) =>
      s == null ? 0.0 : (s.clamp(0, 3) / 3.0);

  factory ScamEvent.fromJson(Map<String, dynamic> json) {
    final int? s = (json['fraud_stage'] is num) ? (json['fraud_stage'] as num).toInt() : null;
    return ScamEvent(
      callId:     (json['callId'] ?? json['call_id'] ?? '').toString(),
      transcript: (json['sentence'] ?? json['transcript'] ?? '').toString(),
      riskLabel:  s != null ? _labelFromStage(s) : (json['riskLabel'] ?? json['label'] ?? 'Non-fraud').toString(),
      riskScore:  s != null ? _scoreFromStage(s) : (json['riskScore'] ?? json['risk_score'] ?? 0).toDouble(),
      suggestion: (json['suggestion'] ?? json['llm_suggestion'] ?? '').toString(),
      time:       DateTime.tryParse((json['time'] ?? '').toString()) ?? DateTime.now(),
      stage:      s,
    );
  }

  factory ScamEvent.fromMock(Map<String, dynamic> data) {
    final int? s = (data['fraud_stage'] is num) ? (data['fraud_stage'] as num).toInt() : null;
    if (s != null) {
      return ScamEvent(
        callId:     (data['id'] ?? data['call_id'] ?? '').toString(),
        transcript: (data['sentence'] ?? data['transcript'] ?? '').toString(),
        riskLabel:  _labelFromStage(s),
        riskScore:  _scoreFromStage(s),
        suggestion: (data['suggestion'] ?? '').toString(),
        time:       DateTime.now(),
        stage:      s,
      );
    }
  
    final fa = (data['fraud_assessment'] as Map?) ?? const {};
    return ScamEvent(
      callId:     (data['call_id'] ?? '').toString(),
      transcript: (data['transcript'] ?? '').toString(),
      riskLabel:  (fa['label'] ?? 'Non-fraud').toString(),
      riskScore:  (fa['risk_score'] ?? 0).toDouble(),
      suggestion: (fa['llm_suggestion'] ?? '').toString(),
      time:       DateTime.now(),
      stage:      null,
    );
  }
}