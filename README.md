Smart Medication Management System

Biomedical Engineering Capstone Design Project

고령자 및 만성질환자의 복약 순응도 향상을 위한 모바일·웹·IoT 기반 스마트 복약 관리 시스템

프로젝트 소개

Smart Medication Management System은 환자, 보호자, 의료진이 하나의 플랫폼에서 복약 정보를 실시간으로 공유할 수 있도록 개발된 통합 복약 관리 시스템입니다.

기존 복약 관리 서비스가 개인 중심으로 운영되는 한계를 개선하기 위해 모바일 애플리케이션, 병원 웹 관리 시스템, IoT 복약 장치를 연동하였으며 Firebase 기반 클라우드를 이용하여 복약 일정과 복약 기록을 실시간으로 동기화합니다.

IoT 장치를 통해 실제 복약 여부를 자동 기록하여 의료진과 보호자가 환자의 복약 상태를 효율적으로 관리할 수 있도록 설계하였습니다.

프로젝트 목표
복약 시간 누락 방지
복약 이력 자동 기록
보호자 및 의료진 모니터링
병원 중심 환자 관리
IoT 기반 자동 복약 확인
음식-약물 상호작용 정보 제공
시스템 아키텍처
                        Flutter Mobile App
                                │
                                ▼
                    Firebase Authentication
                  Cloud Firestore / Realtime DB
                     │                     │
                     ▼                     ▼
             Web Dashboard           ESP8266
                                           │
                                           ▼
                                 Arduino Mega 2560
                                           │
                                           ▼
                              TFT LCD & DFPlayer Mini
주요 기능
Flutter Mobile App
환자 정보 관리
복약 일정 조회 및 관리
복약 통계 제공
음식-약물 상호작용 조회
복약 이력 확인
Web Dashboard
관리자 인증
병원·약국 관리
환자 관리
약 정보 관리
복약 일정 관리
음식 위험도 관리
복약 기록 조회
IoT Device
WiFi 기반 Firebase 연동
복약 일정 조회
LCD 복약 안내
버튼 입력을 통한 복약 확인
음성 복약 알림
복약 기록 자동 저장
기술 스택
Category	Technology
Mobile	Flutter, Dart
Backend	Firebase Authentication, Cloud Firestore, Realtime Database
Web	HTML, CSS, JavaScript
IoT	ESP8266, Arduino Mega 2560
Hardware	TFT LCD (ILI9341), DFPlayer Mini
프로젝트 구조
Capstone
│
├── README.md
├── CHANGELOG.md
├── Project_Development_Guide.md
│
├── capstone2/
│   ├── Flutter Application
│   └── Firebase Integration
│
├── webpage/
│   └── Hospital Dashboard
│
├── IOT/
│   ├── ESP8266 Firmware
│   ├── Arduino Mega Firmware
│   └── Peripheral Devices
│
└── documents/
실행 환경

개발 환경 구축 방법은 아래 문서를 참고하세요.

Project_Development_Guide.md
Firebase 데이터 구조
Cloud Firestore
patients
patients/{patientId}/medSchedules

hospitals

pharmacies

medicines

medicineFoodInfo

adminUsers
Realtime Database
patients/{patientId}/medLogs

medicationResponses/{patientId}
데이터 흐름
복약 일정 등록
Web Dashboard
      │
      ▼
Cloud Firestore
복약 알림
Cloud Firestore
      │
      ▼
ESP8266
      │
      ▼
Arduino Mega
      │
      ▼
LCD + Voice Alert
복약 완료
User
 │
 ▼
Arduino Mega
 │
 ▼
ESP8266
 │
 ▼
Realtime Database
복약 현황 조회
Firebase
   ├── Flutter App
   └── Web Dashboard
향후 개발 계획
Push Notification
보호자 알림 서비스
AI 기반 복약 상담
복약 통계 고도화
음식-약물 상호작용 자동 분석
병원 EMR 연동
개발 환경
Flutter SDK
Android Studio
Visual Studio Code
Arduino IDE
Firebase Console
GitHub
Repository
https://github.com/bigjw16/Capstone
License

This project was developed as a Biomedical Engineering Capstone Design Project for educational purposes.
