import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyApiUrl        = 'api_base_url';
  static const _keyFeedThreshold = 'feed_threshold';
  static const _keyWaterThreshold = 'water_threshold';

  static const String _defaultApiUrl        = 'http://137.184.181.86:8000/';
  static const double _defaultFeedThreshold  = 20.0;
  static const double _defaultWaterThreshold = 15.0;

  /// 讀取所有設定，回傳 Map。APP 啟動時呼叫一次。
  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'apiUrl':         prefs.getString(_keyApiUrl)         ?? _defaultApiUrl,
      'feedThreshold':  prefs.getDouble(_keyFeedThreshold)  ?? _defaultFeedThreshold,
      'waterThreshold': prefs.getDouble(_keyWaterThreshold) ?? _defaultWaterThreshold,
    };
  }

  static Future<void> saveApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiUrl, url);
  }

  static Future<void> saveFeedThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFeedThreshold, value);
  }

  static Future<void> saveWaterThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyWaterThreshold, value);
  }
}
