# Capstone Project

# Smart Medication Management System

의공학과 Capstone Design 프로젝트
최종 결과물은 Capstone2 폴더로 이동하여 확인하길 바랍니다. 

---

## 프로젝트 소개

Smart Medication Management System은 고령자 및 만성질환자의 복약 순응도 향상을 목표로 개발된 통합 복약 관리 플랫폼입니다.

기존 복약 관리 서비스는 사용자 개인 중심으로 제공되어 보호자 및 의료진이 환자의 복약 상태를 실시간으로 확인하기 어렵다는 한계가 있습니다.

본 프로젝트는 모바일 애플리케이션, 웹 관리 시스템, IoT 복약 관리 장치를 통합하여 환자·보호자·의료진이 동일한 데이터를 공유할 수 있는 스마트 복약 관리 환경을 구축하였습니다.

Firebase 기반 클라우드 데이터베이스를 활용하여 복약 일정, 복약 기록, 환자 정보 및 약물 정보를 실시간으로 동기화하며, IoT 장치를 통해 실제 복약 여부를 자동으로 기록할 수 있습니다.

---

# 프로젝트 목표

* 복약 시간 누락 방지
* 환자 복약 이력 자동 기록
* 보호자 및 의료진 모니터링 지원
* 병원 중심 환자 관리 시스템 구축
* IoT 기반 복약 확인 자동화
* 음식-약물 상호작용 정보 제공

---

# 설치 및 환경 구성

자세한 개발 환경 구축 방법은 아래 문서를 참고하세요.

[개발 환경 구축 방법](Project_Development_Guide.md)

---

# 업데이트 내역

프로젝트 버전별 변경 사항은 아래 문서를 참고하세요.


[업데이트 내역](CHANGELOG.md)

---

# 시스템 구성

```text
                           ┌──────────────────┐
                           │Flutter Mobile App│
                           └─────────┬────────┘
                                     │
                                     ▼

                    ┌────────────────────────────┐
                    │         Firebase           │
                    │────────────────────────────│
                    │ Authentication             │
                    │ Cloud Firestore            │
                    │ Realtime Database          │
                    └───────┬───────────┬────────┘
                            │           │
                            │           │
                            ▼           ▼

                 ┌────────────────┐  ┌─────────────────┐
                 │ Web Dashboard  │  │ ESP8266 IoT     │
                 │ Hospital Admin │  │ Controller      │
                 └────────────────┘  └────────┬────────┘
                                              │
                                              ▼

                                  ┌───────────────────┐
                                  │ Arduino Mega 2560 │
                                  │ TFT LCD Display   │
                                  │ Button Interface  │
                                  └─────────┬─────────┘
                                            │
                                            ▼

                                   ┌────────────────┐
                                   │   DFPlayer     │
                                   │ Voice Alert    │
                                   └────────────────┘
```

---

# 프로젝트 구조

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
│   └── TFT LCD Interface
│
└── documents/
```

---

# 주요 기능

## Flutter 모바일 애플리케이션

### 환자 관리

* 환자 등록
* 환자 정보 수정
* 보호자 정보 관리

### 복약 관리

* 복약 일정 등록
* 복약 일정 수정
* 복약 알림 확인
* 복약 이력 조회

### 복약 통계

* 복약률 계산
* 복약 완료 횟수 확인
* 미복용 날짜 확인
* 환자별 복약 현황 분석

### 음식 정보 제공

* 안전 음식 정보
* 주의 음식 정보
* 위험 음식 정보

---

## 병원 웹 관리 시스템

### 관리자 인증

* Firebase Authentication 로그인
* 관리자 권한 검증

### 병원 및 약국 관리

* 병원 등록
* 약국 등록
* 연락처 관리

### 환자 관리

* 환자 등록
* 환자 정보 수정
* 보호자 정보 관리

### 약 정보 관리

* 약 이름 등록
* 성분 등록
* ESP8266 영문 약 이름 매핑

### 복약 일정 관리

* 복약 시간 설정
* 식전 / 식후 / 공복 설정
* 반복 복약 설정
* 요일별 복약 설정

### 음식 위험도 관리

* 안전
* 주의
* 매우 위험

분류 기반 음식 정보 관리

### 복약 기록 조회

* RTDB 데이터 조회
* 환자별 복약 이력 확인

---

## IoT 복약 관리 시스템

### ESP8266

* WiFi 연결
* Firebase Authentication 로그인
* Firestore 복약 일정 조회
* NTP 시간 동기화
* Realtime Database 저장

### Arduino Mega

* TFT LCD 사용자 인터페이스
* 복약 확인 버튼 처리
* 보호자 알림 화면
* 복약 상태 시각화

### DFPlayer Mini

* 음성 복약 알림
* MP3 음성 출력

### 데이터 저장

* 복약 예정 시간
* 실제 복약 시간
* 복약 응답 방식
* 환자 정보

---

# 사용 기술

## Mobile

* Flutter
* Dart

## Backend

* Firebase Authentication
* Cloud Firestore
* Firebase Realtime Database

## Web

* HTML5
* CSS3
* JavaScript

## IoT

* ESP8266 NodeMCU
* Arduino Mega 2560
* DFPlayer Mini
* TFT LCD (ILI9341)
* SoftwareSerial

---

# Firebase 데이터 구조

## Firestore

```text
patients
patients/{patientId}/medSchedules

hospitals

pharmacies

medicines

medicineFoodInfo

adminUsers
```

---

## Realtime Database

```text
patients/{patientId}/medLogs

medicationResponses/{patientId}
```

---

# 데이터 흐름

## 복약 일정 등록

```text
의료진
   │
   ▼
Web Dashboard
   │
   ▼
Firestore 저장
```

---

## 복약 알림

```text
Firestore
   │
   ▼
ESP8266
   │
   ▼
Arduino Mega
   │
   ▼
LCD + 음성 알림
```

---

## 복약 완료

```text
사용자
   │
   ▼
버튼 입력
   │
   ▼
Arduino Mega
   │
   ▼
ESP8266
   │
   ▼
Realtime Database 저장
```

---

## 복약 현황 조회

```text
Firebase
   │
   ├── Flutter App
   │
   ├── Web Dashboard
   │
   └── 보호자
```

---

# 기대 효과

* 복약 누락 감소
* 복약 순응도 향상
* 보호자 모니터링 지원
* 의료진의 환자 관리 효율 향상
* 복약 데이터 기반 분석 가능
* 디지털 헬스케어 환경 구축

---

# 향후 개발 계획

* 보호자 SMS 알림
* 모바일 Push Notification
* AI 기반 복약 상담 기능
* 복약 통계 시각화 고도화
* 음식-약물 상호작용 자동 분석
* 의료진 대시보드 확장
* 병원 EMR 연동

---

# 개발 환경

* Flutter SDK
* Android Studio
* Visual Studio Code
* Arduino IDE
* Firebase Console
* GitHub

---

# Repository

GitHub Repository

https://github.com/bigjw16/Capstone

---

# License

This project was developed as a Capstone Design Project for educational and academic purposes.
