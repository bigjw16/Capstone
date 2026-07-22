# Smart Medication Management System

> Biomedical Engineering Capstone Design Project

고령자 및 만성질환자의 복약 순응도 향상을 위한 **모바일·웹·IoT 기반 스마트 복약 관리 시스템**

---

# 📖 프로젝트 소개

Smart Medication Management System은 환자, 보호자, 의료진이 하나의 플랫폼에서 복약 정보를 실시간으로 공유할 수 있도록 개발된 통합 복약 관리 시스템입니다.

기존 복약 관리 서비스가 개인 중심으로 운영되는 한계를 개선하기 위해 모바일 애플리케이션, 병원 웹 관리 시스템, IoT 복약 장치를 연동하였으며 Firebase 기반 클라우드를 이용하여 복약 일정과 복약 기록을 실시간으로 동기화합니다.

IoT 장치를 통해 실제 복약 여부를 자동으로 기록하여 의료진과 보호자가 환자의 복약 상태를 효율적으로 관리할 수 있도록 설계하였습니다.

---

# 🎯 프로젝트 목표

- 복약 시간 누락 방지
- 복약 이력 자동 기록
- 보호자 및 의료진 모니터링
- 병원 중심 환자 관리 시스템 구축
- IoT 기반 자동 복약 확인
- 음식-약물 상호작용 정보 제공

---

# 🏗️ 시스템 아키텍처

```text
                        Flutter Mobile App
                                │
                                ▼
              Firebase Authentication / Firestore / RTDB
                     │                     │
                     ▼                     ▼
             Web Dashboard           ESP8266
                                           │
                                           ▼
                                 Arduino Mega 2560
                                           │
                                           ▼
                              TFT LCD & DFPlayer Mini
```

---

# ✨ 주요 기능

## 📱 Flutter Mobile Application

- 환자 정보 관리
- 복약 일정 조회 및 관리
- 복약 통계 제공
- 복약 이력 조회
- 음식-약물 상호작용 정보 제공

---

## 🌐 Web Dashboard

- 관리자 인증
- 병원 및 약국 관리
- 환자 관리
- 약 정보 관리
- 복약 일정 관리
- 음식 위험도 관리
- 복약 기록 조회

---

## 📟 IoT Medication Device

- WiFi 기반 Firebase 연동
- 복약 일정 조회
- TFT LCD 복약 안내
- 버튼 입력을 통한 복약 확인
- DFPlayer 음성 알림
- 복약 기록 자동 저장

---

# 🛠️ 기술 스택

| Category | Technology |
|----------|------------|
| **Mobile** | Flutter, Dart |
| **Backend** | Firebase Authentication, Cloud Firestore, Firebase Realtime Database |
| **Web** | HTML5, CSS3, JavaScript |
| **IoT** | ESP8266 NodeMCU, Arduino Mega 2560 |
| **Hardware** | TFT LCD (ILI9341), DFPlayer Mini |

---

# 📂 프로젝트 구조

```text
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
```

---

# 🚀 시작하기

## 개발 환경

- Flutter SDK
- Android Studio
- Visual Studio Code
- Arduino IDE
- Firebase Console
- GitHub

프로젝트 환경 구축 방법은 아래 문서를 참고하세요.

```
Project_Development_Guide.md
```

---

# 🗄️ Firebase 데이터 구조

## Cloud Firestore

```text
patients
patients/{patientId}/medSchedules

hospitals

pharmacies

medicines

medicineFoodInfo

adminUsers
```

## Realtime Database

```text
patients/{patientId}/medLogs

medicationResponses/{patientId}
```

---

# 🔄 시스템 데이터 흐름

## 1. 복약 일정 등록

```text
Web Dashboard
      │
      ▼
Cloud Firestore
```

## 2. 복약 알림

```text
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
```

## 3. 복약 완료

```text
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
```

## 4. 복약 현황 조회

```text
Firebase
   ├── Flutter App
   └── Web Dashboard
```

---

# 🚀 향후 개발 계획

- Push Notification 지원
- 보호자 알림 서비스
- AI 기반 복약 상담 기능
- 복약 통계 시각화 고도화
- 음식-약물 상호작용 자동 분석
- 병원 EMR 연동

---

# 📄 문서

- `Project_Development_Guide.md` : 개발 환경 구축 가이드
- `CHANGELOG.md` : 버전별 업데이트 내역

---

# 📌 Repository

```text
https://github.com/bigjw16/Capstone
```

---

# 📜 License

This project was developed as a **Biomedical Engineering Capstone Design Project** for educational purposes.
