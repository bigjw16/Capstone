import 'package:flutter/material.dart';

class ScrollTimePickerSheet extends StatefulWidget {
  const ScrollTimePickerSheet({super.key, required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<ScrollTimePickerSheet> createState() => _ScrollTimePickerSheetState();
}

class _ScrollTimePickerSheetState extends State<ScrollTimePickerSheet> {
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

  void _applyHour(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0 || parsed > 23) return;
    setState(() {
      _hour = parsed;
      _hourController.jumpToItem(_hour);
      _syncText();
    });
  }

  void _applyMinute(String value) {
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
                    onSubmitted: _applyHour,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _minuteTextController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: '분 (0-59)'),
                    onSubmitted: _applyMinute,
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
                      onSelectedItemChanged: (value) => setState(() {
                        _hour = value;
                        _syncText();
                      }),
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 24,
                        builder: (_, i) => Center(child: Text(i.toString().padLeft(2, '0'))),
                      ),
                    ),
                  ),
                  const Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: ListWheelScrollView.useDelegate(
                      controller: _minuteController,
                      itemExtent: 40,
                      onSelectedItemChanged: (value) => setState(() {
                        _minute = value;
                        _syncText();
                      }),
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 60,
                        builder: (_, i) => Center(child: Text(i.toString().padLeft(2, '0'))),
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
