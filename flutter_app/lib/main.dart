import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;

  try {
    await Firebase.initializeApp();
    await _ensureSignedIn();
  } catch (e) {
    startupError = e.toString();
  }

  runApp(PatientMedSyncApp(startupError: startupError));
}

Future<void> _ensureSignedIn() async {
  if (FirebaseAuth.instance.currentUser != null) return;
  await FirebaseAuth.instance.signInAnonymously();
}

class PatientMedSyncApp extends StatelessWidget {
  const PatientMedSyncApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patient Med Sync',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: startupError == null
          ? const SwipeHomeContainer()
          : StartupErrorScreen(errorText: startupError!),
    );
  }
}

class SwipeHomeContainer extends StatelessWidget {
  const SwipeHomeContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return PageView(
      scrollDirection: Axis.horizontal,
      children: const [
        TodayHomePage(), // 1페이지(추가한 홈페이지)
        HomeDashboardScreen(), // 2페이지(기존 홈페이지)
      ],
    );
  }
}

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
    final repeatUntil = repeatUntilTs is Timestamp ? repeatUntilTs.toDate() : alarmAt;
    final startDay = DateTime(alarmAt.year, alarmAt.month, alarmAt.day);
    final endDay = DateTime(repeatUntil.year, repeatUntil.month, repeatUntil.day, 23, 59, 59);
    final todayDay = DateTime(today.year, today.month, today.day);

    if (todayDay.isBefore(startDay) || todayDay.isAfter(endDay)) return false;
    if (repeatDaily) return true;
    if (repeatWeekdays.isNotEmpty) return repeatWeekdays.contains(today.weekday % 7);
    return todayDay.year == startDay.year &&
        todayDay.month == startDay.month &&
        todayDay.day == startDay.day;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayText =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('홈페이지'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsLoginPage()),
            ),
            icon: const Icon(Icons.settings),
            tooltip: '설정',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(12),
              child: Center(
                child: Text(
                  '오늘 날짜: $todayText',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          Expanded(
            child: Card(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: const Center(
                child: Text('개발중', style: TextStyle(fontSize: 20, color: Colors.grey)),
              ),
            ),
          ),
          Expanded(
            child: Card(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('오늘 먹어야 하는 약', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('patients')
                            .doc('default-patient')
                            .collection('medSchedules')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) return Text('조회 실패: ${snapshot.error}');
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final dueDocs = snapshot.data!.docs
                              .where((d) => _isDueToday(d.data(), today))
                              .toList();
                          if (dueDocs.isEmpty) return const Text('오늘 복약 예정이 없습니다.');
                          return ListView.builder(
                            itemCount: dueDocs.length,
                            itemBuilder: (_, i) {
                              final data = dueDocs[i].data();
                              final times = (data['times'] as List<dynamic>? ?? []).join(', ');
                              return ListTile(
                                dense: true,
                                title: Text(data['medicineName']?.toString() ?? '-'),
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
          ),
        ],
      ),
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.errorText});

  final String errorText;

  @override
  Widget build(BuildContext context) {
    final isConfigError = errorText.contains('CONFIGURATION_NOT_FOUND');

    return Scaffold(
      appBar: AppBar(title: const Text('Firebase 초기화 오류')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '앱 시작 중 Firebase 인증/초기화에 실패했습니다.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(errorText),
          const SizedBox(height: 16),
          if (isConfigError) ...[
            const Text('해결 방법 (CONFIGURATION_NOT_FOUND):'),
            const SizedBox(height: 6),
            const Text('1) Firebase Console > Authentication > Sign-in method 진입'),
            const Text('2) Anonymous 제공자 활성화'),
            const Text('3) flutterfire configure 재실행 후 앱 재빌드'),
            const Text('4) 선택한 Firebase 프로젝트가 맞는지 확인'),
          ] else ...[
            const Text('해결 방법:'),
            const SizedBox(height: 6),
            const Text('- flutterfire configure 실행 여부 확인'),
            const Text('- 앱 패키지명/번들ID가 Firebase 앱 등록값과 일치하는지 확인'),
            const Text('- 네트워크 및 프로젝트 설정값 점검'),
          ],
        ],
      ),
    );
  }
}

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool _isPatientLoggedIn = false;

  Future<void> _openSettingsLogin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SettingsLoginPage()),
    );

    if (result == true) {
      setState(() => _isPatientLoggedIn = true);
    }
  }

  void _guardedNavigate(Widget page) {
    if (!_isPatientLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 설정에서 로그인 후 이용하세요.')),
      );
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isPatientLoggedIn ? '복약 관리 홈 (로그인됨)' : '복약 관리 홈 (로그인 필요)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettingsLogin,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '캘린더',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Expanded(
                        child: MedicationCalendarWidget(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MenuButton(
                    label: '알림등록',
                    onTap: () => _guardedNavigate(const NotificationRegisterPage()),
                  ),
                  _MenuButton(
                    label: '복약통계',
                    onTap: () => _guardedNavigate(const MedicationStatsPage()),
                  ),
                  _MenuButton(
                    label: '복약정보',
                    onTap: () => _guardedNavigate(const PlaceholderPage(title: '복약정보')),
                  ),
                  _MenuButton(
                    label: '식품관리',
                    onTap: () => _guardedNavigate(const PlaceholderPage(title: '식품관리')),
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


class MedicationCalendarWidget extends StatefulWidget {
  const MedicationCalendarWidget({super.key});

  @override
  State<MedicationCalendarWidget> createState() => _MedicationCalendarWidgetState();
}

class _MedicationCalendarWidgetState extends State<MedicationCalendarWidget> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DateTime> _buildMonthCells(DateTime monthStart) {
    final firstWeekday = monthStart.weekday % 7; // sunday:0
    final firstCell = monthStart.subtract(Duration(days: firstWeekday));
    return List.generate(42, (i) => firstCell.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final monthEnd = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collectionGroup('medSchedules')
          .where(
            'alarmAt',
            isLessThanOrEqualTo: Timestamp.fromDate(
              DateTime(monthEnd.year, monthEnd.month, monthEnd.day, 23, 59, 59),
            ),
          )
          .where('repeatUntilAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .snapshots(),
      builder: (context, snapshot) {
        final marked = <DateTime>{};
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final alarmTs = data['alarmAt'] ?? data['createdAt'];
            final untilTs = data['repeatUntilAt'];
            final isRepeatDaily = data['repeatDaily'] == true;
            final weekdays = (data['repeatWeekdays'] as List<dynamic>? ?? []).map((e) => e as int).toSet();
            if (alarmTs is! Timestamp) continue;

            final start = _dateOnly(alarmTs.toDate());
            final until = untilTs is Timestamp ? _dateOnly(untilTs.toDate()) : start;

            if (isRepeatDaily || weekdays.isNotEmpty) {
              final from = start.isAfter(monthStart) ? start : monthStart;
              final to = until.isBefore(monthEnd) ? until : monthEnd;
              for (DateTime d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
                final weekday = d.weekday % 7;
                if (isRepeatDaily || weekdays.contains(weekday)) {
                  marked.add(_dateOnly(d));
                }
              }
            } else if (!start.isBefore(monthStart) && !start.isAfter(monthEnd)) {
              marked.add(start);
            }
          }
        }

        final cells = _buildMonthCells(monthStart);
        final weekdays = const ['일', '월', '화', '수', '목', '금', '토'];

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${_focusedMonth.year}년 ${_focusedMonth.month}월', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: weekdays
                  .map((w) => Expanded(
                        child: Center(
                          child: Text(w, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                itemCount: cells.length,
                itemBuilder: (_, i) {
                  final day = cells[i];
                  final isCurrentMonth = day.month == _focusedMonth.month;
                  final hasAlarm = marked.contains(_dateOnly(day));

                  return Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: isCurrentMonth ? Colors.white : Colors.grey.shade100,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isCurrentMonth ? Colors.black : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (hasAlarm)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class NotificationRegisterPage extends StatefulWidget {
  const NotificationRegisterPage({super.key});

  @override
  State<NotificationRegisterPage> createState() => _NotificationRegisterPageState();
}

class _NotificationRegisterPageState extends State<NotificationRegisterPage> {
  static const _defaultPatientId = 'default-patient';
  final _medicineCtrl = TextEditingController();
  Duration _alarmTime = const Duration(hours: 8, minutes: 0);
  bool _repeatDaily = false;
  DateTime? _repeatUntilDate;
  final List<bool> _weekdayRepeats = List<bool>.filled(7, false);
  String _status = '준비 완료';

  String _formatTime(Duration d) {
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> saveMedicationSchedule() async {
    try {
      await _ensureSignedIn();
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
          .doc(_defaultPatientId)
          .collection('medSchedules')
          .add({
        'medicineName': _medicineCtrl.text.trim(),
        'times': [_formatTime(_alarmTime)],
        'alarmAt': Timestamp.fromDate(alarmAt),
        'repeatDaily': _repeatDaily,
        'repeatWeekdays': selectedWeekdays,
        'repeatUntilAt': Timestamp.fromDate(
          DateTime(repeatUntil.year, repeatUntil.month, repeatUntil.day, 23, 59, 59),
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
    return Scaffold(
      appBar: AppBar(title: const Text('알림등록')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('알림 저장', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('약 이름 + 시간만 설정합니다.'),
                      const SizedBox(height: 8),
                      Text('상태: $_status'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _medicineCtrl,
                        decoration: const InputDecoration(
                          labelText: '약 이름',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('선택된 시간: ${_formatTime(_alarmTime)}'),
                      const SizedBox(height: 4),
                      const Text('시간 설정(위/아래 스크롤)'),
                      Expanded(
                        child: TimePickerSpinner(
                          duration: _alarmTime,
                          onChanged: (duration) => setState(() => _alarmTime = duration),
                        ),
                      ),

                      Row(
                        children: [
                          Checkbox(
                            value: _repeatDaily,
                            onChanged: (v) => setState(() => _repeatDaily = v ?? false),
                          ),
                          const Text('매일 반복'),
                        ],
                      ),

                      Wrap(
                        spacing: 6,
                        children: List.generate(7, (index) {
                          const labels = ['일', '월', '화', '수', '목', '금', '토'];
                          return FilterChip(
                            label: Text(labels[index]),
                            selected: _weekdayRepeats[index],
                            onSelected: (v) => setState(() => _weekdayRepeats[index] = v),
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
                              initialDate: _repeatUntilDate ?? DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _repeatUntilDate = picked);
                            }
                          },
                          child: Text(
                            _repeatUntilDate == null
                                ? '반복 종료일 선택 (미선택 시 2100-12-31)'
                                : '반복 종료일: ${_repeatUntilDate!.year}-${_repeatUntilDate!.month.toString().padLeft(2, '0')}-${_repeatUntilDate!.day.toString().padLeft(2, '0')}',
                          ),
                        ),
                      FilledButton(
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('저장된 알림 확인', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('patients')
                              .doc(_defaultPatientId)
                              .collection('medSchedules')
                              .orderBy('createdAt', descending: true)
                              .limit(30)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) return Text('조회 실패: ${snapshot.error}');
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            final docs = snapshot.data!.docs;
                            if (docs.isEmpty) return const Text('저장된 알림이 없습니다.');
                            return ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (_, i) {
                                final data = docs[i].data();
                                final times = (data['times'] as List<dynamic>? ?? []).join(', ');
                                return ListTile(
                                  dense: true,
                                  title: Text('${data['medicineName'] ?? '-'}'),
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
            ),
          ),
        ],
      ),
    );
  }
}

class TimePickerSpinner extends StatefulWidget {
  const TimePickerSpinner({super.key, required this.duration, required this.onChanged});

  final Duration duration;
  final ValueChanged<Duration> onChanged;

  @override
  State<TimePickerSpinner> createState() => _TimePickerSpinnerState();
}

class _TimePickerSpinnerState extends State<TimePickerSpinner> {
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    _hourCtrl = FixedExtentScrollController(initialItem: widget.duration.inHours % 24);
    _minuteCtrl = FixedExtentScrollController(initialItem: widget.duration.inMinutes % 60);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int selectedHour = widget.duration.inHours % 24;
    int selectedMinute = widget.duration.inMinutes % 60;

    void notify() {
      widget.onChanged(Duration(hours: selectedHour, minutes: selectedMinute));
    }

    return Row(
      children: [
        Expanded(
          child: ListWheelScrollView.useDelegate(
            controller: _hourCtrl,
            itemExtent: 36,
            perspective: 0.003,
            onSelectedItemChanged: (v) {
              selectedHour = v;
              notify();
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: 24,
              builder: (_, i) => Center(child: Text('${i.toString().padLeft(2, '0')}시')),
            ),
          ),
        ),
        Expanded(
          child: ListWheelScrollView.useDelegate(
            controller: _minuteCtrl,
            itemExtent: 36,
            perspective: 0.003,
            onSelectedItemChanged: (v) {
              selectedMinute = v;
              notify();
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: 60,
              builder: (_, i) => Center(child: Text('${i.toString().padLeft(2, '0')}분')),
            ),
          ),
        ),
      ],
    );
  }
}

class MedicationStatsPage extends StatefulWidget {
  const MedicationStatsPage({super.key});

  @override
  State<MedicationStatsPage> createState() => _MedicationStatsPageState();
}

class _MedicationStatsPageState extends State<MedicationStatsPage> {
  final _patientIdCtrl = TextEditingController();
  DocumentSnapshot<Map<String, dynamic>>? _patientDoc;
  DocumentSnapshot<Map<String, dynamic>>? _hospitalDoc;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _medScheduleDocs = [];
  String _status = '준비 완료';

  Future<void> loadPatientAndHospital({String? patientIdFromList}) async {
    final patientId = (patientIdFromList ?? _patientIdCtrl.text).trim();
    if (patientId.isEmpty) {
      _showMessage('환자 ID(환자명)를 입력하세요.');
      return;
    }

    try {
      await _ensureSignedIn();
      setState(() => _status = '환자/병원/복약 정보 불러오는 중...');

      final patient = await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .get();

      if (!patient.exists) {
        setState(() {
          _patientDoc = null;
          _hospitalDoc = null;
          _medScheduleDocs = [];
          _status = '환자 문서를 찾을 수 없습니다.';
        });
        return;
      }

      final hospitalId = patient.data()?['hospitalId'] as String?;
      DocumentSnapshot<Map<String, dynamic>>? hospital;

      if (hospitalId != null && hospitalId.isNotEmpty) {
        final hospitalById = await FirebaseFirestore.instance
            .collection('hospitals')
            .doc(hospitalId)
            .get();

        if (hospitalById.exists) {
          hospital = hospitalById;
        } else {
          final hospitalByName = await FirebaseFirestore.instance
              .collection('hospitals')
              .where('name', isEqualTo: hospitalId)
              .limit(1)
              .get();

          if (hospitalByName.docs.isNotEmpty) {
            hospital = hospitalByName.docs.first;
          }
        }
      }

      final medSnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .collection('medSchedules')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _patientIdCtrl.text = patientId;
        _patientDoc = patient;
        _hospitalDoc = hospital;
        _medScheduleDocs = medSnapshot.docs;
        _status = '환자/병원/복약 정보 로딩 완료';
      });
    } catch (e) {
      setState(() => _status = '불러오기 실패: $e');
      _showMessage('불러오기 실패: $e');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '미로그인';

    return Scaffold(
      appBar: AppBar(title: const Text('복약통계')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('인증 UID: $uid', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('상태: $_status'),
          const SizedBox(height: 12),
          const Text(
            '웹에서 저장된 환자 목록',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('환자 목록 조회 실패: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Text('환자 데이터가 없습니다. 웹에서 먼저 환자를 등록하세요.');
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return ListTile(
                      dense: true,
                      title: Text(data['name'] ?? '이름 없음'),
                      subtitle: Text('patientId(=환자명): ${doc.id} / hospitalId: ${data['hospitalId'] ?? '-'}'),
                      onTap: () => loadPatientAndHospital(patientIdFromList: doc.id),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _patientIdCtrl,
            decoration: const InputDecoration(
              labelText: '환자 ID (환자명과 동일, 직접 입력 또는 목록 탭)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: loadPatientAndHospital,
            child: const Text('환자/병원/복약 정보 불러오기'),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('환자 정보', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('이름: ${_patientDoc?.data()?['name'] ?? '-'}'),
                  Text('생년월일: ${_patientDoc?.data()?['birthDate'] ?? '-'}'),
                  Text('보호자: ${_patientDoc?.data()?['guardianName'] ?? '-'}'),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('병원 정보', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('병원명: ${_hospitalDoc?.data()?['name'] ?? '-'}'),
                  Text('주소: ${_hospitalDoc?.data()?['address'] ?? '-'}'),
                  Text('연락처: ${_hospitalDoc?.data()?['phone'] ?? '-'}'),
                  Text('병원 문서 ID: ${_hospitalDoc?.id ?? '-'}'),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('복약 스케줄', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (_medScheduleDocs.isEmpty)
                    const Text('복약 스케줄이 없습니다.')
                  else
                    ..._medScheduleDocs.map((doc) {
                      final data = doc.data();
                      final times = (data['times'] as List<dynamic>? ?? [])
                          .map((e) => e.toString())
                          .join(', ');

                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '- ${data['medicineName'] ?? ''} / 용량: ${data['dosage'] ?? ''} / 시간: $times',
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class SettingsLoginPage extends StatefulWidget {
  const SettingsLoginPage({super.key});

  @override
  State<SettingsLoginPage> createState() => _SettingsLoginPageState();
}

class _SettingsLoginPageState extends State<SettingsLoginPage> {
  final _nameCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  String _status = '환자 이름/생년월일을 입력하세요.';

  Future<void> _login() async {
    final name = _nameCtrl.text.trim();
    final birthDate = _birthDateCtrl.text.trim();

    if (name.isEmpty || birthDate.isEmpty) {
      setState(() => _status = '이름과 생년월일을 모두 입력하세요.');
      return;
    }

    try {
      await _ensureSignedIn();
      setState(() => _status = '환자 정보 확인 중...');

      final queryByDocId = await FirebaseFirestore.instance
          .collection('patients')
          .doc(name)
          .get();

      bool matched = false;
      if (queryByDocId.exists) {
        final data = queryByDocId.data() ?? {};
        matched = (data['birthDate']?.toString() ?? '') == birthDate;
      }

      if (!matched) {
        final queryByFields = await FirebaseFirestore.instance
            .collection('patients')
            .where('name', isEqualTo: name)
            .where('birthDate', isEqualTo: birthDate)
            .limit(1)
            .get();
        matched = queryByFields.docs.isNotEmpty;
      }

      setState(() {
        _status = matched ? '로그인 성공' : '로그인 실패: 입력한 환자 정보와 일치하지 않습니다.';
      });

      if (matched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 성공')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _status = '로그인 오류: $e');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthDateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '로그인',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '환자 이름',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _birthDateCtrl,
            decoration: const InputDecoration(
              labelText: '생년월일 (YYYY-MM-DD)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _login,
            child: const Text('로그인'),
          ),
          const SizedBox(height: 12),
          Text('상태: $_status'),
        ],
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Text('개발중입니다.'),
      ),
    );
  }
}
