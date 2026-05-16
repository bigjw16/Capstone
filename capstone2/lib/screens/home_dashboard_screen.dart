import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../session/patient_session.dart';
import '../widgets/menu_button.dart';
import 'settings_login_page.dart';
import 'notification_register_page.dart';
import 'medication_stats_page.dart';
import 'medication_statistics_page.dart';
import 'food_management_page.dart';

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
                      MenuButton(
                        label: '알림등록',
                        icon: Icons.notifications_none,
                        onTap: () =>
                            _guardedNavigate(const NotificationRegisterPage()),
                      ),
                      MenuButton(
                        label: '복약정보',
                        icon: Icons.show_chart,
                        onTap: () =>
                            _guardedNavigate(const MedicationStatsPage()),
                      ),
                      MenuButton(
                        label: '복약통계',
                        icon: Icons.medication,
                        onTap: () =>
                            _guardedNavigate(const MedicationStatisticsPage()),
                      ),
                      MenuButton(
                        label: '식품관리',
                        icon: Icons.emoji_emotions_outlined,
                        onTap: () =>
                            _guardedNavigate(const FoodManagementPage()),
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
        const weekdays = ['일', '월', '화', '수', '목', '금', '토'];

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