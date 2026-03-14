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
  // =========================
  static const String apiBaseUrl = 'https://vision.futuremedialab.tw:1688';

  static const String baseUrl = apiBaseUrl;

  // ---- REST paths (依你 Postman 截圖) ----
  static const String loginPath = '/auth/login';
  static const String statusPath = '/auth/status';
  static const String chatPath = '/api/chat/';
  static const String foodRecognitionPath = '/api/food-recognition/';
  static const String hangupPath = '/api/hangup';
  static const String logoutPath = '/auth/logout';

  // =========================

  // =========================
  static const String socketBaseUrl = 'https://vision.futuremedialab.tw:1688';

  static const String wsBase = 'wss://vision.futuremedialab.tw:1688';

  // =========================
  // Common headers / device id
  // =========================
  static const String installationIdHeader = 'X-Installation-Id';

  static const String defaultInstallationId = 'device001';

  static const bool devBypassLogin = false;

// 給一個假 token，後端開了再改回 false
  static const String devFakeAccessToken = 'dev-fake-token';
}
