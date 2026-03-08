/// WebSocket 通用訊息
/// 已支援常見型別：
/// - connection_success: 連線成功（帶 connection_id / client_uuid）
/// - scam_detection_started / ended: 監控開始／結束
/// - incoming_call_request: 來電請求（可帶 llm_only / caller 等）
/// - fraud_assessment: 單句判讀（sentence / fraud_stage / keywords_found）
/// - error: 伺服器錯誤訊息
///
/// 解析策略：優先看 `type`；若沒有，依欄位推斷（有 sentence/fraud_stage ⇒ fraud_assessment 等）
enum WsType {
  connectionSuccess,
  detectionStarted,
  detectionEnded,
  incomingCallRequest,
  fraudAssessment,
  scamDecision, // 保留：若後端未來真的會丟最終決策
  callAccepted,
  callDeclined,
  callEnded,
  error,
  unknown,
}

class WsMessage {
  final WsType type;
  final Map<String, dynamic> raw;

  // 便利欄位（可能為 null）
  final String? connectionId;
  final String? clientUuid;

  final String? sentence;
  final int? stage; // 0=非詐騙，1..3=風險階段
  final List<String> keywords;

  final bool? llmOnly;   // 來電是否僅由 LLM 應答（示例）
  final String? caller;  // 來電者（示例）

  final String? errorMessage;

  final String? callerId;        // 來電者的 uuid
  final String? targetUsername;  // 目標使用者 username
  final int? timeoutSeconds;     // 來電請求倒數秒數
  final int? fraudCount;         // （可選）詐騙命中的累計

  final String? callId; // 通話 ID（後端事件會帶上）


  WsMessage({
    required this.type,
    required this.raw,
    this.connectionId,
    this.clientUuid,
    this.sentence,
    this.stage,
    this.keywords = const <String>[],
    this.llmOnly,
    this.caller,
    this.errorMessage,
    this.callerId,
    this.targetUsername,
    this.timeoutSeconds,
    this.fraudCount,
    this.callId,

  });

  factory WsMessage.fromJson(Map<String, dynamic> j) {
    // 取 type（字串）；沒有就嘗試推斷
    final tStr = (j['type'] ?? j['event'] ?? '').toString().toLowerCase();

    WsType inferType() {
      if (tStr.contains('connection_success')) return WsType.connectionSuccess;
      if (tStr.contains('scam_detection_started')) return WsType.detectionStarted;
      if (tStr.contains('scam_detection_ended')) return WsType.detectionEnded;
      if (tStr.contains('incoming_call_request')) return WsType.incomingCallRequest;
      if (tStr.contains('fraud_assessment')) return WsType.fraudAssessment;
      if (tStr.contains('scam_decision')) return WsType.scamDecision;
      if (tStr.contains('error')) return WsType.error;
      if (tStr.contains('call_accepted')) return WsType.callAccepted;
      if (tStr.contains('call_declined')) return WsType.callDeclined;
      if (tStr.contains('call_ended'))    return WsType.callEnded;


      // 無 type：用欄位推斷
      if (j.containsKey('sentence') || j.containsKey('fraud_stage') || j.containsKey('stage')) {
        return WsType.fraudAssessment;
      }
      if (j.containsKey('connection_id') || j.containsKey('client_uuid')) {
        return WsType.connectionSuccess;
      }
      if (j.containsKey('error') || j.containsKey('message') && (j['status'] == 'error')) {
        return WsType.error;
      }
      return WsType.unknown;
    }

    final type = inferType();

    // 共同容錯取值
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    List<String> parseStrList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const <String>[];
    }

    final stage = parseInt(j['fraud_stage'] ?? j['stage']);
    final keywords = parseStrList(j['keywords_found'] ?? j['keywords']);

    return WsMessage(
      type: type,
      raw: j,
      connectionId: j['connection_id']?.toString(),
      clientUuid: j['client_uuid']?.toString(),
      sentence: j['sentence']?.toString(),
      stage: (stage == null || stage < 0 || stage > 3) ? null : stage,
      keywords: keywords,
      llmOnly: (j['llm_only'] is bool) ? j['llm_only'] as bool : (j['llm_only']?.toString().toLowerCase() == 'true'),
      caller: j['caller']?.toString(),

      callerId: j['caller_id']?.toString(),
      targetUsername: j['target_username']?.toString(),
      timeoutSeconds: parseInt(j['timeout']) ?? parseInt(j['timeout_seconds']),
      fraudCount: parseInt(j['fraud_count']),
      callId: j['call_id']?.toString(),

      errorMessage: j['error']?.toString() ?? j['message']?.toString(),
    );
  }
}
