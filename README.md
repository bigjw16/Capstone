# Capstone Web Dashboard

Firebase 기반 스마트 복약 관리 시스템의 병원·환자 통합 관리 웹페이지입니다.

본 웹 대시보드는 의료진 및 관리자 계정을 대상으로 개발되었으며, 환자 정보 관리부터 복약 일정 등록, 약 정보 관리, 음식 위험도 관리, 복약 기록 조회까지 하나의 화면에서 수행할 수 있습니다.

---

# 프로젝트 소개

본 프로젝트는 캡스톤 디자인 과제로 개발 중인 **스마트 복약 관리 시스템(Smart Medication Management System)** 의 웹 관리 플랫폼입니다.

Firebase Firestore와 Realtime Database를 기반으로 병원, 약국, 환자, 약 정보 및 복약 데이터를 통합 관리할 수 있으며, ESP8266 IoT 디바이스와 Flutter 모바일 앱과 연동됩니다.

---

# 주요 기능

## 관리자 인증

* Firebase Authentication 로그인
* 검증된 관리자(adminUsers) 권한 확인
* 승인된 관리자만 접근 가능

---

## 병원 및 약국 관리

* 병원 정보 등록
* 병원 연락처 및 주소 관리
* 약국 정보 등록
* 환자와 병원 정보 연동

---

## 환자 정보 관리

* 환자 등록
* 환자 정보 수정
* 보호자 정보 등록
* ESP8266 RTDB 환자 ID 연동

---

## 복약 일정 관리

* 환자별 복약 스케줄 등록
* 날짜 및 시간 설정
* 식전 / 식후 / 공복 설정
* 아침 / 점심 / 저녁 구분
* 매일 반복 설정
* 요일 반복 설정
* 반복 종료일 설정

---

## 약 정보 관리

* 약 이름 등록
* ESP8266 영문 약 이름 매핑
* 약 성분 관리
* 자동완성 검색 지원

---

## 음식 위험도 관리

* 성분별 음식 정보 등록
* 안전
* 주의
* 매우 위험

위험도 분류 및 복용 주의사항 저장

---

## 복약 기록 조회

* Firebase Realtime Database 조회
* ESP8266 복약 기록 확인
* 환자별 복약 이력 조회
* 약 이름 자동 변환 기능

---

## 자동완성 기능

* 환자 검색
* 약 검색
* 성분 검색
* 등록 데이터 자동 불러오기

---

# 프로젝트 구조

```text
Capstone
│
├── hospital.html
├── README.md
└── 웹페이지 들어가기.txt
```

---

# 시스템 구성

```text
Flutter App
      │
      ▼
Firebase Firestore
      │
      ├── 병원 정보
      ├── 약국 정보
      ├── 환자 정보
      ├── 약 정보
      └── 복약 일정
      │
      ▼
Web Dashboard
      │
      ▼
Firebase Realtime Database
      │
      ▼
ESP8266 IoT Device
```

---

# 사용 기술

## Front-End

* HTML5
* CSS3
* JavaScript (ES6)

## Backend

* Firebase Authentication
* Firebase Firestore
* Firebase Realtime Database

## External Services

* Firebase Hosting
* GitHub

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
```

---

# 실행 방법

## 저장소 클론

```bash
git clone https://github.com/bigjw16/Capstone.git
```

## Web 브랜치 이동

```bash
git checkout webpage
```

## 웹페이지 실행

### 방법 1

hospital.html 실행

### 방법 2 (권장)

```bash
python -m http.server 8080
```

브라우저 접속

```text
http://localhost:8080
```

---

# 관리자 계정

테스트용 계정

```text
E-mail : admin@example.com
Password : admin1234
```

※ 실제 운영 환경에서는 Firebase Authentication 계정과 Firestore의 adminUsers 컬렉션에 등록된 승인 계정만 접근 가능합니다.

---

# ESP8266 연동

IoT 브랜치에서 동작하는 ESP8266과 연동됩니다.

복약 기록 저장 경로

```text
patients/{patientId}/medLogs
```

웹페이지에서는 해당 데이터를 조회하여 복약 이력을 표시합니다.

---

# 개발 목적

본 프로젝트는 고령자 및 만성질환자의 복약 순응도를 향상시키기 위한 스마트 복약 관리 시스템 구축을 목표로 합니다.

Flutter 모바일 앱, Firebase 클라우드 데이터베이스, ESP8266 IoT 디바이스, 웹 관리 시스템을 통합하여 병원·보호자·환자 간 복약 정보를 실시간으로 공유할 수 있도록 설계되었습니다.

---

# 향후 개발 예정

* 실시간 복약 현황 모니터링 대시보드
* 복약 통계 시각화
* 보호자 관리 기능
* 병원별 환자 통계
* 알림 이력 관리
* 관리자 권한 세분화
* Firebase Hosting 배포
* AI 기반 복약 순응도 분석

---

# Repository

GitHub Repository

https://github.com/bigjw16/Capstone

Branch

```text
webpage
```

---

# License

This project was developed for educational and academic purposes as a Capstone Design Project.
