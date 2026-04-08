import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pages/history_page.dart';
import 'pages/home_page.dart';
import 'pages/reminder_page.dart';
import 'services/notification_service.dart';

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
      home: HomePage(notificationService: notificationService),
      routes: {
        '/reminders': (_) => ReminderPage(notificationService: notificationService),
        '/history': (_) => HistoryPage(notificationService: notificationService),
      },
    );
  }
}
