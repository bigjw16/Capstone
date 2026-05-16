import 'package:flutter/material.dart';

import '../core/constants.dart';

class TimePickerSpinner extends StatefulWidget {
  const TimePickerSpinner({
    super.key,
    required this.duration,
    required this.onChanged,
  });

  final Duration duration;
  final ValueChanged<Duration> onChanged;

  @override
  State<TimePickerSpinner> createState() => _TimePickerSpinnerState();
}

class _TimePickerSpinnerState extends State<TimePickerSpinner> {
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    _hourCtrl = FixedExtentScrollController(
      initialItem: widget.duration.inHours % 24,
    );
    _minuteCtrl = FixedExtentScrollController(
      initialItem: widget.duration.inMinutes % 60,
    );
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int selectedHour = widget.duration.inHours % 24;
    int selectedMinute = widget.duration.inMinutes % 60;

    void notify() {
      widget.onChanged(Duration(hours: selectedHour, minutes: selectedMinute));
    }

    return Row(
      children: [
        Expanded(
          child: ListWheelScrollView.useDelegate(
            controller: _hourCtrl,
            itemExtent: 36,
            perspective: 0.003,
            onSelectedItemChanged: (v) {
              selectedHour = v;
              notify();
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: 24,
              builder: (_, i) => Center(
                child: Text(
                  '${i.toString().padLeft(2, '0')}시',
                  style: const TextStyle(
                    color: chickBrown,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListWheelScrollView.useDelegate(
            controller: _minuteCtrl,
            itemExtent: 36,
            perspective: 0.003,
            onSelectedItemChanged: (v) {
              selectedMinute = v;
              notify();
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: 60,
              builder: (_, i) => Center(
                child: Text(
                  '${i.toString().padLeft(2, '0')}분',
                  style: const TextStyle(
                    color: chickBrown,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}