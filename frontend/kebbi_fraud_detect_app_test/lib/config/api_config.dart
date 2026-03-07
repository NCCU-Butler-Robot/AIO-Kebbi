class ApiConfig {
  ApiConfig._();

  // =========================
  // Feature flags
  // =========================
  static const bool mockLogin = false;
  static const Duration mockDelay = Duration(milliseconds: 600);

  static const bool mockWs = false;
  static const Duration mockWsInterval = Duration(seconds: 2);

  // =========================
  // REST API（登入 / chat / food / hangup / logout）
  // 這個一定要指向「真正提供 /api/login 的後端」
  // =========================
  static const String apiBaseUrl = 'https://scamdemo.dddanielliu.com';

  /// 你現有 ApiService 用的是 baseUrl 這個名字，所以保留
  static const String baseUrl = apiBaseUrl;

  // ---- REST paths (依你 Postman 截圖) ----
  static const String loginPath = '/api/login';
  static const String chatPath = '/api/chat/';
  static const String foodRecognitionPath = '/api/food-recognition/';
  static const String hangupPath = '/api/hangup';
  static const String logoutPath = '/auth/logout';

  // =========================
  // Socket / WebSocket（Daniel 說換的路由）
  // 你之後做 socket.io / audio_chunk 會用到
  // =========================
  static const String socketBaseUrl = 'https://vision.futuremedialab.tw:1688';

  /// 你目前的 WebSocketService 用的是 wsBase 這個名字，所以保留
  /// 它會組出：wss://host:port/ws/{uuid}?token=...
  static const String wsBase = 'wss://vision.futuremedialab.tw:1688';

  // =========================
  // Common headers / device id
  // =========================
  static const String installationIdHeader = 'X-Installation-Id';

  /// 先給你一個預設值（你之後也可以改成從裝置真實生成/儲存）
  static const String defaultInstallationId = 'device001';

  // 開發用：後端沒開時先讓 app 能往下走
  static const bool devBypassLogin = true;

// 給一個假 token，後端開了再改回 false
  static const String devFakeAccessToken = 'dev-fake-token';
}
