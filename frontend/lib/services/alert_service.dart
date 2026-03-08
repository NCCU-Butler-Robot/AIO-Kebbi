import 'package:audioplayers/audioplayers.dart';
import '../services/kebbi_service.dart';

class AlertService {
  AlertService._();

  static final AudioPlayer _player = AudioPlayer();

  static Future<void> _beep() async {
    try {
      // 播放 assets/sounds/alert.mp3
      await _player.play(AssetSource('sounds/alert.mp3'));
    } catch (_) {}
  }

  static Future<void> _isFraud() async {
    try {
      // 播放 assets/sounds/Fraud.mp3
      await _player.play(AssetSource('sounds/Fraud.mp3'));
    } catch (_) {}
  }

  static Future<void> _notFraud() async {
    try {
      // 播放 assets/sounds/Not_Fraud.mp3
      await _player.play(AssetSource('sounds/Not_Fraud.mp3'));
    } catch (_) {}
  }

  /// 詐騙
  static Future<void> fraudAlert() async {
    await Future.wait([
      _beep(),
      _isFraud(),
    ]);
     await KebbiService.doFraudAction();     
  }

  /// 非詐騙
  static Future<void> safeAlert() async {
    await Future.wait([
      _beep(),
      _notFraud(),
    ]);
    await KebbiService.doSafeAction();    

  }
  static Future<void> alert() async {
    await Future.wait([
      _beep(),
    ]);
  }

}
