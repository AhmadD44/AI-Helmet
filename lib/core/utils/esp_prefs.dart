import 'package:shared_preferences/shared_preferences.dart';

class EspPrefs {
  static const _kMac = 'esp_mac';

  static Future<void> saveMac(String mac) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kMac, mac);
  }

  static Future<String?> loadMac() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kMac);
  }

  static Future<void> clearMac() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kMac);
  }
}
