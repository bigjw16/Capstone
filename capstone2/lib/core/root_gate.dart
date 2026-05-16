import 'package:flutter/material.dart';

import '../session/patient_session.dart';
import '../screens/settings_login_page.dart';
import '../screens/swipe_home_container.dart';

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await PatientSession.init(); // 🔥 세션 복원
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 1. 앱 시작 로딩
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 🔥 2. 로그인 상태 실시간 감지
    return ValueListenableBuilder<String?>(
      valueListenable: PatientSession.patientId,
      builder: (context, patientId, _) {
        final isLoggedIn = patientId != null && patientId.isNotEmpty;

        // 🔥 로그아웃 상태 → 로그인 화면
        if (!isLoggedIn) {
          return const SettingsLoginPage();
        }

        // 🔥 로그인 상태 → 홈 (Swipe)
        return const SwipeHomeContainer();
      },
    );
  }
}