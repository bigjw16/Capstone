import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../widgets/chick_card.dart';
import '../widgets/chick_scaffold.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ChickScaffold(
      title: title,
      child: const Center(
        child: ChickCard(
          child: Text(
            '개발중입니다.',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: chickBrown,
            ),
          ),
        ),
      ),
    );
  }
}