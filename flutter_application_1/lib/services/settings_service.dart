import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyApiUrl        = 'api_base_url';
  static const _keyFeedThreshold = 'feed_threshold';
  static const _keyWaterThreshold = 'water_threshold';
  static const _keyPetList       = 'pet_list'; // 用來儲存寵物列表的 Key

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
      // 讀取寵物列表，如果沒有存過就給一個空的列表 []
      'petList':        prefs.getStringList(_keyPetList)    ?? <String>[], 
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

  /// 儲存整份寵物名單
  static Future<void> savePetList(List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyPetList, list);
  }
}
