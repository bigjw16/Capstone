import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(MyApp(notificationService: notificationService));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.notificationService});

  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '복약 알림',
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: ReminderPage(notificationService: notificationService),
    );
  }
}

class ReminderItem {
  ReminderItem({
    required this.id,
    required this.medicineName,
    required this.time,
  });

  final int id;
  final String medicineName;
  final TimeOfDay time;
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
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _addReminder() async {
    final medicineName = _nameController.text.trim();
    if (medicineName.isEmpty || _selectedTime == null) {
      _showSnackBar('약 이름과 시간을 모두 입력해주세요.');
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    final item = ReminderItem(
      id: id,
      medicineName: medicineName,
      time: _selectedTime!,
    );

    await widget.notificationService.scheduleDailyReminder(item);

    setState(() {
      _reminders.add(item);
      _nameController.clear();
      _selectedTime = null;
    });

    _showSnackBar('알림이 등록되었습니다.');
  }

  Future<void> _deleteReminder(ReminderItem item) async {
    await widget.notificationService.cancelReminder(item.id);
    setState(() {
      _reminders.removeWhere((element) => element.id == item.id);
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = _selectedTime == null
        ? '시간 선택'
        : _selectedTime!.format(context);

    return Scaffold(
      appBar: AppBar(title: const Text('복약 알림')),
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
                      itemBuilder: (context, index) {
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

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleDailyReminder(ReminderItem item) async {
    final scheduledDate = _nextInstanceOfTime(item.time);

    const androidDetails = AndroidNotificationDetails(
      'medication_channel',
      '복약 알림',
      channelDescription: '정해진 시간에 복약 알림을 제공합니다.',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.zonedSchedule(
      item.id,
      '복약 시간입니다',
      '${item.medicineName} 복용할 시간이에요.',
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
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

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }
}
