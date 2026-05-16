import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../main.dart';
import '../session/patient_session.dart';
import '../widgets/chick_card.dart';
import '../widgets/chick_input.dart';
import '../widgets/chick_scaffold.dart';
import '../widgets/time_picker_spinner.dart';

class NotificationRegisterPage extends StatefulWidget {
  const NotificationRegisterPage({super.key});

  @override
  State<NotificationRegisterPage> createState() =>
      _NotificationRegisterPageState();
}

class _NotificationRegisterPageState extends State<NotificationRegisterPage> {
  Future<void> deleteMedicationSchedule(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(PatientSession.patientId.value ?? 'default-patient')
          .collection('medSchedules')
          .doc(docId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림이 삭제되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  final _medicineCtrl = TextEditingController();
  Duration _alarmTime = const Duration(hours: 8, minutes: 0);
  bool _repeatDaily = false;
  DateTime? _repeatUntilDate;
  final List<bool> _weekdayRepeats = List<bool>.filled(7, false);
  String _status = '준비 완료';
  String mealTime = 'breakfast';
  String mealType = 'after_meal';
  bool isFasting = false;

  String _formatTime(Duration d) {
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String getMealTimeLabel(String value) {
    switch (value) {
      case 'breakfast':
        return '아침';
      case 'lunch':
        return '점심';
      case 'dinner':
        return '저녁';
      default:
        return '';
    }
  }

  String getMealTypeLabel(String value) {
    switch (value) {
      case 'before_meal':
        return '식전';
      case 'after_meal':
        return '식후';
      case 'empty_stomach':
        return '공복';
      default:
        return '';
    }
  }

  Future<void> saveMedicationSchedule() async {
    try {
      await ensureSignedIn();
      setState(() => _status = '복약 알림 저장 중...');

      final now = DateTime.now();
      final alarmAt = DateTime(
        now.year,
        now.month,
        now.day,
        _alarmTime.inHours,
        _alarmTime.inMinutes % 60,
      );

      final selectedWeekdays = <int>[];
      for (int i = 0; i < _weekdayRepeats.length; i++) {
        if (_weekdayRepeats[i]) selectedWeekdays.add(i);
      }

      final repeatUntil = (_repeatDaily || selectedWeekdays.isNotEmpty)
          ? (_repeatUntilDate ?? DateTime(2100, 12, 31))
          : alarmAt;

      await FirebaseFirestore.instance
          .collection('patients')
          .doc(PatientSession.patientId.value ?? 'default-patient')
          .collection('medSchedules');

      final medicineName = _medicineCtrl.text.trim();

      final medicineDoc = await FirebaseFirestore.instance
          .collection('medicines')
          .doc(medicineName)
          .get();

      List<String> ingredients = [];

      if (medicineDoc.exists) {
        ingredients = List<String>.from(
          medicineDoc.data()?['ingredients'] ?? [],
        );
      }

      final mealLabel =
          '${getMealTimeLabel(mealTime)} ${getMealTypeLabel(mealType)}';

      final fasting = mealType == 'empty_stomach';

      await FirebaseFirestore.instance
          .collection('patients')
          .doc(PatientSession.patientId.value ?? 'default-patient')
          .collection('medSchedules')
          .add({
        'medicineName': medicineName,
        'ingredients': ingredients,
        'time': _formatTime(_alarmTime),
        'alarmAt': Timestamp.fromDate(alarmAt),
        'mealTime': mealTime,
        'mealType': mealType,
        'mealLabel': mealLabel,
        'isFasting': fasting,
        'repeatDaily': _repeatDaily,
        'repeatWeekdays': selectedWeekdays,
        'repeatUntilAt': Timestamp.fromDate(
          DateTime(
            repeatUntil.year,
            repeatUntil.month,
            repeatUntil.day,
            23,
            59,
            59,
          ),
        ),
        'source': 'flutter',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _status = '복약 알림 저장 완료');
      _showMessage('복약 알림 저장 완료');
    } catch (e) {
      setState(() => _status = '저장 실패: $e');
      _showMessage('저장 실패: $e');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _medicineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPatientId =
        PatientSession.patientId.value ?? 'default-patient';

    return ChickScaffold(
      title: '알림등록 ($currentPatientId)',
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: ChickCard(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '알림 저장',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: chickBrown,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('상태: $_status'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _medicineCtrl,
                        decoration: chickInput('약 이름'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '선택된 시간: ${_formatTime(_alarmTime)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: chickOrange,
                            foregroundColor: chickBrown,
                          ),
                          icon: const Icon(Icons.access_time),
                          label: const Text('시간 설정'),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) {
                                Duration tempTime = _alarmTime;

                                return Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: StatefulBuilder(
                                    builder: (context, setModalState) {
                                      return SizedBox(
                                        width: 320,
                                        height: 320,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            children: [
                                              const Text(
                                                '복약 시간 선택',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                  color: chickBrown,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Expanded(
                                                child: TimePickerSpinner(
                                                  duration: tempTime,
                                                  onChanged: (duration) {
                                                    setModalState(() {
                                                      tempTime = duration;
                                                    });
                                                  },
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: OutlinedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      child: const Text('취소'),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: FilledButton(
                                                      style:
                                                          FilledButton.styleFrom(
                                                        backgroundColor:
                                                            chickOrange,
                                                        foregroundColor:
                                                            chickBrown,
                                                      ),
                                                      onPressed: () {
                                                        setState(() {
                                                          _alarmTime = tempTime;
                                                        });
                                                        Navigator.pop(context);
                                                      },
                                                      child: const Text('확인'),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: mealTime,
                        decoration: chickInput('복용 시간대'),
                        items: const [
                          DropdownMenuItem(
                              value: 'breakfast', child: Text('아침')),
                          DropdownMenuItem(value: 'lunch', child: Text('점심')),
                          DropdownMenuItem(
                              value: 'dinner', child: Text('저녁')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => mealTime = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: mealType,
                        decoration: chickInput('식사 여부'),
                        items: const [
                          DropdownMenuItem(
                              value: 'before_meal', child: Text('식전')),
                          DropdownMenuItem(
                              value: 'after_meal', child: Text('식후')),
                          DropdownMenuItem(
                              value: 'empty_stomach', child: Text('공복')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              mealType = v;
                              isFasting = v == 'empty_stomach';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '복약 정보: ${getMealTimeLabel(mealTime)} ${getMealTypeLabel(mealType)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: chickBrown,
                        ),
                      ),
                      if (isFasting)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            '공복 복용 약입니다.',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Checkbox(
                            value: _repeatDaily,
                            activeColor: chickOrange,
                            onChanged: (v) =>
                                setState(() => _repeatDaily = v ?? false),
                          ),
                          const Text('매일 반복'),
                        ],
                      ),
                      Wrap(
                        spacing: 2,
                        children: List.generate(7, (index) {
                          const labels = ['월', '화', '수', '목', '금', '토', '일'];
                          return FilterChip(
                            selectedColor: chickOrange,
                            label: Text(labels[index]),
                            selected: _weekdayRepeats[index],
                            onSelected: (v) =>
                                setState(() => _weekdayRepeats[index] = v),
                          );
                        }),
                      ),
                      if (_repeatDaily || _weekdayRepeats.contains(true))
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100, 12, 31),
                              initialDate:
                                  _repeatUntilDate ?? DateTime.now(),
                            );

                            if (picked != null) {
                              setState(() => _repeatUntilDate = picked);
                            }
                          },
                          child: Text(
                            _repeatUntilDate == null
                                ? '반복 종료일 선택'
                                : '반복 종료일: ${_repeatUntilDate!.year}-${_repeatUntilDate!.month.toString().padLeft(2, '0')}-${_repeatUntilDate!.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: chickOrange,
                          foregroundColor: chickBrown,
                        ),
                        onPressed: saveMedicationSchedule,
                        child: const Text('알림 등록 저장'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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

                            final times =
                                (data['times'] as List<dynamic>? ?? [])
                                    .join(', ');

                            final repeatDaily = data['repeatDaily'] == true;

                            final repeatWeekdays =
                                (data['repeatWeekdays'] as List<dynamic>? ?? [])
                                    .map((e) => e as int)
                                    .toList();

                            const weekdayLabels = [
                              '일', '월', '화', '수', '목', '금', '토'
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
                                    Text('시간: $times'),
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
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final result = await showDialog<bool>(
                                      context: context,
                                      builder: (_) {
                                        return AlertDialog(
                                          title: const Text('알림 삭제'),
                                          content: const Text(
                                              '저장된 알림을 삭제하시겠습니까?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                  context, false),
                                              child: const Text('취소'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.pop(
                                                  context, true),
                                              child: const Text('삭제'),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (result == true) {
                                      await deleteMedicationSchedule(
                                          docs[i].id);
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