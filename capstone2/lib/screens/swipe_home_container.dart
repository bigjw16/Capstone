import 'package:flutter/material.dart';
import 'today_home_page.dart';
import 'home_dashboard_screen.dart';

class SwipeHomeContainer extends StatelessWidget {
  const SwipeHomeContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return PageView(
      children: const [
        TodayHomePage(),
        HomeDashboardScreen(),
      ],
    );
  }
}