import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/notification_service.dart';

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
