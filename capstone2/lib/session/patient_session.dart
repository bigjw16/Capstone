import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientSession {
  static final ValueNotifier<String?> patientId =
      ValueNotifier<String?>(null);

  static late SharedPreferences _prefs;

  static bool _initialized = false;

  static bool get isLoggedIn =>
      patientId.value != null && patientId.value!.isNotEmpty;

  /// 🔥 반드시 앱 시작 시 1번만 호출
  static Future<void> init() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    _initialized = true;

    await restore();
  }

  /// 🔥 로그인 상태 복원
  static Future<void> restore() async {
    final savedId = _prefs.getString('patientId');

    if (savedId != null && savedId.isNotEmpty) {
      patientId.value = savedId;
    }
  }

  /// 🔥 로그인
  static Future<void> login(String id) async {
    if (!_initialized) await init();
    if (id.isEmpty) return;

    if (patientId.value == id) return;

    patientId.value = id;
    await _prefs.setString('patientId', id);
  }

  /// 🔥 로그아웃
  static Future<void> logout() async {
    if (!_initialized) return;

    patientId.value = null;
    await _prefs.remove('patientId');
  }
}