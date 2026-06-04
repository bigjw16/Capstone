import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import 'chick_card.dart';

class TodayRewardCard extends StatefulWidget {
  const TodayRewardCard({
    super.key,
    required this.patientId,
    required this.today,
  });

  final String patientId;
  final DateTime today;

  @override
  State<TodayRewardCard> createState() => _TodayRewardCardState();
}

class _TodayRewardCardState extends State<TodayRewardCard> {
  late Future<_TodayRewardState> _future;
  String? _loadedPatientId;
  String? _loadedDateKey;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant TodayRewardCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final dateKey = _formatDate(widget.today);
    if (widget.patientId != _loadedPatientId || dateKey != _loadedDateKey) {
      _future = _load();
    }
  }

  Future<_TodayRewardState> _load() {
    _loadedPatientId = widget.patientId;
    _loadedDateKey = _formatDate(widget.today);
    return _TodayRewardRepository().loadAndReward(
      patientId: widget.patientId,
      today: widget.today,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChickCard(
      child: FutureBuilder<_TodayRewardState>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 96,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return _RewardMessage(
              icon: Icons.error_outline,
              title: '리워드 정보를 불러오지 못했습니다.',
              subtitle: '${snapshot.error}',
              actionLabel: '다시 확인',
              onAction: _reload,
            );
          }

          final state =
              snapshot.data ?? _TodayRewardState.empty(widget.patientId);
          final remaining = max(state.scheduledCount - state.takenCount, 0);

          if (state.scheduledCount == 0) {
            return _RewardMessage(
              icon: Icons.event_available,
              title: '총 리워드 ${state.totalRewardAmount}원',
              subtitle:
                  '오늘은 복약 알림이 없습니다. 알림이 있는 날에 모두 복용하면 랜덤 포인트를 받을 수 있어요.',
            );
          }

          if (state.rewardAmount > 0) {
            return _RewardMessage(
              icon: Icons.card_giftcard,
              title: '${state.rewardAmount}원 리워드 지급 완료!',
              subtitle:
                  '오늘 복약 ${state.takenCount}/${state.scheduledCount}회를 모두 완료했습니다. '
                  '총 리워드: ${state.totalRewardAmount}원',
              actionLabel: '새로고침',
              onAction: _reload,
            );
          }

          return _RewardMessage(
            icon: Icons.savings,
            title: '오늘 복약 ${state.takenCount}/${state.scheduledCount}회 완료',
            subtitle: remaining == 0
                ? '복약 완료 확인 중입니다. 잠시 후 다시 확인해 주세요. '
                    '총 리워드: ${state.totalRewardAmount}원'
                : '$remaining회 더 복용하면 1~5원 랜덤 리워드를 받을 수 있어요. '
                    '총 리워드: ${state.totalRewardAmount}원',
            actionLabel: '복약 기록 확인',
            onAction: _reload,
          );
        },
      ),
    );
  }
}

