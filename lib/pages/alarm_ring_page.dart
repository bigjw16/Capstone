import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

import '../services/notification_service.dart';

class AlarmRingPage extends StatefulWidget {
  const AlarmRingPage({
    super.key,
    required this.medicineName,
    required this.notificationService,
    this.reminderId,
    this.notificationId,
  });

  final String medicineName;
  final int? reminderId;
  final int? notificationId;
  final NotificationService notificationService;

  @override
  State<AlarmRingPage> createState() => _AlarmRingPageState();
}

class _AlarmRingPageState extends State<AlarmRingPage> {
  Timer? _timeoutTimer;
  Timer? _vibrationTimer;
  bool _stopped = false;

  @override
  void initState() {
    super.initState();
    _startAlerting();
  }

  Future<void> _startAlerting() async {
    await widget.notificationService.clearActiveNotification(widget.notificationId);
    FlutterRingtonePlayer().playAlarm(looping: true, asAlarm: true, volume: 1.0);

    if (await Vibration.hasVibrator() ?? false) {
      _vibrationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        Vibration.vibrate(duration: 800);
      });
    }

    _timeoutTimer = Timer(const Duration(minutes: 1), () async {
      if (_stopped) return;
      await _stopAndClose(recordHistory: false);
      await widget.notificationService.scheduleSnoozeAfter3Minutes(
        medicineName: widget.medicineName,
        reminderId: widget.reminderId,
      );
    });
  }

  Future<void> _stopAndClose({required bool recordHistory}) async {
    _stopped = true;
    _timeoutTimer?.cancel();
    _vibrationTimer?.cancel();
    FlutterRingtonePlayer().stop();

    if (recordHistory) {
      widget.notificationService.recordDose(widget.medicineName);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _vibrationTimer?.cancel();
    FlutterRingtonePlayer().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.alarm, size: 72, color: Colors.red),
                const SizedBox(height: 16),
                const Text('복약 알림', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(widget.medicineName,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _stopAndClose(recordHistory: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('복약 완료 (알림 종료)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
