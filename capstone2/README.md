# Patient Medication Sync System

> **Biomedical Engineering Capstone Design Project**

Web, Flutter, Firebase, IoT Device를 연동하여 환자의 복약 정보를 실시간으로 관리하는 스마트 복약 관리 시스템입니다.

---

# 📖 프로젝트 소개

Patient Medication Sync System은 병원, 환자, 보호자가 하나의 플랫폼에서 복약 정보를 공유할 수 있도록 개발된 통합 복약 관리 시스템입니다.

Firebase 기반 클라우드 서비스를 활용하여 복약 일정과 복약 기록을 실시간으로 동기화하며, Flutter 모바일 애플리케이션과 Web Portal을 통해 데이터를 관리합니다. 또한 ESP8266 기반 IoT 장치와 연동하여 실제 복약 여부를 자동으로 기록할 수 있도록 설계되었습니다.

---

# ✨ 주요 기능

## 🌐 Web Portal

- 병원 및 환자 정보 관리
- 약 정보 등록
- 음식-약물 상호작용 관리
- 복약 일정 조회

---

## 📱 Flutter Application

- 환자 정보 조회
- 복약 일정 관리
- 복약 통계 제공
- 캘린더 기반 복약 일정 표시
- 음식 추천 및 주의 음식 조회

---

## 📟 IoT Device

- Firebase 데이터 연동
- 복약 알림 표시
- 버튼 입력을 통한 복약 확인
- 복약 기록 자동 저장

---

# 🏗️ 시스템 구성

```text
                 Flutter Mobile App
                         │
                         ▼
      Firebase Authentication / Firestore / RTDB
            │                          │
            ▼                          ▼
      Web Portal                 ESP8266 Device
                                         │
                                         ▼
                                  Arduino Mega
                                         │
                                         ▼
                                LCD & Voice Alert
```

---

# 🛠️ 기술 스택

| Category | Technology |
|----------|------------|
| Mobile | Flutter, Dart |
| Backend | Firebase Authentication, Cloud Firestore, Realtime Database |
| Web | HTML, CSS, JavaScript |
| IoT | ESP8266, Arduino Mega 2560 |
| Hardware | DFPlayer Mini, TFT LCD |

---

# 📂 프로젝트 구조

```text
project-root/
│
├── flutter_app/
├── web-portal/
├── firebase/
│   └── firestore.rules
│
└── README.md
```

---

# 🚀 시작하기

```bash
flutter clean
flutter pub get
flutter run
```

Web Portal 실행

```bash
python -m http.server 8080
```

접속

```
http://localhost:8080/web-portal/
```

---

# 🗄️ Firebase 데이터 구조

## Cloud Firestore

```text
hospitals

patients

patients/{patientId}/medSchedules

medicines

medicineFoodInfo
```

## Realtime Database

```text
patients/{patientId}/medLogs
```

---

# 🔄 데이터 흐름

## 병원 및 환자 등록

```text
Web Portal
     │
     ▼
Cloud Firestore
```

## 복약 일정 등록

```text
Flutter App
      │
      ▼
Cloud Firestore
```

## 복약 알림

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

## 복약 완료

```text
User
 │
 ▼
Button Input
 │
 ▼
ESP8266
 │
 ▼
Realtime Database
```

---

# 📄 문서

- 📘 [개발 환경 구축 가이드](./Project_Development_Guide.md)
- 🔥 [Firebase 설정](./Firebase_Setup.md)
- 🛠️ [문제 해결 가이드](./Troubleshooting.md)
- 📝 [CHANGELOG](./CHANGELOG.md)

---

# 🚀 향후 개발 계획

- Push Notification
- 보호자 알림 서비스
- AI 기반 복약 상담
- 복약 통계 시각화
- EMR 연동
- 사용자 권한 관리

---

# 📜 License

This project was developed as a Biomedical Engineering Capstone Design Project for educational purposes.
