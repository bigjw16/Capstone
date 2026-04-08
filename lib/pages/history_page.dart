import 'package:flutter/material.dart';

import '../services/notification_service.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    final records = notificationService.histories.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('복약 기록')),
      body: SafeArea(
        child: records.isEmpty
            ? const Center(child: Text('아직 종료 기록이 없습니다.'))
            : ListView.builder(
                itemCount: records.length,
                itemBuilder: (_, index) {
                  final record = records[index];
                  return ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(record.medicineName),
                    subtitle: Text('종료 시각: ${record.completedAt}'),
                  );
                },
              ),
      ),
    );
  }
}
