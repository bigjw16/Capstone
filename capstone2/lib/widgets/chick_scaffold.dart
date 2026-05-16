import 'package:flutter/material.dart';

import '../core/constants.dart';

class ChickScaffold extends StatelessWidget {
  const ChickScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chickYellow,
      appBar: AppBar(
        backgroundColor: chickYellow,
        elevation: 0,
        foregroundColor: chickBrown,
        title: Text(
          title,
          style: const TextStyle(
            color: chickBrown,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: actions,
      ),
      body: child,
    );
  }
}