import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../session/patient_session.dart';
import '../widgets/chick_card.dart';
import '../widgets/chick_scaffold.dart';

class NotificationRegisterPage extends StatefulWidget {
  const NotificationRegisterPage({super.key});

  @override
  State<NotificationRegisterPage> createState() =>
      _NotificationRegisterPageState();
}

class _NotificationRegisterPageState extends State<NotificationRegisterPage> {
  String _formatScheduleTime(Map<String, dynamic> data) {
    final timeTexts = <String>[];

    void addTime(Object? value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) return;
      if (!timeTexts.contains(text)) timeTexts.add(text);
    }

    final times = data['times'];
    if (times is List) {
      for (final time in times) {
        addTime(time);
      }
    } else {
      addTime(times);
    }

    addTime(data['time']);
    addTime(data['alarmTime']);

    final alarmAt = data['alarmAt'];
    if (alarmAt is Timestamp) {
      final date = alarmAt.toDate();
      addTime(_formatTime(date.hour, date.minute));
    }

    return timeTexts.isEmpty ? '-' : timeTexts.join(', ');
  }

  TimeOfDay _initialTimeFromSchedule(Map<String, dynamic> data) {
    final alarmAt = data['alarmAt'];
    if (alarmAt is Timestamp) {
      final date = alarmAt.toDate();
      return TimeOfDay(hour: date.hour, minute: date.minute);
    }

    final timeText = (data['time'] ?? data['alarmTime'])?.toString();
    final match =
        RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(timeText ?? '');
    if (match != null) {
      return TimeOfDay(
        hour: int.parse(match.group(1)!),
        minute: int.parse(match.group(2)!),
      );
    }

    return TimeOfDay.now();
  }

  DateTime _alarmDateWithNewTime(
    Map<String, dynamic> data,
    TimeOfDay picked,
  ) {
    final alarmAt = data['alarmAt'];
    final baseDate = alarmAt is Timestamp ? alarmAt.toDate() : DateTime.now();

    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      picked.hour,
      picked.minute,
    );
  }

  String _formatTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}'
        ':${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _updateScheduleTime({
    required String patientId,
    required String scheduleId,
    required Map<String, dynamic> data,
    required TimeOfDay picked,
  }) async {
    final newTime = _formatTime(picked.hour, picked.minute);
    final newAlarmTime = _alarmDateWithNewTime(data, picked);
    final updateData = {
      'time': newTime,
      'alarmTime': newTime,
      'times': [newTime],
      'alarmAt': Timestamp.fromDate(newAlarmTime),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('patients')
        .doc(patientId)
        .collection('medSchedules')
        .doc(scheduleId)
        .update(updateData);

    await FirebaseDatabase.instance
        .ref('patients/$patientId/medSchedules/$scheduleId')
        .update({
      'medicineName': data['medicineName'],
      'time': newTime,
      'alarmTime': newTime,
      'times': [newTime],
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPatientId =
        PatientSession.patientId.value ?? 'default-patient';

    return ChickScaffold(
      title: '알림조회/수정 ($currentPatientId)',
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: ChickCard(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '저장된 알림 확인',
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
                          .orderBy('createdAt', descending: true)
                          .limit(30)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text('조회 실패: ${snapshot.error}');
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data!.docs;

                        if (docs.isEmpty) {
                          return const Text('저장된 알림이 없습니다.');
                        }

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (_, i) {
                            final data = docs[i].data();

                            final time = _formatScheduleTime(data);

                            final repeatDaily = data['repeatDaily'] == true;

                            final repeatWeekdays =
                                (data['repeatWeekdays'] as List<dynamic>? ?? [])
                                    .map((e) => e as int)
                                    .toList();

                            const weekdayLabels = [
                              '일',
                              '월',
                              '화',
                              '수',
                              '목',
                              '금',
                              '토',
                            ];

                            String repeatText = '반복 없음';

                            if (repeatDaily) {
                              repeatText = '매일 반복';
                            } else if (repeatWeekdays.isNotEmpty) {
                              repeatText = repeatWeekdays
                                  .map((i) => weekdayLabels[i])
                                  .join(', ');
                            }

                            return Card(
                              color: chickYellow.withOpacity(0.35),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.medication,
                                  color: chickOrange,
                                ),
                                title: Text(
                                  '${data['medicineName'] ?? '-'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: chickBrown,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('시간: $time'),
                                    Text('복용: ${data['mealLabel'] ?? '-'}'),
                                    if (data['isFasting'] == true)
                                      const Text(
                                        '공복 복용',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    Text('반복: $repeatText'),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: chickOrange,
                                  ),
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _initialTimeFromSchedule(data),
                                    );

                                    if (picked == null) return;

                                    try {
                                      await _updateScheduleTime(
                                        patientId: currentPatientId,
                                        scheduleId: docs[i].id,
                                        data: data,
                                        picked: picked,
                                      );

                                      if (!mounted) return;                                    

                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('복약 시간이 수정되었습니다.'),
                                        ),
                                      );
                                    } catch (error) {
                                      if (!mounted) return;

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('수정 실패: $error'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
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
