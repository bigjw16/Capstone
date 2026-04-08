import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  final notificationService = NotificationService();
  await notificationService.initialize(onAlarmPayload: (_) {});

  runApp(MyApp(notificationService: notificationService));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: '복약 성장 도우미',
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
        '/settings': (_) => SettingsPage(notificationService: notificationService),
      },
    );
  }
}

class ReminderItem {
  ReminderItem({
    required this.id,
    required this.medicineName,
    required this.time,
    required this.dose,
  });

  final int id;
  final String medicineName;
  final TimeOfDay time;
  final String dose;
}

enum DoseStatus { taken, missed }

class DoseHistory {
  DoseHistory({
    required this.reminderId,
    required this.medicineName,
    required this.status,
    required this.recordedAt,
    required this.attempt,
  });

  final int reminderId;
  final String medicineName;
  final DoseStatus status;
  final DateTime recordedAt;
  final int attempt;
}

class CharacterState {
  CharacterState({required this.level, required this.xp, required this.streak});

  final int level;
  final int xp;
  final int streak;

  int get levelXpMin => (level - 1) * 100;
  int get levelXpMax => level * 100;
  double get levelProgress => ((xp - levelXpMin) / 100).clamp(0, 1);

  String get moodLabel {
    if (streak >= 7) return '최고 컨디션';
    if (streak >= 3) return '활발함';
    if (streak >= 1) return '안정적';
    return '응원이 필요해요';
  }

  String get avatar {
    if (level >= 10) return '🐲';
    if (level >= 5) return '🦊';
    return '🐣';
  }
}

class UserSettings {
  UserSettings({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.ringtone = 'default_alarm',
  });

  bool soundEnabled;
  bool vibrationEnabled;
  String ringtone;
}

class ContactInfo {
  ContactInfo({this.name = '', this.phone = '', this.address = ''});

  String name;
  String phone;
  String address;
}

class AccountInfo {
  AccountInfo({this.email = '', this.loggedIn = false});

