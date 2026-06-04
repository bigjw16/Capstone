import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../session/patient_session.dart';
import '../widgets/chick_card.dart';
import '../widgets/chick_scaffold.dart';
import '../widgets/today_reward_card.dart';
import 'settings_login_page.dart';

class TodayHomePage extends StatelessWidget {
  const TodayHomePage({super.key});

  bool _isDueToday(Map<String, dynamic> data, DateTime today) {
    final alarmTs = data['alarmAt'];
    if (alarmTs is! Timestamp) return false;

    final alarmAt = alarmTs.toDate();
    final repeatDaily = data['repeatDaily'] == true;

    final repeatWeekdays = (data['repeatWeekdays'] as List<dynamic>? ?? [])
        .map((e) => e as int)
        .toSet();

    final repeatUntilTs = data['repeatUntilAt'];
    final repeatUntil =
        repeatUntilTs is Timestamp ? repeatUntilTs.toDate() : alarmAt;

    final startDay = DateTime(alarmAt.year, alarmAt.month, alarmAt.day);
    final endDay = DateTime(
      repeatUntil.year,
      repeatUntil.month,
      repeatUntil.day,
      23,
      59,
      59,
    );
    final todayDay = DateTime(today.year, today.month, today.day);

    if (todayDay.isBefore(startDay) || todayDay.isAfter(endDay)) return false;
    if (repeatDaily) return true;
    if (repeatWeekdays.isNotEmpty) {
      return repeatWeekdays.contains(today.weekday % 7);
    }

    return todayDay.year == startDay.year &&
        todayDay.month == startDay.month &&
        todayDay.day == startDay.day;
  }

  String _formatScheduleTimes(Map<String, dynamic> data) {
    final alarmTime = data['alarmTime']?.toString().trim();
    if (alarmTime != null && alarmTime.isNotEmpty) return alarmTime;

    final alarmAt = data['alarmAt'];
    if (alarmAt is Timestamp) {
      final date = alarmAt.toDate();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    return '시간 정보 없음';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayText =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final currentPatientId =
        PatientSession.patientId.value ?? 'default-patient';

    return ChickScaffold(
      title: '오늘의 정보',
      actions: [
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsLoginPage()),
          ),
          icon: const Icon(Icons.settings, color: chickBrown),
        ),
      ],
      child: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: chickBrown,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 34,
                  height: 28,
                  decoration: BoxDecoration(
                    color: chickOrange,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: chickBrown,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ChickCard(
            child: Center(
              child: Text(
                todayText,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: chickBrown,
                ),
              ),
            ),
          ),
          TodayRewardCard(
            patientId: currentPatientId,
            today: today,
          ),
          Expanded(
            child: ChickCard(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '오늘 먹어야 하는 약',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: chickBrown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('patients')
                          .doc(currentPatientId)
                          .collection('medSchedules')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('조회 실패: ${snapshot.error}');
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final dueDocs = snapshot.data!.docs
                            .where((d) => _isDueToday(d.data(), today))
                            .toList();

                        if (dueDocs.isEmpty) {
                          return const Text('오늘 복약 예정이 없습니다.');
                        }

                        return ListView.builder(
                          itemCount: dueDocs.length,
                          itemBuilder: (_, i) {
                            final data = dueDocs[i].data();
                            final times = _formatScheduleTimes(data);

                            return ListTile(
                              leading: const Icon(
                                Icons.medication,
                                color: chickOrange,
                              ),
                              title: Text(
                                data['medicineName']?.toString() ?? '-',
                              ),
                              subtitle: Text('시간: $times'),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}