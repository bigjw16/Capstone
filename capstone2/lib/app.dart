import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'core/root_gate.dart';
import 'screens/startup_error_screen.dart';

class PatientMedSyncApp extends StatelessWidget {
  const PatientMedSyncApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patient Med Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: chickOrange,
        useMaterial3: true,
        scaffoldBackgroundColor: chickYellow,
      ),
      home: startupError == null
          ? const RootGate()
          : StartupErrorScreen(errorText: startupError!),
    );
  }
}