class SsciData {
  final bool available;
  final bool updated;
  final int rawInferenceCount;
  final int triggerCount;
  final double? confidence;
  final double? evidence;
  final double? agreement;
  final double? stability;
  final int? nK;
  final bool? latestTriggerDecision;

  const SsciData({
    required this.available,
    required this.updated,
    required this.rawInferenceCount,
    required this.triggerCount,
    this.confidence,
    this.evidence,
    this.agreement,
    this.stability,
    this.nK,
    this.latestTriggerDecision,
  });

  factory SsciData.fromJson(Map<String, dynamic> json) {
    return SsciData(
      available: json['available'] as bool? ?? false,
      updated: json['updated'] as bool? ?? false,
      rawInferenceCount: json['raw_inference_count'] as int? ?? 0,
      triggerCount: json['trigger_count'] as int? ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble(),
      evidence: (json['evidence'] as num?)?.toDouble(),
      agreement: (json['agreement'] as num?)?.toDouble(),
      stability: (json['stability'] as num?)?.toDouble(),
      nK: json['n_k'] as int?,
      latestTriggerDecision: json['latest_trigger_decision'] as bool?,
    );
  }
}

class FraudResult {
  final String? status;
  final String? callToken;
  final String? reason;
  final String message;
  final String messageId;
  final String conversationId;
  final SsciData ssci;

  const FraudResult({
    this.status,
    this.callToken,
    this.reason,
    required this.message,
    required this.messageId,
    required this.conversationId,
    required this.ssci,
  });

  bool get isInitiateSocketIo => status == 'initiate_socketio';

  factory FraudResult.fromJson(Map<String, dynamic> json) {
    return FraudResult(
      status: json['status'] as String?,
      callToken: json['call_token'] as String?,
      reason: json['reason'] as String?,
      message: json['message'] as String? ?? '',
      messageId: json['message_id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      ssci: SsciData.fromJson(
        json['ssci'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