class _TodayRewardRepository {
  static const _timeout = Duration(seconds: 10);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  Future<_TodayRewardState> loadAndReward({
    required String patientId,
    required DateTime today,
  }) async {
    final dateKey = _formatDate(today);
    final patientRef = _firestore.collection('patients').doc(patientId);
    final patientSnap = await patientRef.get().timeout(_timeout);
    final patientData = patientSnap.data() ?? <String, dynamic>{};
    final rtdbPatientId = _firstString(
          patientData,
          const ['rtdbPatientId', 'esp8266PatientId', 'devicePatientId'],
        ) ??
        patientId;

    final schedulesSnap = await patientRef
        .collection('medSchedules')
        .get()
        .timeout(_timeout);

    final scheduledCount = schedulesSnap.docs.fold<int>(0, (total, doc) {
      final data = doc.data();
      if (!_isDueOn(data, today)) return total;
      return total + _scheduledDoseCount(data);
    });

    final takenCount = await _loadTakenCount(
      patientId: patientId,
      rtdbPatientId: rtdbPatientId,
      dateKey: dateKey,
    );

    final rewardRef = patientRef.collection('rewardDays').doc(dateKey);
    final rewardSnap = await rewardRef.get().timeout(_timeout);
    final existingReward = _intValue(rewardSnap.data()?['amount']);

    if (existingReward > 0) {
      return _TodayRewardState(
        patientId: patientId,
        rtdbPatientId: rtdbPatientId,
        dateKey: dateKey,
        scheduledCount: scheduledCount,
        takenCount: min(takenCount, scheduledCount),
        rewardAmount: existingReward,
        totalRewardAmount: await _loadTotalRewardAmount(patientRef),
      );
    }

    final allTaken = scheduledCount > 0 && takenCount >= scheduledCount;
    if (!allTaken) {
      return _TodayRewardState(
        patientId: patientId,
        rtdbPatientId: rtdbPatientId,
        dateKey: dateKey,
        scheduledCount: scheduledCount,
        takenCount: min(takenCount, scheduledCount),
        rewardAmount: 0,
        totalRewardAmount: await _loadTotalRewardAmount(patientRef),
      );
    }

    final rewardAmount = await _firestore.runTransaction<int>((transaction) async {
      final freshReward = await transaction.get(rewardRef);
      final amount = _intValue(freshReward.data()?['amount']);
      if (amount > 0) return amount;

      final newAmount = Random().nextInt(5) + 1;
      transaction.set(rewardRef, {
        'amount': newAmount,
        'date': dateKey,
        'patientId': patientId,
        'rtdbPatientId': rtdbPatientId,
        'scheduledCount': scheduledCount,
        'takenCount': takenCount,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return newAmount;
    }).timeout(_timeout);

    return _TodayRewardState(
      patientId: patientId,
      rtdbPatientId: rtdbPatientId,
      dateKey: dateKey,
      scheduledCount: scheduledCount,
      takenCount: min(takenCount, scheduledCount),
      rewardAmount: rewardAmount,
      totalRewardAmount: await _loadTotalRewardAmount(patientRef),
    );
  }

  Future<int> _loadTotalRewardAmount(
    DocumentReference<Map<String, dynamic>> patientRef,
  ) async {
    final rewardsSnap = await patientRef
        .collection('rewardDays')
        .get()
        .timeout(_timeout);

    return rewardsSnap.docs.fold<int>(
      0,
      (total, doc) => total + _intValue(doc.data()['amount']),
    );
  }

  int _scheduledDoseCount(Map<String, dynamic> data) {
    final times = data['times'];
    if (times is List && times.isNotEmpty) return times.length;
    return 1;
  }

  Future<int> _loadTakenCount({
    required String patientId,
    required String rtdbPatientId,
    required String dateKey,
  }) async {
    final takenLogKeys = <String>{};
    final paths = <String>{
      'medicationResponses/$patientId',
      'medicationResponses/$rtdbPatientId',
      'patients/$rtdbPatientId/medLogs',
    };

    for (final path in paths) {
      final snapshot = await _readRtdbPath(path);
      if (snapshot == null || !snapshot.exists) continue;
      _collectTakenLogKeys(
        value: snapshot.value,
        path: path,
        dateKey: dateKey,
        takenLogKeys: takenLogKeys,
      );
    }

    return takenLogKeys.length;
  }

  Future<DataSnapshot?> _readRtdbPath(String path) async {
    try {
      return await _database.ref(path).get().timeout(_timeout);
    } catch (_) {
      return null;
    }
  }

  void _collectTakenLogKeys({
    required Object? value,
    required String path,
    required String dateKey,
    required Set<String> takenLogKeys,
  }) {
    void collect(Object? key, Object? entry) {
      final entryDate = _dateFromLogEntry(key?.toString() ?? '', entry);
      if (entryDate == null || _formatDate(entryDate) != dateKey) return;
      takenLogKeys.add('$path/${key ?? takenLogKeys.length}');
    }

    if (value is Map) {
      value.forEach(collect);
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        collect(i, value[i]);
      }
    } else {
      collect('single', value);
    }
  }

  bool _isDueOn(Map<String, dynamic> data, DateTime day) {
    final start = _readDate(data['alarmDate']) ??
        _readDate(data['date']) ??
        _readDate(data['alarmAt']) ??
        _readDate(data['createdAt']);

    if (start == null) return false;

    final repeatDaily = data['repeatDaily'] == true;
    final repeatWeekdays = (data['repeatWeekdays'] as List<dynamic>? ?? [])
        .map((value) => int.tryParse(value.toString()))
        .whereType<int>()
        .toSet();
    final repeatUntil = _readDate(data['repeatUntilAt']) ??
        _readDate(data['repeatUntilDate']) ??
        start;

    final targetDay = _dateOnly(day);
    final startDay = _dateOnly(start);
    final endDay = _dateOnly(repeatUntil);

    if (targetDay.isBefore(startDay) || targetDay.isAfter(endDay)) {
      return false;
    }

    if (repeatDaily) return true;
    if (repeatWeekdays.isNotEmpty) {
      return repeatWeekdays.contains(targetDay.weekday % 7);
    }

    return targetDay == startDay;
  }
}

class _TodayRewardState {
  const _TodayRewardState({
    required this.patientId,
    required this.rtdbPatientId,
    required this.dateKey,
    required this.scheduledCount,
    required this.takenCount,
    required this.rewardAmount,
    required this.totalRewardAmount,
  });

  factory _TodayRewardState.empty(String patientId) {
    return _TodayRewardState(
      patientId: patientId,
      rtdbPatientId: patientId,
      dateKey: _formatDate(DateTime.now()),
      scheduledCount: 0,
      takenCount: 0,
      rewardAmount: 0,
      totalRewardAmount: 0,
    );
  }

  final String patientId;
  final String rtdbPatientId;
  final String dateKey;
  final int scheduledCount;
  final int takenCount;
  final int rewardAmount;
  final int totalRewardAmount;
}

class _RewardMessage extends StatelessWidget {
  const _RewardMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: chickOrange, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: chickBrown,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
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

String? _firstString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime? _readDate(Object? value) {
  if (value == null) return null;

  if (value is Timestamp) return _dateOnly(value.toDate());
  if (value is DateTime) return _dateOnly(value);
  if (value is int) {
    final milliseconds = value > 9999999999 ? value : value * 1000;
    return _dateOnly(DateTime.fromMillisecondsSinceEpoch(milliseconds));
  }
  if (value is double) return _readDate(value.toInt());

  final text = value.toString();
  final match = RegExp(r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(text);
  if (match == null) return null;

  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

String _formatDate(DateTime date) {
  final normalized = _dateOnly(date);
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}
