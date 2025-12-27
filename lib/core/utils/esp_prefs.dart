import 'package:shared_preferences/shared_preferences.dart';

class EspPrefs {
  static const _key = 'esp_mac';

  static Future<void> saveMac(String mac) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, mac);
  }

  static Future<String?> loadMac() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_key);
  }

  static Future<void> clearMac() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