  String email;
  bool loggedIn;
}

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final List<ReminderItem> _savedReminders = <ReminderItem>[];
  final List<DoseHistory> _histories = <DoseHistory>[];
  final Set<String> _completedCycleKeys = <String>{};

  final UserSettings userSettings = UserSettings();
  final AccountInfo accountInfo = AccountInfo();
  final ContactInfo hospitalInfo = ContactInfo();
  final ContactInfo pharmacyInfo = ContactInfo();

  int _xp = 0;
  int _streak = 0;
  String? _pendingAlarmPayload;
  String? _lastHandledPayload;

  List<ReminderItem> get reminders => List<ReminderItem>.unmodifiable(_savedReminders);
  List<DoseHistory> get histories => List<DoseHistory>.unmodifiable(_histories);

  CharacterState get character {
    final level = (_xp ~/ 100) + 1;
    return CharacterState(level: level, xp: _xp, streak: _streak);
  }

  double get complianceRate {
    if (_histories.isEmpty) return 0;
    final taken = _histories.where((e) => e.status == DoseStatus.taken).length;
    return taken / _histories.length;
  }

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

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

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

  Future<void> clearActiveNotification(int? id) async {
    if (id == null) return;
    await _plugin.cancel(id);
  }

  Future<void> handleForegroundTrigger(ReminderItem item) async {
    await _plugin.cancel(item.id);
    await scheduleDailyReminder(item);
  }

  Future<void> scheduleDailyReminder(ReminderItem item) async {
    _savedReminders.removeWhere((e) => e.id == item.id);
    _savedReminders.add(item);

    final scheduledDate = _nextInstanceOfTime(item.time);
    await _plugin.zonedSchedule(
      item.id,
      '복약 시간입니다',
      '${item.medicineName} (${item.dose}) 복용할 시간이에요.',
      scheduledDate,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'alarm',
        'medicineName': item.medicineName,
        'dose': item.dose,
        'reminderId': item.id,
        'notificationId': item.id,
        'attempt': 0,
      }),
    );
  }

  Future<void> scheduleSnoozeAfter3Minutes({
    required ReminderItem reminder,
    required int attempt,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);

    await _plugin.zonedSchedule(
      id,
      '복약 재알림',
      '${reminder.medicineName} (${reminder.dose}) 복용 알림입니다.',
      tz.TZDateTime.now(tz.local).add(const Duration(minutes: 3)),
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'type': 'alarm',
        'medicineName': reminder.medicineName,
        'dose': reminder.dose,
        'reminderId': reminder.id,
        'notificationId': id,
        'attempt': attempt,
      }),
    );
  }

  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
    _savedReminders.removeWhere((e) => e.id == id);
  }

  ReminderItem? findReminder(int id) {
    for (final reminder in _savedReminders) {
      if (reminder.id == id) return reminder;
    }
    return null;
  }

  String _cycleKey(int reminderId, DateTime dt) =>
      '$reminderId-${dt.year}-${dt.month}-${dt.day}-${dt.hour}-${dt.minute}';

  bool isCycleHandled(int reminderId, DateTime dt) {
    return _completedCycleKeys.contains(_cycleKey(reminderId, dt));
  }

  void markCycleHandled(int reminderId, DateTime dt) {
    _completedCycleKeys.add(_cycleKey(reminderId, dt));
  }

  void recordDoseTaken({required ReminderItem reminder, required int attempt}) {
    final now = DateTime.now();
    if (isCycleHandled(reminder.id, now)) return;

    markCycleHandled(reminder.id, now);
    _histories.add(
      DoseHistory(
        reminderId: reminder.id,
        medicineName: reminder.medicineName,
        status: DoseStatus.taken,
        recordedAt: now,
        attempt: attempt,
      ),
    );

    _xp += 10;
    _streak += 1;
  }

  void recordDoseMissed({required ReminderItem reminder, required int attempt}) {
    final now = DateTime.now();
    if (isCycleHandled(reminder.id, now)) return;

    markCycleHandled(reminder.id, now);
    _histories.add(
      DoseHistory(
        reminderId: reminder.id,
        medicineName: reminder.medicineName,
        status: DoseStatus.missed,
        recordedAt: now,
        attempt: attempt,
      ),
    );
    _streak = 0;
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

  NotificationDetails get _notificationDetails {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'medication_channel',
        '복약 알림',
        channelDescription: '정해진 시간에 복약 알림을 제공합니다.',
        importance: Importance.max,
        priority: Priority.max,
        playSound: userSettings.soundEnabled,
        enableVibration: userSettings.vibrationEnabled,
        silent: !(userSettings.soundEnabled || userSettings.vibrationEnabled),
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        sound: userSettings.soundEnabled ? RawResourceAndroidNotificationSound(userSettings.ringtone) : null,
      ),
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
  final PageController _pageController = PageController();
  Timer? _foregroundAlarmTimer;
  bool _isAlarmPageOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openAlarmIfPending());
    _startForegroundAlarmWatcher();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundAlarmTimer?.cancel();
    _pageController.dispose();
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
    if (payload == null || !mounted || _isAlarmPageOpen) return;

    final data = NotificationService.parsePayload(payload);
    final reminderId = data['reminderId'] as int?;
    final notificationId = data['notificationId'] as int?;
    final attempt = (data['attempt'] as int?) ?? 0;
    if (reminderId == null) return;

    final reminder = widget.notificationService.findReminder(reminderId);
    if (reminder == null) return;

    _isAlarmPageOpen = true;
    await widget.notificationService.clearActiveNotification(notificationId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlarmRingPage(
          reminder: reminder,
          attempt: attempt,
          notificationId: notificationId,
          notificationService: widget.notificationService,
        ),
      ),
    );
    _isAlarmPageOpen = false;
    if (mounted) setState(() {});
  }

  void _startForegroundAlarmWatcher() {
    _foregroundAlarmTimer?.cancel();
    _foregroundAlarmTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkForegroundAlarmDue();
    });
  }

  Future<void> _checkForegroundAlarmDue() async {
    if (!mounted || _isAlarmPageOpen) return;

    final now = DateTime.now();

    for (final reminder in widget.notificationService.reminders) {
      final isDueNow = now.hour == reminder.time.hour && now.minute == reminder.time.minute;
      if (!isDueNow) continue;
      if (widget.notificationService.isCycleHandled(reminder.id, now)) continue;

      _isAlarmPageOpen = true;
      await widget.notificationService.handleForegroundTrigger(reminder);

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AlarmRingPage(
            reminder: reminder,
            attempt: 0,
            notificationService: widget.notificationService,
          ),
        ),
      );
      _isAlarmPageOpen = false;
      if (mounted) setState(() {});
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('복약 성장 도우미'),
        actions: [_settingsAction(context)],
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          children: [
            _HomeCharacterView(notificationService: widget.notificationService),
            MedicationInfoPage(notificationService: widget.notificationService),
          ],
        ),
      ),
    );
  }
}

