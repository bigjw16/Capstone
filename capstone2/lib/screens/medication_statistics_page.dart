import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../session/patient_session.dart';
import '../widgets/chick_card.dart';
import '../widgets/chick_scaffold.dart';

class MedicationStatisticsPage extends StatefulWidget {
  const MedicationStatisticsPage({super.key});

  @override
  State<MedicationStatisticsPage> createState() =>
      _MedicationStatisticsPageState();
}

class _MedicationStatisticsPageState extends State<MedicationStatisticsPage> {
  static const _pageLoadTimeout = Duration(seconds: 30);

  Future<_MedicationStatistics>? _statisticsFuture;
  String? _loadedPatientId;

  Future<_MedicationStatistics> _loadStatistics(String patientId) {
    return _MedicationStatisticsRepository().load(patientId).timeout(
      _pageLoadTimeout,
    );
  }

  Future<_MedicationStatistics> _futureFor(String patientId) {
    if (patientId != _loadedPatientId || _statisticsFuture == null) {
      _loadedPatientId = patientId;
      _statisticsFuture = _loadStatistics(patientId);
    }

    return _statisticsFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: PatientSession.patientId,
      builder: (context, patientId, _) {
        return ChickScaffold(
          title: '복약통계',
          child: patientId == null || patientId.isEmpty
              ? const Center(
              child: Text(
                '환자 로그인 후 복약통계를 확인할 수 있습니다.',
                style: TextStyle(
                  color: chickBrown,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : FutureBuilder<_MedicationStatistics>(
              future: _futureFor(patientId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '복약통계를 불러오지 못했습니다.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: chickBrown),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _statisticsFuture = _loadStatistics(patientId);
                              });
                            },
                            child: const Text('다시 불러오기'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final statistics = snapshot.data ?? _MedicationStatistics.empty;
                return _MedicationStatisticsView(statistics: statistics);
              },
                ),
        );
      },
    );
  }
}

class _MedicationStatisticsView extends StatelessWidget {
  const _MedicationStatisticsView({required this.statistics});

  final _MedicationStatistics statistics;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                        value: statistics.takenRate,
                        strokeWidth: 20,
                        color: chickOrange,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${statistics.percent}%',
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
                  title: '전체 알림 날짜',
                  value: '${statistics.totalScheduledCount}일',
                  icon: Icons.calendar_month,
                ),
                _StatisticsInfoTile(
                  title: '먹은 횟수',
                  value: '${statistics.takenCount}회',
                  icon: Icons.check_circle,
                ),
                _StatisticsInfoTile(
                  title: '안 먹은 횟수',
                  value: '${statistics.missedCount}회',
                  icon: Icons.cancel,
                ),
                const SizedBox(height: 8),
                Text(
                  'Firestore 환자 ID: ${statistics.firestorePatientId}\nRTDB 환자 ID: ${statistics.rtdbPatientId}',
                  style: const TextStyle(color: chickBrown),
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
                if (statistics.missedDays.isEmpty)
                  const Text('안 먹은 날이 없습니다.')
                else
                  ...statistics.missedDays.map(
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
    );
  }
}

class _MedicationStatisticsRepository {
  static const _requestTimeout = Duration(seconds: 10);

