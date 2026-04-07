import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:video_player/video_player.dart';
import 'package:vibration/vibration.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationService = NotificationService();
  await notificationService.initialize(
    onAlarmPayload: (payload) {
      final data = NotificationService.parsePayload(payload);
      final medicineName = data['medicineName'] as String?;
      if (medicineName == null) return;

      notificationService.takePendingAlarmPayload();
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AlarmRingPage(
            medicineName: medicineName,
            reminderId: data['reminderId'] as int?,
            notificationService: notificationService,
          ),
        ),
      );
    },
  );

  runApp(MyApp(notificationService: notificationService));

}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: '복약 알림',
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: HomePage(notificationService: notificationService),
      routes: {
        '/reminders': (_) => ReminderPage(notificationService: notificationService),
        '/history': (_) => HistoryPage(notificationService: notificationService),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late final VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openAlarmIfPending());
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
    _videoController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _openAlarmIfPending();
    }
  }

  Future<void> _openAlarmIfPending() async {
    await widget.notificationService.refreshPendingAlarmPayload();
    final payload = widget.notificationService.takePendingAlarmPayload();
    if (payload == null || !mounted) return;

    final data = NotificationService.parsePayload(payload);
    final medicineName = data['medicineName'] as String?;
    if (medicineName == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlarmRingPage(
          medicineName: medicineName,
          reminderId: data['reminderId'] as int?,
          notificationService: widget.notificationService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('복약 도우미')),
      body: Column(
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
    );
  }
}

class HomeActionWidget extends StatelessWidget {
  const HomeActionWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, textAlign: TextAlign.center),
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class ReminderItem {
  ReminderItem({required this.id, required this.medicineName, required this.time});

  final int id;
  final String medicineName;
  final TimeOfDay time;
}

class DoseHistory {
  DoseHistory({required this.medicineName, required this.completedAt});

