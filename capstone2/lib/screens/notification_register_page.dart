import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

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
  @override
  Widget build(BuildContext context) {
    final currentPatientId =
        PatientSession.patientId.value ?? 'default-patient';
    final DatabaseReference rtdb = FirebaseDatabase.instance.ref();

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

                            final time = data['time'] ?? '-';

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
                              '토'
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
                                      initialTime: TimeOfDay.fromDateTime(
                                        (data['alarmAt'] as Timestamp).toDate(),
                                      ),
                                    );

                                    if (picked == null) return;

                                    final now = DateTime.now();

                                    final newAlarmTime = DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                      picked.hour,
                                      picked.minute,
                                    );

                                    final newTime =
                                        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

                                    await FirebaseFirestore.instance
                                        .collection('patients')
                                        .doc(currentPatientId)
                                        .collection('medSchedules')
                                        .doc(docs[i].id)
                                        .update({
                                      'time': newTime,
                                      'alarmAt':
                                          Timestamp.fromDate(newAlarmTime),
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });

                                    await FirebaseDatabase.instance
                                        .ref()
                                        .child('patients')
                                        .child(currentPatientId)
                                        .child('medSchedules')
                                        .child(docs[i].id)
                                        .update({
                                      'medicineName': data['medicineName'],
                                      'time': newTime,
                                    });

                                    if (!mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('복약 시간이 수정되었습니다.'),
                                      ),
                                    );
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
