import 'package:flutter/material.dart';

import '../models/reminder_item.dart';
import '../services/notification_service.dart';
import '../widgets/scroll_time_picker_sheet.dart';

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
    final picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: ScrollTimePickerSheet(initialTime: _selectedTime ?? TimeOfDay.now()),
      ),
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

    final item = ReminderItem(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      medicineName: medicineName,
      time: _selectedTime!,
    );

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

  Future<void> _editReminder(ReminderItem item) async {
    final nameController = TextEditingController(text: item.medicineName);
    var editedTime = item.time;

    final updated = await showDialog<ReminderItem>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('알림 수정'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '약 이름'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDialog<TimeOfDay>(
                        context: context,
                        builder: (_) => Dialog(
                          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ScrollTimePickerSheet(initialTime: editedTime),
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
                    if (name.isEmpty) return;
                    Navigator.of(context).pop(
                      ReminderItem(id: item.id, medicineName: name, time: editedTime),
                    );
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    if (updated == null) return;

    await widget.notificationService.scheduleDailyReminder(updated);
    setState(() {
      _reminders
        ..clear()
        ..addAll(widget.notificationService.reminders);
    });
    _snack('알림이 수정되었습니다.');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = _selectedTime == null ? '시간 선택' : _selectedTime!.format(context);

    return Scaffold(
      appBar: AppBar(title: const Text('알림 등록')),
      body: SafeArea(
        child: Padding(
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
                              onTap: () => _editReminder(item),
                              title: Text(item.medicineName),
                              subtitle: Text('매일 ${item.time.format(context)} (탭해서 수정)'),
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
