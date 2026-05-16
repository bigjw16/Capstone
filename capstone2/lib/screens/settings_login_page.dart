import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../session/patient_session.dart';
import '../widgets/chick_card.dart';
import '../core/constants.dart';

class SettingsLoginPage extends StatefulWidget {
  const SettingsLoginPage({super.key});

  @override
  State<SettingsLoginPage> createState() => _SettingsLoginPageState();
}

class _SettingsLoginPageState extends State<SettingsLoginPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _birthCtrl = TextEditingController();

  bool _loading = false;

  String _normalizeBirth(String input) {
    // YYYYMMDD → YYYY-MM-DD
    if (RegExp(r'^[0-9]{8}$').hasMatch(input)) {
      return '${input.substring(0, 4)}-${input.substring(4, 6)}-${input.substring(6, 8)}';
    }
    return input;
  }

  Future<void> _login() async {
    final name = _nameCtrl.text.trim();
    final birthInput = _birthCtrl.text.trim();
    final birth = _normalizeBirth(birthInput);

    if (name.isEmpty || birthInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름과 생년월일을 입력하세요')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(name)
          .get();

      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('환자 정보 없음')),
        );
        return;
      }

      final data = doc.data() ?? {};
      final savedBirth = data['birthDate']?.toString();

      if (savedBirth != birth) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('생년월일 불일치')),
        );
        return;
      }

      await PatientSession.login(name);

      _nameCtrl.clear();
      _birthCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 성공')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _logout() async {
    await PatientSession.logout();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃 완료')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: PatientSession.patientId,
      builder: (context, patientId, _) {
        final isLoggedIn = patientId != null && patientId.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('설정'),
            backgroundColor: chickOrange,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChickCard(
                  child: Text(
                    isLoggedIn ? '환자 ID: $patientId' : '로그인되지 않음',
                  ),
                ),

                const SizedBox(height: 20),

                // 🔥 로그인 UI
                if (!isLoggedIn)
                  ChickCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: '환자 이름',
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: _birthCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 8,
                          decoration: const InputDecoration(
                            labelText: '생년월일 (YYYYMMDD)',
                            counterText: '',
                          ),
                        ),

                        const SizedBox(height: 12),

                        ElevatedButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('로그인'),
                        ),
                      ],
                    ),
                  ),

                // 🔥 로그아웃 UI
                if (isLoggedIn)
                  ChickCard(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _logout,
                        child: const Text('로그아웃'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}