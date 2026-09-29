import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 게임 저장 데이터와 언어 설정을 기기에 저장한다.
class Storage {
  static const _kSave = 'save';
  static const _kLocale = 'locale';

  final SharedPreferences _prefs;
  Storage(this._prefs);

  static Future<Storage> create() async => Storage(await SharedPreferences.getInstance());

  /// 사용자가 고른 언어 코드 (null = 시스템 언어).
  String? get localeCode => _prefs.getString(_kLocale);
  Future<void> setLocaleCode(String? code) => code == null ? _prefs.remove(_kLocale) : _prefs.setString(_kLocale, code);

  Map<String, dynamic>? loadGame() {
    final s = _prefs.getString(_kSave);
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGame(Map<String, dynamic> json) => _prefs.setString(_kSave, jsonEncode(json));

  Future<void> clearGame() => _prefs.remove(_kSave);
}