  Future<_MedicationStatistics> load(String firestorePatientId) async {
    final patientDoc = await FirebaseFirestore.instance
        .collection('patients')
        .doc(firestorePatientId)
        .get()
        .timeout(_requestTimeout);

    final patientData = patientDoc.data() ?? <String, dynamic>{};
    final rtdbPatientId = _firstString(
      patientData,
      const ['rtdbPatientId', 'esp8266PatientId', 'devicePatientId'],
    ) ?? firestorePatientId;

    final scheduleSnapshot = await FirebaseFirestore.instance
        .collection('patients')
        .doc(firestorePatientId)
        .collection('medSchedules')
        .get()
        .timeout(_requestTimeout);

    final scheduledOccurrences = <String, String>{};
    final today = _dateOnly(DateTime.now());

    for (final scheduleDoc in scheduleSnapshot.docs) {
      scheduledOccurrences.addAll(
        _scheduledOccurrencesFrom(
          scheduleId: scheduleDoc.id,
          data: scheduleDoc.data(),
          today: today,
        ),
      );
    }

    final takenOccurrences = await _loadTakenOccurrences(
      firestorePatientId: firestorePatientId,
      rtdbPatientId: rtdbPatientId,
    );
    final takenCount = scheduledOccurrences.keys
        .where((key) => _isTakenOccurrence(key, takenOccurrences))
        .length;
    final missedDays = scheduledOccurrences.entries
        .where((entry) => !_isTakenOccurrence(entry.key, takenOccurrences))
        .map((entry) => entry.value)
        .toList()
      ..sort();

    return _MedicationStatistics(
      firestorePatientId: firestorePatientId,
      rtdbPatientId: rtdbPatientId,
      totalScheduledCount: scheduledOccurrences.length,
      takenCount: takenCount,
      missedDays: missedDays,
    );
  }

  Map<String, String> _scheduledOccurrencesFrom({
    required String scheduleId,
    required Map<String, dynamic> data,
    required DateTime today,
  }) {
    final days = _scheduledDaysFrom(data, today);
    return {
      for (final day in days) _occurrenceKey(day, scheduleId): day,
    };
  }

  Set<String> _scheduledDaysFrom(Map<String, dynamic> data, DateTime today) {
    final start = _readDate(data['alarmDate']) ??
        _readDate(data['date']) ??
        _readDate(data['alarmAt']) ??
        _readDate(data['createdAt']);

    if (start == null) return <String>{};

    final repeatDaily = data['repeatDaily'] == true;
    final repeatWeekdays = (data['repeatWeekdays'] as List<dynamic>? ?? [])
        .map((value) => int.tryParse(value.toString()))
        .whereType<int>()
        .toSet();

    final repeatUntil = _readDate(data['repeatUntilAt']) ??
        _readDate(data['repeatUntilDate']) ??
        start;

    final end = _minDate(_dateOnly(repeatUntil), today);
    final normalizedStart = _dateOnly(start);

    if (end.isBefore(normalizedStart)) return <String>{};

    if (!repeatDaily && repeatWeekdays.isEmpty) {
      return {_formatDate(normalizedStart)};
    }

    final days = <String>{};
    for (var day = normalizedStart;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      final matchesDaily = repeatDaily;
      final matchesWeekday = repeatWeekdays.contains(day.weekday % 7);

      if (matchesDaily || matchesWeekday) {
        days.add(_formatDate(day));
      }
    }

    return days;
  }

  Future<Set<String>> _loadTakenOccurrences({
    required String firestorePatientId,
    required String rtdbPatientId,
  }) async {
    final occurrences = <String>{};
    final paths = <String>[
      'medicationResponses/$firestorePatientId',
      'medicationResponses/$rtdbPatientId',
      'patients/$rtdbPatientId/medLogs',
      'medicationResponses',
    ];
    final patientIds = {firestorePatientId, rtdbPatientId};

    final snapshots = await Future.wait(paths.map(_readRtdbPath));
    for (var i = 0; i < snapshots.length; i++) {
      final snapshot = snapshots[i];
      if (snapshot == null || !snapshot.exists) continue;
      _collectTakenOccurrences(
        value: snapshot.value,
        occurrences: occurrences,
        patientIds: patientIds,
        requirePatientMatch: paths[i] == 'medicationResponses',
      );
    }

    return occurrences;
  }

  Future<DataSnapshot?> _readRtdbPath(String path) async {
    try {
      return await FirebaseDatabase.instance
          .ref(path)
          .get()
          .timeout(_requestTimeout);
    } catch (_) {
      return null;
    }
  }

