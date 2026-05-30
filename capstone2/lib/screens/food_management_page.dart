import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../session/patient_session.dart';
import '../widgets/chick_card.dart';
import '../widgets/chick_scaffold.dart';

class FoodManagementPage extends StatefulWidget {
  const FoodManagementPage({super.key});

  @override
  State<FoodManagementPage> createState() => _FoodManagementPageState();
}

class FoodCache {
  static final Map<String, List<Map<String, dynamic>>> foodCache = {};
}

class _FoodManagementPageState extends State<FoodManagementPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _foodInfos = [];

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await _prefetchFoodData();
      await _loadFoodInfo();
    });
  }

  Future<void> _prefetchFoodData() async {
  final patientId =
      PatientSession.patientId.value ?? 'default-patient';

  final medSnapshot = await FirebaseFirestore.instance
      .collection('patients')
      .doc(patientId)
      .collection('medSchedules')
      .get();

  final allIngredients = <String>{};

  for (final doc in medSnapshot.docs) {
    final ingredients = List<String>.from(
      doc.data()['ingredients'] ?? [],
    );

    allIngredients.addAll(ingredients);
  }

  final foodFutures = allIngredients.map((ingredient) async {
    final doc = await FirebaseFirestore.instance
        .collection('medicineFoodInfo')
        .doc(ingredient)
        .get();

    if (!doc.exists) return null;

    return MapEntry(
      ingredient,
      doc.data(),
    );
  });

  final foodResults = await Future.wait(foodFutures);

  for (final item in foodResults) {
    if (item != null) {
      FoodCache.foodCache[item.key] =
          List<Map<String, dynamic>>.from(
        item.value?['foodRisks'] ?? [],
      );
    }
  }
}

  Future<void> _loadFoodInfo() async {
  try {
    final patientId =
        PatientSession.patientId.value ?? 'default-patient';

    final medSnapshot = await FirebaseFirestore.instance
        .collection('patients')
        .doc(patientId)
        .collection('medSchedules')
        .get();

    final List<Map<String, dynamic>> loadedFoods = [];

    for (final doc in medSnapshot.docs) {
      final data = doc.data();

      final medicineName =
          data['medicineName']?.toString() ?? '';

      final ingredients =
        (data['ingredients'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

      final foods = <Map<String, dynamic>>[];

      for (final ingredient in ingredients) {
        final cachedRisks =
            FoodCache.foodCache[ingredient] ?? [];

        for (final risk in cachedRisks) {
          foods.add({
            'food': risk['food'],
            'severity': risk['severity'],
            'reason': risk['reason'],
            'ingredient': ingredient,
          });
        }
      }

      loadedFoods.add({
        'medicineName': medicineName,
        'ingredients': ingredients,
        'foods': foods,
      });
    }

    setState(() {
      _foodInfos = loadedFoods;
      _loading = false;
    });
  } catch (e) {
    debugPrint('로딩 실패: $e');

    setState(() {
      _loading = false;
    });
  }
}

  Color _severityColor(String severity) {
    switch (severity) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'high':
        return '🔴 매우 위험';
      case 'medium':
        return '🟡 주의';
      default:
        return '🟢 안전';
    }
  }

  Widget _foodChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: chickBrown,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChickScaffold(
      title: '식품관리',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _foodInfos.isEmpty
              ? const Center(
                  child: Text(
                    '등록된 음식 정보가 없습니다.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: chickBrown,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _foodInfos.length,
                  itemBuilder: (_, index) {
                    final data = _foodInfos[index];
                    final medicineName = data['medicineName'] ?? '-';
                    final ingredients =
                        (data['ingredients'] as List<dynamic>? ?? [])
                            .map((e) => e.toString())
                            .toList();
                    final foods = (data['foods'] as List<dynamic>? ?? [])
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();

                    return ChickCard(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.medication, color: chickOrange),
                              const SizedBox(width: 8),
                              Text(
                                medicineName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: chickBrown,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ingredients.isEmpty
                                ? [const Text('등록된 성분 없음')]
                                : ingredients
                                    .map((ingredient) =>
                                        _foodChip(ingredient, Colors.orange))
                                    .toList(),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '음식 상호작용 위험도',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: chickBrown,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Column(
                            children: foods.isEmpty
                                ? [const Text('등록된 정보 없음')]
                                : foods.map((food) {
                                    final name = food['food'] ?? '-';
                                    final severity =
                                        food['severity'] ?? 'low';
                                    final reason = food['reason'] ?? '';
                                    final ingredient =
                                        food['ingredient'] ?? '';

                                    return Container(
                                      margin:
                                          const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _severityColor(severity)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _severityColor(severity),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _foodChip(
                                            '${_severityLabel(severity)} $name',
                                            _severityColor(severity),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '성분: $ingredient',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          if (reason.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              reason,
                                              style: const TextStyle(
                                                  fontSize: 13),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}