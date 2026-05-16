import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

const Color chickYellow = Color(0xFFFFE978);
const Color chickOrange = Color(0xFFF4A646);
const Color chickBrown = Color(0xFF3B2A12);
const Color chickRed = Color(0xFFE24A2A);

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

class PatientSession {
  static final ValueNotifier<String?> patientId = ValueNotifier<String?>(null);

  static bool get isLoggedIn =>
      patientId.value != null && patientId.value!.isNotEmpty;

  static void login(String id) {
    patientId.value = id;
  }

  static void logout() {
    patientId.value = null;
  }
}

class PatientMedSyncApp extends StatelessWidget {
  const PatientMedSyncApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patient Med Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: chickOrange,
        useMaterial3: true,
        scaffoldBackgroundColor: chickYellow,
      ),
      home: startupError == null
          ? const SwipeHomeContainer()
          : StartupErrorScreen(errorText: startupError!),
    );
  }
}

/* ---------------- 공통 UI ---------------- */

class ChickScaffold extends StatelessWidget {
  const ChickScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chickYellow,
      appBar: AppBar(
        backgroundColor: chickYellow,
        elevation: 0,
        foregroundColor: chickBrown,
        title: Text(
          title,
          style: const TextStyle(
            color: chickBrown,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: actions,
      ),
      body: child,
    );
  }
}

class ChickCard extends StatelessWidget {
  const ChickCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
  });

  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: margin ?? const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

InputDecoration chickInput(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
  );
}

/* ---------------- 페이지 컨테이너 ---------------- */

class SwipeHomeContainer extends StatelessWidget {
  const SwipeHomeContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return PageView(
      scrollDirection: Axis.horizontal,
      children: const [
        TodayHomePage(),
        HomeDashboardScreen(),
      ],
    );
  }
}

