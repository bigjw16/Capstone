import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../widgets/chick_card.dart';
import '../widgets/chick_scaffold.dart';

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