# capstone2

> **Biomedical Engineering Capstone Design Project**

Web, Flutter, Firebase, IoT Device를 연동하여 환자의 복약 정보를 실시간으로 관리하는 스마트 복약 관리 시스템의 Flutter 코드 입니다.

---

# ✨ 주요 기능

## 📱 Flutter Application

- 환자 정보 조회
- 복약 일정 관리
- 복약 통계 제공
- 캘린더 기반 복약 일정 표시
- 음식 추천 및 주의 음식 조회

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