  void _collectTakenOccurrences({
    required Object? value,
    required Set<String> occurrences,
    required Set<String> patientIds,
    bool requirePatientMatch = false,
  }) {
    void collect(Object? key, Object? entry) {
      final date = _dateFromLogEntry(key?.toString() ?? '', entry);

      if (date == null) {
        if (entry is Map) {
          entry.forEach(collect);
        } else if (entry is List) {
          for (var i = 0; i < entry.length; i++) {
            collect(i, entry[i]);
          }
        }
        return;
      }

      if (!_logBelongsToPatient(
        entry: entry,
        patientIds: patientIds,
        requirePatientMatch: requirePatientMatch,
      )) {
        return;
      }

      final dateKey = _formatDate(date);
      final scheduleId = _scheduleIdFromLogEntry(entry);
      occurrences.add(_occurrenceKey(dateKey, scheduleId));
      if (scheduleId.isEmpty) occurrences.add(_dateOnlyOccurrenceKey(dateKey));
    }

    collect('', value);
  }

  DateTime? _dateFromLogEntry(String key, Object? entry) {
    if (entry is Map) {
      for (final field in const [
        'takenAt',
        'scheduledDate',
        'date',
        'time',
        'timestamp',
        'createdAt',
      ]) {
        final date = _readDate(entry[field]);
        if (date != null) return date;
      }
    }

    return _readDate(entry) ?? _readDate(key);
  }

  bool _logBelongsToPatient({
    required Object? entry,
    required Set<String> patientIds,
    required bool requirePatientMatch,
  }) {
    if (entry is! Map) return !requirePatientMatch;

    final value = entry['patientId']?.toString().trim();
    if (value == null || value.isEmpty) return !requirePatientMatch;
    return patientIds.contains(value);
  }

  String _scheduleIdFromLogEntry(Object? entry) {
    if (entry is Map) {
      final value = entry['scheduleId']?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  bool _isTakenOccurrence(String scheduledKey, Set<String> takenOccurrences) {
    final date = scheduledKey.split('|').first;
    return takenOccurrences.contains(scheduledKey) ||
        takenOccurrences.contains(_dateOnlyOccurrenceKey(date));
  }

  String _occurrenceKey(String date, String scheduleId) => '$date|$scheduleId';

  String _dateOnlyOccurrenceKey(String date) => '$date|*';

  String? _firstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime? _readDate(Object? value) {
    if (value == null) return null;

    if (value is Timestamp) return _dateOnly(value.toDate());
    if (value is DateTime) return _dateOnly(value);
    if (value is int) {
      final milliseconds = value > 9999999999 ? value : value * 1000;
      return _dateOnly(DateTime.fromMillisecondsSinceEpoch(milliseconds));
    }
    if (value is double) {
      return _readDate(value.toInt());
    }

    final text = value.toString();
    final match = RegExp(r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(text);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }

    return null;
  }

  String _formatDate(DateTime date) {
    final normalized = _dateOnly(date);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }
}

class _MedicationStatistics {
  const _MedicationStatistics({
    required this.firestorePatientId,
    required this.rtdbPatientId,
    required this.totalScheduledCount,
    required this.takenCount,
    required this.missedDays,
  });

  static const empty = _MedicationStatistics(
    firestorePatientId: '-',
    rtdbPatientId: '-',
    totalScheduledCount: 0,
    takenCount: 0,
    missedDays: [],
  );

  factory _MedicationStatistics.emptyFor(String patientId) {
    return _MedicationStatistics(
      firestorePatientId: patientId,
      rtdbPatientId: patientId,
      totalScheduledCount: 0,
      takenCount: 0,
      missedDays: const [],
    );
  }

  final String firestorePatientId;
  final String rtdbPatientId;
  final int totalScheduledCount;
  final int takenCount;
  final List<String> missedDays;

  int get missedCount => missedDays.length;
  double get takenRate =>
      totalScheduledCount == 0 ? 0 : takenCount / totalScheduledCount;
  int get percent => (takenRate * 100).round();
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