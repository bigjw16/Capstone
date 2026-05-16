import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../widgets/chick_scaffold.dart';
import '../widgets/chick_card.dart';

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.errorText});

  final String errorText;

  @override
  Widget build(BuildContext context) {
    final isConfigError = errorText.contains('CONFIGURATION_NOT_FOUND');

    return ChickScaffold(
      title: 'Firebase 초기화 오류',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ChickCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '앱 시작 중 Firebase 인증/초기화에 실패했습니다.',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: chickBrown,
                  ),
                ),
                const SizedBox(height: 8),
                Text(errorText),
                const SizedBox(height: 16),
                if (isConfigError) ...[
                  const Text('해결 방법 (CONFIGURATION_NOT_FOUND):'),
                  const Text(
                      '1) Firebase Console > Authentication > Sign-in method 진입'),
                  const Text('2) Anonymous 제공자 활성화'),
                  const Text('3) flutterfire configure 재실행 후 앱 재빌드'),
                  const Text('4) 선택한 Firebase 프로젝트가 맞는지 확인'),
                ] else ...[
                  const Text('해결 방법:'),
                  const Text('- flutterfire configure 실행 여부 확인'),
                  const Text('- 앱 패키지명/번들ID가 Firebase 앱 등록값과 일치하는지 확인'),
                  const Text('- 네트워크 및 프로젝트 설정값 점검'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}