  final String medicineName;
  final DateTime completedAt;
}

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final TextEditingController _nameController = TextEditingController();
  final List<ReminderItem> _reminders = <ReminderItem>[];
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _reminders.addAll(widget.notificationService.reminders);
  }

  Future<void> _pickTime() async {
    final initial = _selectedTime ?? TimeOfDay.now();
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ScrollTimePickerSheet(initialTime: initial),
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _addReminder() async {
    final medicineName = _nameController.text.trim();
    if (medicineName.isEmpty || _selectedTime == null) {
      _snack('약 이름과 시간을 모두 입력해주세요.');
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    final item = ReminderItem(id: id, medicineName: medicineName, time: _selectedTime!);

    await widget.notificationService.scheduleDailyReminder(item);

    setState(() {
      _reminders
        ..clear()
        ..addAll(widget.notificationService.reminders);
      _nameController.clear();
      _selectedTime = null;
    });
    _snack('알림이 등록되었습니다.');
  }

  Future<void> _deleteReminder(ReminderItem item) async {
    await widget.notificationService.cancelReminder(item.id);
    setState(() {
      _reminders
        ..clear()
        ..addAll(widget.notificationService.reminders);
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = _selectedTime == null ? '시간 선택' : _selectedTime!.format(context);

    return Scaffold(
      appBar: AppBar(title: const Text('알림 등록')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: '약 이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule),
                    label: Text(timeLabel),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addReminder,
                  icon: const Icon(Icons.add_alert),
                  label: const Text('등록'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _reminders.isEmpty
                  ? const Center(child: Text('등록된 복약 알림이 없습니다.'))
                  : ListView.builder(
                      itemCount: _reminders.length,
                      itemBuilder: (_, index) {
                        final item = _reminders[index];
                        return Card(
                          child: ListTile(
                            title: Text(item.medicineName),
                            subtitle: Text('매일 ${item.time.format(context)}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteReminder(item),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ScrollTimePickerSheet extends StatefulWidget {
  const _ScrollTimePickerSheet({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_ScrollTimePickerSheet> createState() => _ScrollTimePickerSheetState();
}

class _ScrollTimePickerSheetState extends State<_ScrollTimePickerSheet> {
  late int _hour;
  late int _minute;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late TextEditingController _hourTextController;
  late TextEditingController _minuteTextController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
    _hourTextController = TextEditingController(text: _hour.toString().padLeft(2, '0'));
    _minuteTextController = TextEditingController(text: _minute.toString().padLeft(2, '0'));
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _hourTextController.dispose();
    _minuteTextController.dispose();
    super.dispose();
  }

  void _syncText() {
    _hourTextController.text = _hour.toString().padLeft(2, '0');
    _minuteTextController.text = _minute.toString().padLeft(2, '0');
  }

  void _applyKeyboardHour(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0 || parsed > 23) return;
    setState(() {
      _hour = parsed;
      _hourController.jumpToItem(_hour);
      _syncText();
    });
  }

  void _applyKeyboardMinute(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0 || parsed > 59) return;
    setState(() {
      _minute = parsed;
      _minuteController.jumpToItem(_minute);
      _syncText();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('시간 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hourTextController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: '시 (0-23)'),
                  onSubmitted: _applyKeyboardHour,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _minuteTextController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: '분 (0-59)'),
                  onSubmitted: _applyKeyboardMinute,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: _hourController,
                    itemExtent: 40,
                    onSelectedItemChanged: (value) {
                      setState(() {
                        _hour = value;
                        _syncText();
                      });
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 24,
                      builder: (_, index) => Center(child: Text(index.toString().padLeft(2, '0'))),
                    ),
                  ),
                ),
                const Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: _minuteController,
                    itemExtent: 40,
                    onSelectedItemChanged: (value) {
                      setState(() {
                        _minute = value;
                        _syncText();
                      });
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 60,
                      builder: (_, index) => Center(child: Text(index.toString().padLeft(2, '0'))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop(TimeOfDay(hour: _hour, minute: _minute));
              },
              child: const Text('확인'),
            ),
          ),
        ],
      ),
    );
  }
}

class AlarmRingPage extends StatefulWidget {
  const AlarmRingPage({
    super.key,
    required this.medicineName,
    required this.notificationService,
    this.reminderId,
  });

  final String medicineName;
  final int? reminderId;
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.alarm, size: 72, color: Colors.red),
              const SizedBox(height: 16),
              const Text('복약 알림', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                widget.medicineName,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
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
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    final records = notificationService.histories.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('복약 기록')),
      body: records.isEmpty
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
    );
  }
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final List<ReminderItem> _savedReminders = <ReminderItem>[];
  final List<DoseHistory> _histories = <DoseHistory>[];
  String? _pendingAlarmPayload;
  String? _lastHandledPayload;

  List<ReminderItem> get reminders => List<ReminderItem>.unmodifiable(_savedReminders);
  List<DoseHistory> get histories => List<DoseHistory>.unmodifiable(_histories);

  static Map<String, dynamic> parsePayload(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  Future<void> initialize({required void Function(String payload) onAlarmPayload}) async {
    await _configureLocalTimeZone();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          _pendingAlarmPayload = payload;
          onAlarmPayload(payload);
        }
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _pendingAlarmPayload = launchDetails?.notificationResponse?.payload;
    }

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    await androidPlugin?.requestFullScreenIntentPermission();
  }

  Future<void> refreshPendingAlarmPayload() async {
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload != _lastHandledPayload) {
        _pendingAlarmPayload = payload;
      }
    }
  }

  String? takePendingAlarmPayload() {
    final payload = _pendingAlarmPayload;
    _pendingAlarmPayload = null;
    _lastHandledPayload = payload;
    return payload;
  }

  Future<void> scheduleDailyReminder(ReminderItem item) async {
    _savedReminders.removeWhere((e) => e.id == item.id);
    _savedReminders.add(item);

    final scheduledDate = _nextInstanceOfTime(item.time);
    await _plugin.zonedSchedule(
      item.id,
      '복약 시간입니다',
      '${item.medicineName} 복용할 시간이에요.',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_channel',
          '복약 알림',
          channelDescription: '정해진 시간에 복약 알림을 제공합니다.',
          importance: Importance.max,
          priority: Priority.max,
          playSound: false,
          enableVibration: false,
          silent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'alarm',
        'medicineName': item.medicineName,
        'reminderId': item.id,
      }),
    );
  }

  Future<void> scheduleSnoozeAfter3Minutes({
    required String medicineName,
    int? reminderId,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);

    await _plugin.zonedSchedule(
      id,
      '복약 재알림',
      '$medicineName 복용 알림입니다. 다시 확인해주세요.',
      tz.TZDateTime.now(tz.local).add(const Duration(minutes: 3)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_channel',
          '복약 알림',
          channelDescription: '정해진 시간에 복약 알림을 제공합니다.',
          importance: Importance.max,
          priority: Priority.max,
          playSound: false,
          enableVibration: false,
          silent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'alarm',
        'medicineName': medicineName,
        'reminderId': reminderId,
      }),
    );
  }

  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
    _savedReminders.removeWhere((e) => e.id == id);
  }

  void recordDose(String medicineName) {
    _histories.add(DoseHistory(medicineName: medicineName, completedAt: DateTime.now()));
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final timezoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay timeOfDay) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    return scheduled;
  }
}
