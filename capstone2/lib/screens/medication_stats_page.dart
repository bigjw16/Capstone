import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../main.dart';
import '../session/patient_session.dart';
import '../widgets/chick_card.dart';
import '../widgets/chick_scaffold.dart';

class MedicationStatsPage extends StatefulWidget {
  const MedicationStatsPage({super.key});

  @override
  State<MedicationStatsPage> createState() => _MedicationStatsPageState();
}

class _MedicationStatsPageState extends State<MedicationStatsPage> {
  final _patientIdCtrl = TextEditingController();
  DocumentSnapshot<Map<String, dynamic>>? _patientDoc;
  DocumentSnapshot<Map<String, dynamic>>? _hospitalDoc;
  DocumentSnapshot<Map<String, dynamic>>? _pharmacyDoc;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _medScheduleDocs = [];
  String _status = '준비 완료';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadPatientAndHospital();
    });
  }

  Future<void> loadPatientAndHospital({String? patientIdFromList}) async {
    final patientId = (patientIdFromList ??
            PatientSession.patientId.value ??
            _patientIdCtrl.text)
        .trim();

    if (patientId.isEmpty) {
      _showMessage('환자 ID(환자명)를 입력하세요.');
      return;
    }

    try {
      await ensureSignedIn();
      setState(() => _status = '환자/병원/복약 정보 불러오는 중...');

      final patient = await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .get();

      if (!patient.exists) {
        setState(() {
          _patientDoc = null;
          _hospitalDoc = null;
          _pharmacyDoc = null;
          _medScheduleDocs = [];
          _status = '환자 문서를 찾을 수 없습니다.';
        });
        return;
      }

      final hospitalId = patient.data()?['hospitalId'] as String?;
      DocumentSnapshot<Map<String, dynamic>>? hospital;

      if (hospitalId != null && hospitalId.isNotEmpty) {
        final hospitalById = await FirebaseFirestore.instance
            .collection('hospitals')
            .doc(hospitalId)
            .get();

        if (hospitalById.exists) {
          hospital = hospitalById;
        } else {
          final hospitalByName = await FirebaseFirestore.instance
              .collection('hospitals')
              .where('name', isEqualTo: hospitalId)
              .limit(1)
              .get();

          if (hospitalByName.docs.isNotEmpty) {
            hospital = hospitalByName.docs.first;
          }
        }
      }

      final pharmacyId = patient.data()?['pharmacyId'] as String?;
      final pharmacyName = patient.data()?['pharmacyName'] as String?;
      DocumentSnapshot<Map<String, dynamic>>? pharmacy;

      if (pharmacyId != null && pharmacyId.isNotEmpty) {
        final pharmacyById = await FirebaseFirestore.instance
            .collection('pharmacies')
            .doc(pharmacyId)
            .get();

        if (pharmacyById.exists) {
          pharmacy = pharmacyById;
        }
      }

      if (pharmacy == null && pharmacyName != null && pharmacyName.isNotEmpty) {
        final pharmacyByName = await FirebaseFirestore.instance
            .collection('pharmacies')
            .where('name', isEqualTo: pharmacyName)
            .limit(1)
            .get();

        if (pharmacyByName.docs.isNotEmpty) {
          pharmacy = pharmacyByName.docs.first;
        }
      }

      final medSnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .collection('medSchedules')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _patientIdCtrl.text = patientId;
        _patientDoc = patient;
        _hospitalDoc = hospital;
        _pharmacyDoc = pharmacy;
        _medScheduleDocs = medSnapshot.docs;
        _status = '환자/병원/복약 정보 로딩 완료';
      });
    } catch (e) {
      setState(() => _status = '불러오기 실패: $e');
      _showMessage('불러오기 실패: $e');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChickScaffold(
      title: '복약정보',
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            '상태: $_status',
            style: const TextStyle(color: chickBrown),
          ),
          ChickCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '환자 정보',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: chickBrown,
                  ),
                ),
                Text('이름: ${_patientDoc?.data()?['name'] ?? '-'}'),
                Text('생년월일: ${_patientDoc?.data()?['birthDate'] ?? '-'}'),
                Text('보호자: ${_patientDoc?.data()?['guardianName'] ?? '-'}'),
              ],
            ),
          ),
          ChickCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '병원 정보',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: chickBrown,
                  ),
                ),
                Text('병원명: ${_hospitalDoc?.data()?['name'] ?? '-'}'),
                Text('주소: ${_hospitalDoc?.data()?['address'] ?? '-'}'),
                Text('연락처: ${_hospitalDoc?.data()?['phone'] ?? '-'}'),
              ],
            ),
          ),
          ChickCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '약국 정보',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: chickBrown,
                  ),
                ),
                Text(
                    '약국명: ${_pharmacyDoc?.data()?['name'] ?? _patientDoc?.data()?['pharmacyName'] ?? '-'}'),
                Text(
                    '주소: ${_pharmacyDoc?.data()?['address'] ?? _patientDoc?.data()?['pharmacyAddress'] ?? '-'}'),
                Text(
                    '연락처: ${_pharmacyDoc?.data()?['phone'] ?? _patientDoc?.data()?['pharmacyPhone'] ?? '-'}'),
              ],
            ),
          ),
          ChickCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '복약 스케줄',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: chickBrown,
                  ),
                ),
                if (_medScheduleDocs.isEmpty)
                  const Text('복약 스케줄이 없습니다.')
                else
                  ..._medScheduleDocs.map((doc) {
                    final data = doc.data();
                    final times =
                        (data['times'] as List<dynamic>? ?? []).join(', ');

                    return ListTile(
                      leading: const Icon(
                        Icons.medication,
                        color: chickOrange,
                      ),
                      title: Text('${data['medicineName'] ?? ''}'),
                      subtitle: Text(
                        '용량: ${data['dosage'] ?? ''} / 시간: $times',
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}