class _HomeCharacterView extends StatelessWidget {
  const _HomeCharacterView({required this.notificationService});

  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    final character = notificationService.character;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘의 캐릭터 상태: ${character.moodLabel}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(character.avatar, style: const TextStyle(fontSize: 60)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lv. ${character.level}',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: character.levelProgress),
                        const SizedBox(height: 8),
                        Text('XP ${character.xp}/${character.levelXpMax}'),
                        Text('연속 복약 스트릭: ${character.streak}일'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: '복약 준수율',
                  value: '${(notificationService.complianceRate * 100).toStringAsFixed(1)}%',
                  icon: Icons.verified,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: '총 기록',
                  value: '${notificationService.histories.length}건',
                  icon: Icons.event_note,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('👉 홈에서 오른쪽으로 스와이프하면 복약 정보 화면으로 이동합니다.'),
        ],
      ),
    );
  }
}

class MedicationInfoPage extends StatelessWidget {
  const MedicationInfoPage({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    final reminders = notificationService.reminders;
    final histories = notificationService.histories.reversed.take(7).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('복약 정보', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('복약 알림 목록', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (reminders.isEmpty)
                          const Text('등록된 알림이 없습니다.')
                        else
                          ...reminders.map(
                            (r) => ListTile(
                              dense: true,
                              title: Text(r.medicineName),
                              subtitle: Text('시간 ${r.time.format(context)} · 용량 ${r.dose}'),
                            ),
                          ),
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
                        const Text('복약 기록 위젯', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (histories.isEmpty)
                          const Text('아직 기록이 없습니다.')
                        else
                          ...histories.map(
                            (h) => ListTile(
                              dense: true,
                              leading: Icon(
                                h.status == DoseStatus.taken
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: h.status == DoseStatus.taken ? Colors.green : Colors.red,
                              ),
                              title: Text(h.medicineName),
                              subtitle: Text(
                                '${h.recordedAt} · ${h.status == DoseStatus.taken ? '복약 완료' : '미복약'}',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('복약 준수율 통계'),
                        Text('${(notificationService.complianceRate * 100).toStringAsFixed(1)}%'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReminderPage(notificationService: notificationService),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_alert),
                  label: const Text('복약 알림 등록/수정'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HistoryPage(notificationService: notificationService),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('전체 복약 기록 보기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReminderPage extends StatefulWidget {
  const ReminderPage({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _doseController = TextEditingController(text: '1정');
  TimeOfDay? _selectedTime;

  Future<void> _pickTime() async {
    final initial = _selectedTime ?? TimeOfDay.now();
    final picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: _ScrollTimePickerSheet(initialTime: initial),
      ),
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _addReminder() async {
    final medicineName = _nameController.text.trim();
    final dose = _doseController.text.trim();
    if (medicineName.isEmpty || dose.isEmpty || _selectedTime == null) {
      _snack('약 이름, 용량, 시간을 모두 입력해주세요.');
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    final item = ReminderItem(id: id, medicineName: medicineName, time: _selectedTime!, dose: dose);

    await widget.notificationService.scheduleDailyReminder(item);

    setState(() {
      _nameController.clear();
      _doseController.text = '1정';
      _selectedTime = null;
    });
    _snack('알림이 등록되었습니다.');
  }

  Future<void> _deleteReminder(ReminderItem item) async {
    await widget.notificationService.cancelReminder(item.id);
    setState(() {});
  }

  Future<void> _editReminder(ReminderItem item) async {
    final nameController = TextEditingController(text: item.medicineName);
    final doseController = TextEditingController(text: item.dose);
    var editedTime = item.time;

    final updated = await showDialog<ReminderItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('알림 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '약 이름'),
              ),
              TextField(
                controller: doseController,
                decoration: const InputDecoration(labelText: '용량'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDialog<TimeOfDay>(
                    context: context,
                    builder: (_) => Dialog(
                      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ScrollTimePickerSheet(initialTime: editedTime),
                    ),
                  );
                  if (picked != null) setModalState(() => editedTime = picked);
                },
                icon: const Icon(Icons.schedule),
                label: Text('시간: ${editedTime.format(context)}'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final dose = doseController.text.trim();
                if (name.isEmpty || dose.isEmpty) return;
                Navigator.of(context).pop(
                  ReminderItem(id: item.id, medicineName: name, time: editedTime, dose: dose),
                );
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    doseController.dispose();
    if (updated == null) return;

    await widget.notificationService.scheduleDailyReminder(updated);
    setState(() {});
    _snack('알림이 수정되었습니다.');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final reminders = widget.notificationService.reminders;
    final timeLabel = _selectedTime == null ? '시간 선택' : _selectedTime!.format(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('복약 알림 등록'),
        actions: [_settingsAction(context)],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '약 이름',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _doseController,
                decoration: const InputDecoration(
                  labelText: '용량 (예: 1정, 5ml)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 12),
              Expanded(
                child: reminders.isEmpty
                    ? const Center(child: Text('등록된 복약 알림이 없습니다.'))
                    : ListView.builder(
                        itemCount: reminders.length,
                        itemBuilder: (_, index) {
                          final item = reminders[index];
                          return Card(
                            child: ListTile(
                              onTap: () => _editReminder(item),
                              title: Text(item.medicineName),
                              subtitle: Text('매일 ${item.time.format(context)} · ${item.dose}'),
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
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        builder: (_, index) => Center(
                          child: Text(index.toString().padLeft(2, '0')),
                        ),
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
                        builder: (_, index) => Center(
                          child: Text(index.toString().padLeft(2, '0')),
                        ),
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
      ),
    );
  }
}

class AlarmRingPage extends StatefulWidget {
  const AlarmRingPage({
    super.key,
    required this.reminder,
    required this.attempt,
    required this.notificationService,
    this.notificationId,
  });

  final ReminderItem reminder;
  final int attempt;
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
    if (widget.notificationService.userSettings.soundEnabled) {
      FlutterRingtonePlayer().playAlarm(looping: true, asAlarm: true, volume: 1.0);
    }

    if (widget.notificationService.userSettings.vibrationEnabled &&
        (await Vibration.hasVibrator() ?? false)) {
      _vibrationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        Vibration.vibrate(duration: 800);
      });
    }

    _timeoutTimer = Timer(const Duration(minutes: 1), () async {
      if (_stopped) return;
      await _stopOnly();

      if (widget.attempt < 2) {
        await widget.notificationService.scheduleSnoozeAfter3Minutes(
          reminder: widget.reminder,
          attempt: widget.attempt + 1,
        );
      } else {
        widget.notificationService.recordDoseMissed(
          reminder: widget.reminder,
          attempt: widget.attempt,
        );
      }

      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _stopOnly() async {
    _stopped = true;
    _timeoutTimer?.cancel();
    _vibrationTimer?.cancel();
    FlutterRingtonePlayer().stop();
  }

  Future<void> _completeDose() async {
    await _stopOnly();
    widget.notificationService.recordDoseTaken(
      reminder: widget.reminder,
      attempt: widget.attempt,
    );
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
                const Text(
                  '복약 알람',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(widget.reminder.medicineName,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                Text('용량: ${widget.reminder.dose}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Text('재알람 단계: ${widget.attempt + 1}/3'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _completeDose,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('복약 완료 (알람 종료)'),
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

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    final records = notificationService.histories.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('복약 기록'),
        actions: [_settingsAction(context)],
      ),
      body: SafeArea(
        child: records.isEmpty
            ? const Center(child: Text('아직 기록이 없습니다.'))
            : ListView.builder(
                itemCount: records.length,
                itemBuilder: (_, index) {
                  final record = records[index];
                  final isTaken = record.status == DoseStatus.taken;
                  return ListTile(
                    leading: Icon(isTaken ? Icons.check_circle : Icons.cancel,
                        color: isTaken ? Colors.green : Colors.red),
                    title: Text(record.medicineName),
                    subtitle: Text('${record.recordedAt} · ${isTaken ? '복약 완료' : '미복약'}'),
                    trailing: Text('시도 ${record.attempt + 1}'),
                  );
                },
              ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _emailController;
  late final TextEditingController _hospitalName;
  late final TextEditingController _hospitalPhone;
  late final TextEditingController _hospitalAddress;
  late final TextEditingController _pharmacyName;
  late final TextEditingController _pharmacyPhone;
  late final TextEditingController _pharmacyAddress;

  @override
  void initState() {
    super.initState();
    final service = widget.notificationService;
    _emailController = TextEditingController(text: service.accountInfo.email);
    _hospitalName = TextEditingController(text: service.hospitalInfo.name);
    _hospitalPhone = TextEditingController(text: service.hospitalInfo.phone);
    _hospitalAddress = TextEditingController(text: service.hospitalInfo.address);
    _pharmacyName = TextEditingController(text: service.pharmacyInfo.name);
    _pharmacyPhone = TextEditingController(text: service.pharmacyInfo.phone);
    _pharmacyAddress = TextEditingController(text: service.pharmacyInfo.address);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _hospitalName.dispose();
    _hospitalPhone.dispose();
    _hospitalAddress.dispose();
    _pharmacyName.dispose();
    _pharmacyPhone.dispose();
    _pharmacyAddress.dispose();
    super.dispose();
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _save() {
    final service = widget.notificationService;
    service.accountInfo
      ..email = _emailController.text.trim()
      ..loggedIn = _emailController.text.trim().isNotEmpty;

    service.hospitalInfo
      ..name = _hospitalName.text.trim()
      ..phone = _hospitalPhone.text.trim()
      ..address = _hospitalAddress.text.trim();

    service.pharmacyInfo
      ..name = _pharmacyName.text.trim()
      ..phone = _pharmacyPhone.text.trim()
      ..address = _pharmacyAddress.text.trim();

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('설정 저장 완료')));
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.notificationService.userSettings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        actions: [_settingsAction(context)],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('로그인', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '이메일',
                hintText: 'example@email.com',
              ),
            ),
            const SizedBox(height: 16),
            const Text('알림 설정', style: TextStyle(fontWeight: FontWeight.bold)),
            SwitchListTile(
              value: settings.soundEnabled,
              onChanged: (v) => setState(() => settings.soundEnabled = v),
              title: const Text('소리 알림'),
            ),
            SwitchListTile(
              value: settings.vibrationEnabled,
              onChanged: (v) => setState(() => settings.vibrationEnabled = v),
              title: const Text('진동 알림'),
            ),
            DropdownButtonFormField<String>(
              value: settings.ringtone,
              items: const [
                DropdownMenuItem(value: 'default_alarm', child: Text('기본 알람음')),
                DropdownMenuItem(value: 'ringtone', child: Text('시스템 벨소리')),
                DropdownMenuItem(value: 'notification', child: Text('시스템 알림음')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => settings.ringtone = v);
              },
              decoration: const InputDecoration(labelText: '알림음 종류'),
            ),
            const SizedBox(height: 16),
            const Text('병원 정보', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _hospitalName, decoration: const InputDecoration(labelText: '병원 이름')),
            TextField(controller: _hospitalPhone, decoration: const InputDecoration(labelText: '병원 전화번호')),
            TextField(controller: _hospitalAddress, decoration: const InputDecoration(labelText: '병원 주소')),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _hospitalPhone.text.trim().isEmpty
                    ? null
                    : () => _callPhone(_hospitalPhone.text.trim()),
                icon: const Icon(Icons.call),
                label: const Text('병원 전화 연결'),
              ),
            ),
            const SizedBox(height: 16),
            const Text('약국 정보', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _pharmacyName, decoration: const InputDecoration(labelText: '약국 이름')),
            TextField(controller: _pharmacyPhone, decoration: const InputDecoration(labelText: '약국 전화번호')),
            TextField(controller: _pharmacyAddress, decoration: const InputDecoration(labelText: '약국 주소')),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _pharmacyPhone.text.trim().isEmpty
                    ? null
                    : () => _callPhone(_pharmacyPhone.text.trim()),
                icon: const Icon(Icons.call),
                label: const Text('약국 전화 연결'),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('설정 저장')),
          ],
        ),
      ),
    );
  }
}

Widget _settingsAction(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.settings),
    onPressed: () => Navigator.of(context).pushNamed('/settings'),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(title),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
