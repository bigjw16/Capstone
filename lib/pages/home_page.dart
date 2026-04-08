import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/notification_service.dart';
import '../widgets/home_action_widget.dart';
import 'alarm_ring_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final VideoPlayerController _videoController;
  Timer? _foregroundAlarmTimer;
  final Set<String> _triggeredAlarmKeys = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openAlarmIfPending());
    _startForegroundAlarmWatcher();

    _videoController = VideoPlayerController.networkUrl(
      Uri.parse('https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
    )..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _videoController
          ..setLooping(true)
          ..setVolume(0)
          ..play();
      });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundAlarmTimer?.cancel();
    _videoController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _openAlarmIfPending();
      _startForegroundAlarmWatcher();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _foregroundAlarmTimer?.cancel();
    }
  }

  Future<void> _openAlarmIfPending() async {
    await widget.notificationService.refreshPendingAlarmPayload();
    final payload = widget.notificationService.takePendingAlarmPayload();
    if (payload == null || !mounted) return;

    final data = NotificationService.parsePayload(payload);
    final medicineName = data['medicineName'] as String?;
    final notificationId = data['notificationId'] as int?;
    if (medicineName == null) return;

    await widget.notificationService.clearActiveNotification(notificationId);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlarmRingPage(
          medicineName: medicineName,
          reminderId: data['reminderId'] as int?,
          notificationId: notificationId,
          notificationService: widget.notificationService,
        ),
      ),
    );
  }

  void _startForegroundAlarmWatcher() {
    _foregroundAlarmTimer?.cancel();
    _foregroundAlarmTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkForegroundAlarmDue();
    });
  }

  Future<void> _checkForegroundAlarmDue() async {
    if (!mounted) return;

    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month}-${now.day}';

    for (final reminder in widget.notificationService.reminders) {
      final key = '${reminder.id}-$dateKey';
      final isDueNow = now.hour == reminder.time.hour && now.minute == reminder.time.minute;

      if (!isDueNow || _triggeredAlarmKeys.contains(key)) continue;

      _triggeredAlarmKeys.add(key);
      await widget.notificationService.handleForegroundTrigger(reminder);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AlarmRingPage(
            medicineName: reminder.medicineName,
            reminderId: reminder.id,
            notificationService: widget.notificationService,
          ),
        ),
      );
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('복약 도우미')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _videoController.value.isInitialized
                    ? VideoPlayer(_videoController)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    HomeActionWidget(
                      icon: Icons.add_alert,
                      title: '알림 등록',
                      subtitle: '복약 알림 추가',
                      onTap: () => Navigator.of(context).pushNamed('/reminders'),
                    ),
                    HomeActionWidget(
                      icon: Icons.history,
                      title: '복약 기록',
                      subtitle: '종료 기록 보기',
                      onTap: () => Navigator.of(context).pushNamed('/history'),
                    ),
                    const HomeActionWidget(
                      icon: Icons.show_chart,
                      title: '복약 통계',
                      subtitle: '준비 중',
                    ),
                    const HomeActionWidget(
                      icon: Icons.settings,
                      title: '설정',
                      subtitle: '준비 중',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
