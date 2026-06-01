# Capstone IoT Module

ESP8266 기반 복약 기록 전송 시스템입니다.

사용자가 복약을 수행한 시점의 시간을 인터넷 시간(NTP)으로 받아 Firebase Realtime Database에 저장합니다.

본 모듈은 캡스톤 디자인 프로젝트의 스마트 복약 관리 시스템 일부로 개발되었습니다.

---

# 주요 기능

* WiFi 연결
* NTP 서버를 이용한 실시간 시간 동기화
* Firebase Realtime Database 연동
* 복약 시간 자동 기록
* 시리얼 명령을 통한 복약 이벤트 전송

---

# 시스템 구성

```text
ESP8266
   │
   ├── WiFi
   │
   ▼
NTP Server
   │
   ▼
현재 시간 획득
   │
   ▼
Firebase Realtime Database
   │
   ▼
복약 기록 저장
```

---

# 사용 기술

* ESP8266 (NodeMCU)
* Arduino IDE
* Firebase Realtime Database
* NTPClient
* WiFiUDP
* Firebase ESP Client Library

---

# 라이브러리

Arduino IDE에서 아래 라이브러리를 설치해야 합니다.

```cpp
ESP8266WiFi
WiFiUdp
NTPClient
Firebase_ESP_Client
```

---

# Firebase 데이터 구조

복약 기록은 아래 경로에 저장됩니다.

```json
{
  "patients": {
    "patient001": {
      "medLogs": {
        "-OVxxxx": "2025-05-20 08:03:15",
        "-OVyyyy": "2025-05-20 13:01:22"
      }
    }
  }
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

익명 인증을 사용하여 Firebase에 로그인합니다.

```cpp
Firebase.signUp(&config, &auth, "", "");
```

---

### 3. 시간 동기화

NTP 서버에서 한국 시간(UTC+9)을 가져옵니다.

```cpp
NTPClient(
  ntpUDP,
  "pool.ntp.org",
  9 * 3600,
  60000
);
```

---

### 4. 복약 기록 저장

시리얼 모니터에서 다음 명령 입력

```text
a
```

현재 시간이 Firebase에 저장됩니다.

예시

```text
2025-05-20 08:03:15
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

1. NodeMCU 1.0(ESP-12E Module) 선택
2. COM 포트 선택
3. 업로드

---

# 시리얼 모니터

속도

```text
115200 baud
```

사용 명령

```text
a
```

출력 예시

```text
WiFi 연결 성공
Firebase 연결 성공

'a' 입력 시 복약 기록 저장

저장할 시간 : 2025-05-20 08:03:15
복약 기록 저장 성공
```

---

# 프로젝트 목적

본 프로젝트는 고령자 및 만성질환자의 복약 순응도를 향상시키기 위한 스마트 복약 관리 시스템 구축을 목표로 합니다.

IoT 디바이스를 통해 복약 여부를 자동으로 기록하고 Firebase에 저장하여 모바일 앱 및 웹 대시보드와 연동할 수 있습니다.

---

# 향후 개발 계획

* 물리 버튼 입력 지원
* DFPlayer Mini 음성 알림
* LED 복약 알림
* Flutter 앱 연동
* 웹 대시보드 실시간 모니터링
* 복약 통계 분석 기능

---

# License

This project was developed for educational purposes as a Capstone Design Project.
