# Capstone Project

## Smart Medication Management System

본 프로젝트는 의공학과 졸업 Capstone Design 과제로 진행된 **스마트 복약 관리 시스템(Smart Medication Management System)** 입니다.

고령자 및 만성질환자의 복약 순응도 향상을 목표로 하며, 모바일 애플리케이션, 웹 관리 시스템, IoT 디바이스를 통합하여 복약 정보를 실시간으로 관리할 수 있는 플랫폼을 구현하였습니다.

환자, 보호자, 의료진이 동일한 데이터를 공유할 수 있도록 Firebase 기반 데이터 동기화 환경을 구축하였으며, 복약 알림부터 복약 이력 관리까지 하나의 시스템으로 제공합니다.

---

# 프로젝트 개요

기존 복약 관리 서비스는 사용자 개인에게만 제공되는 경우가 많아 보호자나 의료진이 복약 상태를 확인하기 어렵다는 한계가 있습니다.

본 프로젝트는 다음과 같은 문제를 해결하기 위해 개발되었습니다.

* 복약 시간 누락 방지
* 환자 복약 이력 기록
* 보호자 및 의료진의 복약 상태 확인
* 병원 중심 환자 데이터 관리
* IoT 장치를 통한 복약 여부 자동 기록

---

# 시스템 구성

```text
┌─────────────────┐
│ Flutter Mobile  │
│ Application     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Firebase     │
│ Authentication  │
│ Firestore       │
│ Realtime DB     │
└─────┬─────┬─────┘
      │     │
      │     │
      ▼     ▼
┌─────────┐ ┌────────────┐
│ Web Page│ │ IoT Device │
│ Dashboard│ │ ESP8266   │
└─────────┘ └────────────┘
```

---

# 업데이트 내역

프로젝트 변경 사항은 아래 문서에서 확인할 수 있습니다.

```text
CHANGELOG.md
```

---

# 프로젝트 구조

## Capstone1

초기 기능 개발 및 검증을 위한 프로토타입 프로젝트입니다.

주요 테스트 항목

* Firebase 연동 테스트
* Flutter UI 설계
* 복약 알림 기능 검증
* Firestore 데이터 구조 설계
* 웹 관리 페이지 프로토타입
* ESP8266 통신 테스트
* 데이터 동기화 구조 검증

---

## Capstone2

최종 제출 및 시연용 프로젝트입니다.

Capstone1에서 검증된 기능들을 통합하고 개선하여 실제 사용 가능한 형태로 구현하였습니다.

포함 기능

* 환자 정보 관리
* 약 정보 관리
* 복약 알림
* 복약 이력 저장
* 병원 웹 대시보드
* IoT 디바이스 연동
* Firebase 실시간 데이터 동기화

---

# 주요 기능

## 모바일 애플리케이션

* 환자 정보 등록
* 환자 정보 수정
* 약 정보 등록
* 약 정보 수정
* 복약 시간 설정
* 복약 알림 기능
* 복약 이력 조회
* Firebase 기반 데이터 동기화

---

## 병원 웹 관리 시스템

* 환자 정보 등록 및 수정
* 약물 정보 등록
* 환자 검색 기능
* 복약 정보 조회
* Firebase 데이터 관리
* 의료진용 환자 관리 인터페이스

---

## IoT 복약 관리 장치

* ESP8266 기반 구현
* WiFi 연결
* NTP 서버 시간 동기화
* Firebase Realtime Database 연동
* 복약 기록 자동 저장
* 버튼 입력 기반 복약 체크
* 향후 음성 및 LED 알림 기능 확장 예정

---

## 복약 지원 기능

* 복약 알림 제공
* 약 복용 시 권장 음식 정보 제공
* 약 복용 시 주의 음식 정보 제공
* 환자별 복약 일정 관리

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

* ESP8266 (NodeMCU)
* ESP32
* Arduino IDE
* NTPClient
* Firebase ESP Client

---

# 데이터 흐름

## 복약 알림 생성

```text
사용자
   │
   ▼
Flutter App
   │
   ▼
Firebase 저장
```

## 복약 수행

```text
사용자
   │
   ▼
IoT 버튼 입력
   │
   ▼
ESP8266
   │
   ▼
Firebase 저장
```

## 복약 현황 조회

```text
Firebase
   │
   ├── Flutter App
   │
   ├── Hospital Dashboard
   │
   └── 보호자 확인
```

---

# 기대 효과

* 복약 누락 감소
* 환자 복약 순응도 향상
* 보호자 모니터링 지원
* 의료진의 환자 관리 효율 향상
* 디지털 헬스케어 환경 구축

---

# 향후 개발 계획

* DFPlayer Mini 음성 안내 기능
* LED 기반 복약 알림 기능
* 보호자 푸시 알림 기능
* 복약 통계 시각화
* AI 기반 복약 상담 기능
* 음식-약물 상호작용 자동 분석
* 의료진 전용 대시보드 고도화

---

# 개발 환경

* Flutter SDK
* Android Studio
* Visual Studio Code
* Arduino IDE
* Firebase Console
* GitHub

---

# License

This project was developed as a Capstone Design Project for educational and academic purposes.
