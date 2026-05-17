import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyPetList       = 'pet_list'; 

  static const String _defaultApiUrl        = 'http://137.184.181.86:8000/';
  static const double _defaultFeedThreshold  = 20.0;
  static const double _defaultWaterThreshold = 15.0;

  // 1. 讀取與儲存寵物「名單」（App 啟動時用）
  static Future<List<String>> loadPetList() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyPetList) ?? <String>[];
  }

  static Future<void> savePetList(List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyPetList, list);
  }

  // 2. 讀取「特定寵物」的專屬設定（點擊進入儀表板前呼叫）
  static Future<Map<String, dynamic>> loadPetSettings(String petName) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'apiUrl':         prefs.getString('api_base_url_$petName') ?? _defaultApiUrl,
      'feedThreshold':  prefs.getDouble('feed_threshold_$petName') ?? _defaultFeedThreshold,
      'waterThreshold': prefs.getDouble('water_threshold_$petName') ?? _defaultWaterThreshold,
    };
  }

  // 3. 儲存「特定寵物」的專屬設定
  static Future<void> saveApiUrl(String petName, String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url_$petName', url);
  }

  static Future<void> saveFeedThreshold(String petName, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('feed_threshold_$petName', value);
  }

  static Future<void> saveWaterThreshold(String petName, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('water_threshold_$petName', value);
  }
}