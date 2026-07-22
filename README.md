![Arduino](https://img.shields.io/badge/Arduino-00979D?style=for-the-badge&logo=Arduino&logoColor=white)
![ESP8266](https://img.shields.io/badge/ESP8266-E7352C?style=for-the-badge)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
# IoT Medication Management Module

> **Biomedical Engineering Capstone Design Project**

ESP8266(NodeMCU)와 Arduino Mega를 기반으로 개발된 IoT 복약 관리 모듈입니다.

Firebase Cloud Firestore에서 복약 일정을 조회하고, 복약 시간이 되면 음성 및 LCD를 통해 사용자에게 알림을 제공합니다. 사용자의 복약 응답은 Firebase Realtime Database에 저장되어 Flutter 애플리케이션과 Web Dashboard에서 실시간으로 확인할 수 있습니다.

---

# 📖 프로젝트 소개

IoT Medication Management Module은 스마트 복약 관리 시스템의 IoT 장치입니다.

ESP8266은 Firebase와 통신하여 복약 일정을 조회하고, Arduino Mega와 연동하여 LCD 화면 및 음성 알림을 제공합니다. 사용자가 복약을 완료하면 해당 기록을 Firebase Realtime Database에 저장하여 모바일 앱과 웹 시스템에서 실시간으로 확인할 수 있습니다.

---

# ✨ 주요 기능

- WiFi 연결
- Firebase Authentication 인증
- Cloud Firestore 복약 일정 조회
- NTP 기반 시간 동기화
- DFPlayer Mini 음성 알림
- TFT LCD 복약 안내
- 복약 완료 입력 처리
- Firebase Realtime Database 기록 저장

---

# 🏗️ 시스템 구성

```text
        Flutter App / Web Dashboard
                    │
                    ▼
      Firebase Authentication
 Cloud Firestore / Realtime Database
                    │
                    ▼
            ESP8266 (NodeMCU)
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
 Arduino Mega             DFPlayer Mini
    │
    ▼
 TFT LCD
    │
    ▼
 User Response
```

---

# 🔄 시스템 동작 흐름

```text
Cloud Firestore
       │
       ▼
ESP8266 (Schedule Check)
       │
       ▼
Arduino Mega + DFPlayer
       │
       ▼
User Medication Response
       │
       ▼
Realtime Database
       │
       ▼
Flutter App / Web Dashboard
```

---

# 🛠️ 기술 스택

| Category | Technology |
|----------|------------|
| MCU | ESP8266 (NodeMCU), Arduino Mega 2560 |
| Cloud | Firebase Authentication, Cloud Firestore, Realtime Database |
| Communication | WiFi, SoftwareSerial |
| Hardware | TFT LCD, DFPlayer Mini |
| Development | Arduino IDE |

---

# 📂 프로젝트 구조

```text
IOT/
│
├── ESP8266/
│
├── ArduinoMega/
│
├── libraries/
│
└── README.md
```

---

# 🚀 시작하기

## 개발 환경

- Arduino IDE
- ESP8266 Board Package
- Firebase 프로젝트
- WiFi Network

### 라이브러리 설치

다음 라이브러리를 Arduino IDE에 설치합니다.

- ESP8266WiFi
- ESP8266HTTPClient
- ArduinoJson
- SoftwareSerial
- DFRobotDFPlayerMini

프로젝트 업로드 후 Serial Monitor(115200 baud)를 통해 정상 동작 여부를 확인할 수 있습니다.

---

# 🗄️ Firebase 데이터 구조

## Cloud Firestore

```text
patients
 └── {patientId}
      └── medSchedules
```

## Realtime Database

```text
patients
 └── {patientId}
      └── medLogs
```

---

# 📡 Serial Communication Protocol

### ESP8266 → Arduino Mega

```text
ALERT|09:30|1|MedicineName
```

### Arduino Mega → ESP8266

```text
TAKEN|09:30|MedicineName
```
---

# 🚀 향후 개발 계획

- 보호자 알림 서비스
- Flutter Push Notification 연동
- 병원 EMR 연계
- AI 기반 복약 순응도 분석
- 음성 인식 기반 복약 확인
- 다중 사용자 지원

---

# 📜 License

This project was developed as a Biomedical Engineering Capstone Design Project for educational purposes.
