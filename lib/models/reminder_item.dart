import 'package:flutter/material.dart';

class ReminderItem {
  ReminderItem({required this.id, required this.medicineName, required this.time});

  final int id;
  final String medicineName;
  final TimeOfDay time;
}