/* ---------------- 오늘 페이지 ---------------- */

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
                '$todayText',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: chickBrown,
                ),
              ),
            ),
          ),
          const ChickCard(
            child: Center(
              child: Text(
                '개발중',
                style: TextStyle(fontSize: 20, color: Colors.grey),
              ),
            ),
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
                            final times =
                                (data['times'] as List<dynamic>? ?? [])
                                    .join(', ');

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

/* ---------------- Firebase 오류 화면 ---------------- */

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

/* ---------------- 홈 대시보드 ---------------- */

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  Future<void> _openSettingsLogin() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SettingsLoginPage()),
    );

    if (result != null) {
      PatientSession.login(result);
      setState(() {});
    }
  }

  void _guardedNavigate(Widget page) {
    if (!PatientSession.isLoggedIn) {
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
      backgroundColor: chickYellow,
      body: SafeArea(
        child: Container(
          color: chickYellow,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        PatientSession.isLoggedIn ? '복약 관리 홈' : '로그인이 필요해요',
                        style: const TextStyle(
                          color: chickBrown,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.settings,
                        color: chickBrown,
                        size: 32,
                      ),
                      onPressed: _openSettingsLogin,
                    ),
                  ],
                ),
              ),
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
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const MedicationCalendarWidget(),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.35,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _MenuButton(
                        label: '알림등록',
                        icon: Icons.notifications_none,
                        onTap: () =>
                            _guardedNavigate(const NotificationRegisterPage()),
                      ),
                      _MenuButton(
                        label: '복약정보',
                        icon: Icons.show_chart,
                        onTap: () =>
                            _guardedNavigate(const MedicationStatsPage()),
                      ),
                      _MenuButton(
                        label: '복약통계',
                        icon: Icons.medication,
                        onTap: () =>
                            _guardedNavigate(const MedicationStatisticsPage()),
                      ),
                      _MenuButton(
                        label: '식품관리',
                        icon: Icons.emoji_emotions_outlined,
                        onTap: () => _guardedNavigate(
                          const FoodManagementPage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------- 캘린더 ---------------- */

class MedicationCalendarWidget extends StatefulWidget {
  const MedicationCalendarWidget({super.key});

  @override
  State<MedicationCalendarWidget> createState() =>
      _MedicationCalendarWidgetState();
}

class _MedicationCalendarWidgetState extends State<MedicationCalendarWidget> {
  DateTime _focusedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DateTime> _buildMonthCells(DateTime monthStart) {
    final firstWeekday = monthStart.weekday % 7;
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
              DateTime(
                monthEnd.year,
                monthEnd.month,
                monthEnd.day,
                23,
                59,
                59,
              ),
            ),
          )
          .where(
            'repeatUntilAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
          )
          .snapshots(),
      builder: (context, snapshot) {
        final marked = <DateTime>{};

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final alarmTs = data['alarmAt'] ?? data['createdAt'];
            final untilTs = data['repeatUntilAt'];
            final isRepeatDaily = data['repeatDaily'] == true;

            final weekdays = (data['repeatWeekdays'] as List<dynamic>? ?? [])
                .map((e) => e as int)
                .toSet();

            if (alarmTs is! Timestamp) continue;

            final start = _dateOnly(alarmTs.toDate());
            final until =
                untilTs is Timestamp ? _dateOnly(untilTs.toDate()) : start;

            if (isRepeatDaily || weekdays.isNotEmpty) {
              final from = start.isAfter(monthStart) ? start : monthStart;
              final to = until.isBefore(monthEnd) ? until : monthEnd;

              for (DateTime d = from;
                  !d.isAfter(to);
                  d = d.add(const Duration(days: 1))) {
                final weekday = d.weekday % 7;

                if (isRepeatDaily || weekdays.contains(weekday)) {
                  marked.add(_dateOnly(d));
                }
              }
            } else if (!start.isBefore(monthStart) &&
                !start.isAfter(monthEnd)) {
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
                  color: chickBrown,
                  onPressed: () => setState(
                    () => _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month - 1,
                      1,
                    ),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${_focusedMonth.year}년 ${_focusedMonth.month}월',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: chickBrown,
                  ),
                ),
                IconButton(
                  color: chickBrown,
                  onPressed: () => setState(
                    () => _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month + 1,
                      1,
                    ),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: weekdays
                  .map(
                    (w) => Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: chickBrown,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                ),
                itemCount: cells.length,
                itemBuilder: (_, i) {
                  final day = cells[i];
                  final isCurrentMonth = day.month == _focusedMonth.month;
                  final hasAlarm = marked.contains(_dateOnly(day));

                  return Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isCurrentMonth
                          ? chickYellow.withOpacity(0.35)
                          : Colors.grey.shade100,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isCurrentMonth ? chickBrown : Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (hasAlarm)
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: chickRed,
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

/* ---------------- 메뉴 버튼 ---------------- */

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: chickOrange,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.circle,
              size: 44,
              color: chickBrown,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: chickBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- 알림 등록 ---------------- */

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
        const SnackBar(
          content: Text('알림이 삭제되었습니다.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제 실패: $e'),
        ),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
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
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                      },
                                                      child: const Text('취소'),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: FilledButton(
                                                      style: FilledButton
                                                          .styleFrom(
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
                            value: 'breakfast',
                            child: Text('아침'),
                          ),
                          DropdownMenuItem(
                            value: 'lunch',
                            child: Text('점심'),
                          ),
                          DropdownMenuItem(
                            value: 'dinner',
                            child: Text('저녁'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              mealTime = v;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: mealType,
                        decoration: chickInput('식사 여부'),
                        items: const [
                          DropdownMenuItem(
                            value: 'before_meal',
                            child: Text('식전'),
                          ),
                          DropdownMenuItem(
                            value: 'after_meal',
                            child: Text('식후'),
                          ),
                          DropdownMenuItem(
                            value: 'empty_stomach',
                            child: Text('공복'),
                          ),
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
                        '복약 정보: '
                        '${getMealTimeLabel(mealTime)} '
                        '${getMealTypeLabel(mealType)}',
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
                              initialDate: _repeatUntilDate ?? DateTime.now(),
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
                                    Text('시간: $times'),
                                    Text(
                                      '복용: ${data['mealLabel'] ?? '-'}',
                                    ),
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
                                          content:
                                              const Text('저장된 알림을 삭제하시겠습니까?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('취소'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
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

/* ---------------- 시간 선택 스피너 ---------------- */

class TimePickerSpinner extends StatefulWidget {
  const TimePickerSpinner({
    super.key,
    required this.duration,
    required this.onChanged,
  });

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
    _hourCtrl = FixedExtentScrollController(
      initialItem: widget.duration.inHours % 24,
    );
    _minuteCtrl = FixedExtentScrollController(
      initialItem: widget.duration.inMinutes % 60,
    );
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
              builder: (_, i) => Center(
                child: Text(
                  '${i.toString().padLeft(2, '0')}시',
                  style: const TextStyle(
                    color: chickBrown,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
              builder: (_, i) => Center(
                child: Text(
                  '${i.toString().padLeft(2, '0')}분',
                  style: const TextStyle(
                    color: chickBrown,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/* ---------------- 복약 정보 ---------------- */

class MedicationStatsPage extends StatefulWidget {
  const MedicationStatsPage({super.key});

  @override
  State<MedicationStatsPage> createState() => _MedicationStatsPageState();
}

class _MedicationStatsPageState extends State<MedicationStatsPage> {
  final _patientIdCtrl = TextEditingController();
  DocumentSnapshot<Map<String, dynamic>>? _patientDoc;
  DocumentSnapshot<Map<String, dynamic>>? _hospitalDoc;
  DocumentSnapshot<Map<String, dynamic>>? _pharmacyDoc;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _medScheduleDocs = [];
  String _status = '준비 완료';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadPatientAndHospital();
    });
  }

  Future<void> loadPatientAndHospital({String? patientIdFromList}) async {
    final patientId = (patientIdFromList ??
            PatientSession.patientId.value ??
            _patientIdCtrl.text)
        .trim();

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
          _pharmacyDoc = null;
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
      final pharmacyId = patient.data()?['pharmacyId'] as String?;
      final pharmacyName = patient.data()?['pharmacyName'] as String?;
      DocumentSnapshot<Map<String, dynamic>>? pharmacy;

      if (pharmacyId != null && pharmacyId.isNotEmpty) {
        final pharmacyById = await FirebaseFirestore.instance
            .collection('pharmacies')
            .doc(pharmacyId)
            .get();

        if (pharmacyById.exists) {
          pharmacy = pharmacyById;
        }
      }

      if (pharmacy == null && pharmacyName != null && pharmacyName.isNotEmpty) {
        final pharmacyByName = await FirebaseFirestore.instance
            .collection('pharmacies')
            .where('name', isEqualTo: pharmacyName)
            .limit(1)
            .get();

        if (pharmacyByName.docs.isNotEmpty) {
          pharmacy = pharmacyByName.docs.first;
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
        _pharmacyDoc = pharmacy;
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
    return ChickScaffold(
      title: '복약정보',
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            '상태: $_status',
            style: const TextStyle(color: chickBrown),
          ),
          ChickCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '환자 정보',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: chickBrown,
                  ),
                ),
                Text('이름: ${_patientDoc?.data()?['name'] ?? '-'}'),
                Text('생년월일: ${_patientDoc?.data()?['birthDate'] ?? '-'}'),
                Text('보호자: ${_patientDoc?.data()?['guardianName'] ?? '-'}'),
              ],
            ),
          ),
          ChickCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '병원 정보',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: chickBrown,
                  ),
                ),
                Text('병원명: ${_hospitalDoc?.data()?['name'] ?? '-'}'),
                Text('주소: ${_hospitalDoc?.data()?['address'] ?? '-'}'),
                Text('연락처: ${_hospitalDoc?.data()?['phone'] ?? '-'}'),
              ],
            ),
          ),
          ChickCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '약국 정보',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: chickBrown,
                  ),
                ),
                Text(
                    '약국명: ${_pharmacyDoc?.data()?['name'] ?? _patientDoc?.data()?['pharmacyName'] ?? '-'}'),
                Text(
                    '주소: ${_pharmacyDoc?.data()?['address'] ?? _patientDoc?.data()?['pharmacyAddress'] ?? '-'}'),
                Text(
                    '연락처: ${_pharmacyDoc?.data()?['phone'] ?? _patientDoc?.data()?['pharmacyPhone'] ?? '-'}')
              ],
            ),
          ),
          ChickCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '복약 스케줄',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: chickBrown,
                  ),
                ),
                if (_medScheduleDocs.isEmpty)
                  const Text('복약 스케줄이 없습니다.')
                else
                  ..._medScheduleDocs.map((doc) {
                    final data = doc.data();
                    final times =
                        (data['times'] as List<dynamic>? ?? []).join(', ');

                    return ListTile(
                      leading: const Icon(
                        Icons.medication,
                        color: chickOrange,
                      ),
                      title: Text('${data['medicineName'] ?? ''}'),
                      subtitle: Text(
                        '용량: ${data['dosage'] ?? ''} / 시간: $times',
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- 설정 로그인 ---------------- */

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
        PatientSession.login(name);
        Navigator.of(context).pop(name);
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
    return ChickScaffold(
      title: '설정',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ChickCard(
            child: Text(
              '로그인',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: chickBrown,
              ),
            ),
          ),
          ChickCard(
            child: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: chickInput('환자 이름'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _birthDateCtrl,
                  decoration: chickInput('생년월일 (YYYY-MM-DD)'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: chickOrange,
                    foregroundColor: chickBrown,
                  ),
                  onPressed: _login,
                  child: const Text('로그인'),
                ),
                const SizedBox(height: 12),
                Text('상태: $_status'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- 개발중 페이지 ---------------- */

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ChickScaffold(
      title: title,
      child: const Center(
        child: ChickCard(
          child: Text(
            '개발중입니다.',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: chickBrown,
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- 복약 통계 ---------------- */

class MedicationStatisticsPage extends StatelessWidget {
  const MedicationStatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const int takenCount = 18;
    const int missedCount = 6;
    const List<String> missedDays = [
      '2026-05-01',
      '2026-05-03',
      '2026-05-06',
    ];

    final int totalCount = takenCount + missedCount;
    final double takenRate = totalCount == 0 ? 0 : takenCount / totalCount;
    final int percent = (takenRate * 100).round();

    return ChickScaffold(
      title: '복약통계',
      child: Column(
        children: [
          Expanded(
            child: ChickCard(
              child: Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: takenRate,
                          strokeWidth: 20,
                          color: chickOrange,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$percent%',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: chickBrown,
                            ),
                          ),
                          const Text('복약률'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ChickCard(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ListView(
                children: [
                  const Text(
                    '복약 상세 통계',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: chickBrown,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatisticsInfoTile(
                    title: '먹은 횟수',
                    value: '$takenCount회',
                    icon: Icons.check_circle,
                  ),
                  _StatisticsInfoTile(
                    title: '안 먹은 횟수',
                    value: '$missedCount회',
                    icon: Icons.cancel,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '안 먹은 날',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: chickBrown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (missedDays.isEmpty)
                    const Text('안 먹은 날이 없습니다.')
                  else
                    ...missedDays.map(
                      (day) => ListTile(
                        leading: const Icon(
                          Icons.warning_amber_rounded,
                          color: chickOrange,
                        ),
                        title: Text(day),
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

class _StatisticsInfoTile extends StatelessWidget {
  const _StatisticsInfoTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: chickYellow.withOpacity(0.45),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        leading: Icon(icon, color: chickOrange),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: chickBrown,
          ),
        ),
      ),
    );
  }
}

class FoodManagementPage extends StatefulWidget {
  const FoodManagementPage({super.key});

  @override
  State<FoodManagementPage> createState() => _FoodManagementPageState();
}

class _FoodManagementPageState extends State<FoodManagementPage> {
  bool _loading = true;

  List<Map<String, dynamic>> _foodInfos = [];

  @override
  void initState() {
    super.initState();
    _loadFoodInfo();
  }

  Future<void> _loadFoodInfo() async {
    try {
      final patientId = PatientSession.patientId.value ?? 'default-patient';

      // 1. 환자 복용 약 조회
      final medSnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .collection('medSchedules')
          .get();

      final medicineNames = medSnapshot.docs
          .map((e) => e.data()['medicineName']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      List<Map<String, dynamic>> loadedFoods = [];

      // 2. 약 → 성분 → foodInteractions 매핑
      for (final medicineName in medicineNames) {
        final medicineDoc = await FirebaseFirestore.instance
            .collection('medicines')
            .doc(medicineName)
            .get();

        if (!medicineDoc.exists) continue;

        final medicineData = medicineDoc.data() ?? {};
        final ingredients =
            List<String>.from(medicineData['ingredients'] ?? []);

        List<Map<String, dynamic>> allFoods = [];

        for (final ingredient in ingredients) {
          final foodDoc = await FirebaseFirestore.instance
              .collection('foodInteractions')
              .doc(ingredient)
              .get();

          if (!foodDoc.exists) continue;

          final foodData = foodDoc.data() ?? {};

          final foods = List<Map<String, dynamic>>.from(
            foodData['foods'] ?? [],
          );

          for (final food in foods) {
            allFoods.add({
              "food": food['food'] ?? '',
              "severity": food['severity'] ?? 'low',
              "reason": food['reason'] ?? '',
              "ingredient": ingredient,
            });
          }
        }

        loadedFoods.add({
          "medicineName": medicineName,
          "ingredients": ingredients,
          "foods": allFoods,
        });
      }

      setState(() {
        _foodInfos = loadedFoods;
        _loading = false;
      });
    } catch (e) {
      debugPrint("식품 정보 로딩 실패: $e");
      setState(() {
        _loading = false;
      });
    }
  }

  // 🔥 severity 색상
  Color _severityColor(String severity) {
    switch (severity) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  // 🔥 severity 라벨
  String _severityLabel(String severity) {
    switch (severity) {
      case 'high':
        return '🔴 매우 위험';
      case 'medium':
        return '🟡 주의';
      default:
        return '🟢 안전';
    }
  }

  Widget _foodChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: chickBrown,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChickScaffold(
      title: '식품관리',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _foodInfos.isEmpty
              ? const Center(
                  child: Text(
                    '등록된 음식 정보가 없습니다.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: chickBrown,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _foodInfos.length,
                  itemBuilder: (_, index) {
                    final data = _foodInfos[index];

                    final medicineName = data['medicineName'] ?? '-';

                    final ingredients =
                        (data['ingredients'] as List<dynamic>? ?? [])
                            .map((e) => e.toString())
                            .toList();

                    final foods = (data['foods'] as List<dynamic>? ?? [])
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();

                    return ChickCard(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 약 이름
                          Row(
                            children: [
                              const Icon(
                                Icons.medication,
                                color: chickOrange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                medicineName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: chickBrown,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // 성분
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ingredients.isEmpty
                                ? [const Text('등록된 성분 없음')]
                                : ingredients
                                    .map(
                                      (ingredient) => _foodChip(
                                        ingredient,
                                        Colors.orange,
                                      ),
                                    )
                                    .toList(),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            '음식 상호작용 위험도',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: chickBrown,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Column(
                            children: foods.isEmpty
                                ? [const Text('등록된 정보 없음')]
                                : foods.map((food) {
                                    final name = food['food'] ?? '-';
                                    final severity = food['severity'] ?? 'low';
                                    final reason = food['reason'] ?? '';
                                    final ingredient = food['ingredient'] ?? '';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _severityColor(severity)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _severityColor(severity),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _foodChip(
                                            "${_severityLabel(severity)} $name",
                                            _severityColor(severity),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "성분: $ingredient",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          if (reason.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              reason,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
