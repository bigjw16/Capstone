# Capstone IoT Module

ESP8266(NodeMCU)와 Arduino Mega를 이용한 IoT 기반 스마트 복약 관리 시스템입니다.

Firebase Firestore에 등록된 복약 일정을 조회하고, 복약 시간이 되면 음성 및 LCD 화면을 통해 사용자에게 알림을 제공합니다.

사용자의 복약 응답은 Firebase Realtime Database에 저장되며, Flutter 앱 및 웹 대시보드와 연동하여 복약 현황을 실시간으로 확인할 수 있습니다.

본 모듈은 캡스톤 디자인 프로젝트의 스마트 복약 관리 시스템 일부로 개발되었습니다.

---

# 주요 기능

* WiFi 연결
* Firebase Authentication 로그인
* Firestore 복약 일정 조회
* NTP 서버 기반 실시간 시간 동기화
* DFPlayer Mini 음성 알림
* Arduino Mega TFT LCD 연동
* 복약 완료 여부 기록
* Firebase Realtime Database 저장
* 보호자 알림 기능

---

# 시스템 구성

```text
Flutter App / Web Dashboard
                │
                ▼
        Firebase Firestore
                │
                ▼
        ESP8266 (NodeMCU)
                │
    ┌───────────┴───────────┐
    ▼                       ▼
DFPlayer Mini         Arduino Mega
(음성 알림)            (TFT LCD)
                            │
                            ▼
                      사용자 응답
                            │
                            ▼
          Firebase Realtime Database
```

---

# 사용 기술

* ESP8266 (NodeMCU)
* Arduino IDE
* Firebase Authentication
* Firebase Firestore
* Firebase Realtime Database
* NTP Time Service
* DFPlayer Mini
* SoftwareSerial
* ArduinoJson

---

# 라이브러리

Arduino IDE에서 아래 라이브러리를 설치해야 합니다.

```cpp
ESP8266WiFi
ESP8266HTTPClient
ArduinoJson
SoftwareSerial
DFRobotDFPlayerMini
time
```

---

# Firebase 데이터 구조

## Firestore

복약 일정 조회

```text
patients
 └─ {patientId}
      └─ medSchedules
```

예시

```json
{
  "medicineName": "당뇨약",
  "times": ["08:00", "20:00"],
  "repeatDaily": true
}
```

---

## Realtime Database

복약 응답 저장

```text
medicationResponses
 └─ {patientId}
      └─ autoPushId
```

예시

```json
{
  "patientId": "무한",
  "medicineName": "당뇨약",
  "scheduledTime": "08:00",
  "takenAt": "2026-06-05 08:01:12",
  "responseType": "mega_display"
}
```

---

# 동작 방식

### 1. WiFi 연결

ESP8266이 지정된 WiFi 네트워크에 연결합니다.

```cpp
WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
```

---

### 2. Firebase 로그인

Firebase Authentication을 통해 로그인합니다.

```cpp
accounts:signInWithPassword
```

---

### 3. 시간 동기화

NTP 서버를 통해 한국 시간(UTC+9)을 동기화합니다.

```cpp
configTime(
  9 * 3600,
  0,
  "pool.ntp.org",
  "time.nist.gov"
);
```

---

### 4. 복약 일정 조회

Firestore에서 환자의 복약 일정을 조회합니다.

```text
patients/{patientId}/medSchedules
```

현재 시간과 일치하는 복약 일정이 존재하는지 확인합니다.

---

### 5. 음성 알림 출력

복약 시간이 되면 DFPlayer Mini를 통해 음성 안내를 출력합니다.

```cpp
dfPlayer.play(1);
```

---

### 6. LCD 복약 알림

ESP8266은 Arduino Mega로 복약 알림 명령을 전송합니다.

```text
ALERT|09:30|1|당뇨약
```

Mega는 TFT LCD 화면에 복약 정보를 표시합니다.

---

### 7. 사용자 응답

사용자가 LCD 화면에서 복약을 완료하면 Mega가 ESP8266으로 응답을 전송합니다.

```text
TAKEN|09:30|당뇨약
```

---

### 8. 복약 결과 저장

복약 완료 정보가 Firebase Realtime Database에 저장됩니다.

```cpp
POST
/medicationResponses/{patientId}
```

---

# 실행 방법

### 저장소 클론

```bash
git clone https://github.com/bigjw16/Capstone.git
```

### IoT 브랜치 이동

```bash
git checkout IOT
```

### Arduino IDE 업로드

#### ESP8266

1. NodeMCU 1.0 (ESP-12E Module) 선택
2. COM 포트 선택
3. 업로드

#### Arduino Mega

1. Arduino Mega 2560 선택
2. COM 포트 선택
3. 업로드

---

# 시리얼 모니터

속도

```text
115200 baud
```

출력 예시

```text
WiFi 연결 성공
Firebase Auth 로그인 성공

현재 날짜: 2026-06-05
현재 시간: 09:30

====== 복약 알림 ======
약 이름: 당뇨약
Mega 화면으로 ALERT 명령 전송
DFPlayer 0001.mp3 재생 시도
======================
```

복약 완료 시

```text
Mega 복약 완료 응답 수신

====== 복약 응답 저장 완료 ======
약 이름: 당뇨약
응답 시간: 2026-06-05 09:31:02
================================
```

---

# 통신 프로토콜

### ESP8266 → Arduino Mega

```text
ALERT|09:30|1|당뇨약
```

### Arduino Mega → ESP8266

```text
TAKEN|09:30|당뇨약
```

### 보호자 알림

```text
GUARDIAN_ALERT
```

### 전체 복약 완료

```text
ALL_DONE
```

---

# 프로젝트 목적

본 프로젝트는 고령자 및 만성질환자의 복약 순응도를 향상시키기 위한 스마트 복약 관리 시스템 구축을 목표로 합니다.

IoT 디바이스를 통해 복약 여부를 자동으로 기록하고 Firebase에 저장하여 모바일 앱 및 웹 대시보드와 연동할 수 있습니다.

또한 음성 알림과 시각적 인터페이스를 제공하여 디지털 기기 사용이 익숙하지 않은 사용자도 쉽게 복약 관리를 수행할 수 있도록 설계되었습니다.

---

# 향후 개발 계획

* 보호자 SMS 알림 연동
* 병원 EMR 연계
* AI 기반 복약 순응도 분석
* 음성 인식 복약 확인 기능
* Flutter 앱 푸시 알림 연동
* 복약 통계 시각화 기능
* 다중 환자 지원 기능

---

# License

This project was developed for educational purposes as a Capstone Design Project.
