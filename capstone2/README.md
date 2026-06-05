# Capstone2 - Patient Medication Sync System

(Web + Firebase + Flutter + Handmade Device)

본 프로젝트는 4학년 Capstone 프로젝트를 위한 기능 테스트 및 최소 구현 예제 프로젝트입니다.
Flutter 앱, Firebase, Web Portal, 그리고 Handmade Device(ESP 계열 등) 연동을 기반으로 환자의 복약 정보를 관리하고 동기화하는 시스템을 제공합니다.

---

# 프로젝트 개요

이 저장소는 다음 기능들을 포함합니다.

* 웹에서 병원/환자 정보 입력 후 Firebase 저장
* 웹에서 환자 복약 시간 조회
* 웹에서 저장한 환자 목록을 Flutter에서 실시간 조회 및 선택
* 웹에서 약 정보 입력 후 Firebase 저장
* 웹에서 약과 함께 복용 시 좋은/나쁜 음식 정보 저장
* Flutter 앱에서 환자/병원 정보 자동 조회
* Flutter에서 복약 시간 등록 후 Firebase 저장
* Flutter 홈 대시보드(캘린더 + 메뉴 UI) 구성
* 캘린더에 복약 알림 날짜 표시
* 설정 페이지 로그인 검증 기능
* 로그인 이후에만 알림 등록/복약 통계 기능 사용 가능
* 알림 등록 페이지 상/하단 분할 UI 제공
* 식품관리 페이지에서 약 기반 음식 추천 자동 조회
* Firebase 기반 실시간 데이터 동기화
* Handmade Device(ESP8266/ESP32 등) 연동 확장 가능

---

# 프로젝트 구조

```text
project-root/
│
├── web-portal/                 # 병원/환자 입력 및 복약 조회 웹 페이지
├── flutter_app/                # Flutter 모바일 앱
├── firebase/
│   └── firestore.rules         # Firestore 보안 규칙
│
└── README.md
```

---

# 개발 환경

## Flutter 기본 환경

* Flutter
* Android Studio
* Firebase
* Firestore
* Firebase Authentication
* Dart SDK

---

# Flutter 실행 방법

Flutter 기본 사용법을 따릅니다.

## 실행 순서

```bash
flutter clean
flutter pub get
flutter run
```

## 명령어 설명

### 1. Flutter 리소스 초기화

```bash
flutter clean
```

* 기존 빌드 캐시 제거
* 의존성 충돌 방지

### 2. 의존성 설치

```bash
flutter pub get
```

* `pubspec.yaml` 내부 패키지 다운로드
* 리소스 적용

### 3. 앱 실행

```bash
flutter run
```

* 연결된 디바이스에서 앱 실행

---

# Flutter 프로젝트 주요 코드 위치

```text
flutter_app/lib/main.dart
```

* 전체 앱 기능 구현
* Firebase 연동
* UI 구성
* 알림/복약/식품 관리 기능 포함

---

# Flutter Icon 설정

## 아이콘 적용 방법

1. `1024 x 1024` 이미지 준비
2. `pubspec.yaml`에 이미지 경로 지정
3. 아래 명령어 실행

```bash
dart run flutter_launcher_icons
```

## 예시

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
```

---

# Flutter Splash 설정

## Splash 적용 방법

1. `1024 x 1024` 이미지 준비
2. `pubspec.yaml`에 Splash 이미지 경로 지정
3. 아래 명령어 실행

```bash
dart run flutter_native_splash:create
```

## 예시

```yaml
flutter_native_splash:
  color: "#ffffff"
  image: assets/splash/logo.png
```

---

# Firebase 설정

## 1. Firebase 프로젝트 생성

1. Firebase Console 프로젝트 생성
2. Authentication 활성화
3. Cloud Firestore 생성

---

## 2. Authentication 설정

### 반드시 활성화해야 하는 항목

* Anonymous Authentication (익명 로그인)

경로:

```text
Firebase Console
→ Authentication
→ Sign-in method
→ Anonymous ON
```

---

## 3. Firestore Rules 적용

```text
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() {
      return request.auth != null;
    }

    function isVerifiedAdminByUid() {
      return signedIn()
        && exists(/databases/$(database)/documents/adminUsers/$(request.auth.uid))
        && get(/databases/$(database)/documents/adminUsers/$(request.auth.uid)).data.active == true
        && get(/databases/$(database)/documents/adminUsers/$(request.auth.uid)).data.verified == true;
    }

    function isVerifiedAdminByEmail() {
      return signedIn()
        && request.auth.token.email != null
        && exists(/databases/$(database)/documents/adminUsers/$(request.auth.token.email))
        && get(/databases/$(database)/documents/adminUsers/$(request.auth.token.email)).data.active == true
        && get(/databases/$(database)/documents/adminUsers/$(request.auth.token.email)).data.verified == true;
    }

    function isAdmin() {
      return isVerifiedAdminByUid() || isVerifiedAdminByEmail();
    }

    match /adminUsers/{userId} {
      allow read: if signedIn()
        && (
          request.auth.uid == userId ||
          request.auth.token.email == userId ||
          isAdmin()
        );

      allow write: if false;
    }

    match /hospitals/{document=**} {
      allow read: if signedIn();
      allow write: if isAdmin();
    }

    match /pharmacies/{document=**} {
      allow read: if signedIn();
      allow write: if isAdmin();
    }

    match /medicines/{document=**} {
      allow read: if signedIn();
      allow write: if isAdmin();
    }

    match /medicineFoodInfo/{document=**} {
      allow read: if signedIn();
      allow write: if isAdmin();
    }

    match /patients/{patientId} {
      allow read: if signedIn();
      allow write: if isAdmin();

      match /medSchedules/{scheduleId} {
        allow read, write: if signedIn();
      }

      match /rewardDays/{rewardDayId} {
        allow read, write: if signedIn();
      }
    }

    match /patients/{patientId}/{document=**} {
      allow read: if signedIn();
      allow write: if isAdmin();
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

파일 내용을 Firestore Rules 탭에 적용합니다.

---

# Firestore 데이터 구조

## Collections

```text
hospitals/{hospitalId}

patients/{patientId}

patients/{patientId}/medSchedules/{scheduleId}
```

---

# 웹(Web Portal) 설정

## Firebase Web App 등록

### 1. Firebase Console 접속

```text
프로젝트 설정
→ 내 앱
→ 웹 앱(</>) 추가
```

### 2. Firebase 설정값 복사

`web-portal/hospital.html`

```js
const firebaseConfig = {
  apiKey: "AIzaSyB3n9cTNNBa2hFTVRddtMU9pG-Tha7n_u0",
  authDomain: "test2-814d1.firebaseapp.com",
  projectId: "test2-814d1",
  storageBucket: "test2-814d1.firebasestorage.app",
  messagingSenderId: "510762522149",
  appId: "1:510762522149:web:12c8b9d20e7c2d1c7c51cc",
};
```
---
'Realtime Database URL'
```
https://test2-814d1-default-rtdb.asia-southeast1.firebasedatabase.app/
```
---

# 로컬 서버 실행

ES Module 사용으로 인해 `file://` 실행 대신 로컬 서버 사용 권장

## Windows

```bash
python -m http.server 8080
```

## macOS / Linux

```bash
python3 -m http.server 8080
```

## 접속 주소

```text
http://localhost:8080/web-portal/
```

---

# 웹 기본 사용 흐름

## 1. 병원 정보 저장

* 병원 정보 입력
* `병원 저장` 클릭
* `hospitalId` 생성

---

## 2. 환자 정보 저장

* 환자 정보 입력
* 병원 ID 입력
* `환자 저장` 클릭

---

## 3. 복약 정보 저장

Firestore 또는 Flutter 앱에서:

```text
patients/{patientId}/medSchedules
```

에 데이터 저장

---

## 4. 복약 시간 조회

웹 페이지에서:

* 환자 ID 입력
* 복약 시간 조회

---

# Flutter 앱 기능

## 홈 화면

* 상단 캘린더
* 복약 일정 점 표시
* 2x2 메뉴 UI

## 기능 메뉴

* 환자 조회
* 복약 등록
* 알림 관리
* 복약 통계
* 식품 관리

---

# 설정 페이지 기능

## 로그인 검증

사용자 정보:

* 환자 이름
* 생년월일

검증 완료 후:

* 알림 등록 사용 가능
* 통계 기능 사용 가능

---

# 식품 관리 기능

Firebase에 저장된 약 정보를 기반으로:

* 좋은 음식 자동 조회
* 나쁜 음식 자동 조회

예시:

```text
약: 혈압약

좋은 음식:
- 바나나
- 토마토

나쁜 음식:
- 자몽
- 고염분 음식
```

---

# Handmade Device 연동 확장

ESP8266 / ESP32 등을 이용하여:

* Firebase에서 알림 시간 조회
* LCD/Buzzer 제어
* 복약 알림 장치 제작 가능

예시 기능:

* 정해진 시간 LCD 점등
* 스피커 음성 알림
* 버튼 입력 후 Firebase 기록 저장

---

# Flutter Firebase 설정

## 1. 의존성 초기화

```bash
flutter clean
```

## 2. 패키지 설치

```bash
flutter pub get
```

## 3. Firebase 연결

```bash
flutterfire configure
```

## 4. 앱 실행

```bash
flutter run
```

---

# Android Firebase 필수 점검 사항

## 1. 패키지명 일치 확인

예시:

```gradle
applicationId "com.example.patient_med_sync_app"
```

Firebase Console 등록값과 동일해야 함

---

## 2. google-services.json 위치 확인

```text
flutter_app/android/app/google-services.json
```

---

## 3. Google Services Plugin 적용

### android/build.gradle 또는 settings.gradle

Google Services 설정 필요

### android/app/build.gradle

```gradle
apply plugin: 'com.google.gms.google-services'
```

---

## 4. Anonymous Authentication 활성화

반드시 ON 상태 유지

---

## 5. flutterfire configure 위치 확인

반드시:

```text
flutter_app/
```

폴더 내부에서 실행

---

## 6. 앱 재설치

```bash
flutter clean
flutter pub get
flutter run
```

실행 전 기존 앱 삭제 권장

---

# 자주 발생하는 오류

## auth/api-key-not-valid

### 원인

* 잘못된 Firebase Web API Key

### 해결

Firebase Console 설정값 다시 복사

---

## Missing or insufficient permissions

### 원인

* Authentication 비활성화
* Firestore Rules 미적용

### 해결

* Anonymous 로그인 활성화
* Rules 적용 확인

---

## CONFIGURATION_NOT_FOUND

### 원인

* 패키지명 불일치
* google-services.json 누락

### 해결

* Firebase Android 앱 재등록
* `flutterfire configure` 재실행

---

## Failed to fetch / CORS

### 원인

* `file://` 실행

### 해결

* 반드시 로컬 서버 사용

---

# 보안 관련 참고 사항

실서비스에서는 아래 기능 추가 권장:

* 사용자 역할(Role) 관리
* 병원-사용자 권한 매핑
* 개인정보 암호화
* 감사 로그(Audit Log)
* 접근 권한 분리
* 데이터 백업

---

# 사용 기술 스택

## Frontend

* Flutter
* Dart
* HTML/CSS/JavaScript

## Backend / Cloud

* Firebase
* Firestore
* Firebase Authentication

## Hardware

* ESP8266
* ESP32
* DFPlayer Mini
* LED / Buzzer Module

---

# 프로젝트 목적

본 프로젝트는:

* 고령자 복약 관리
* 병원-환자 데이터 동기화
* Firebase 기반 실시간 시스템
* Flutter 모바일 앱 개발
* IoT 복약 알림 장치 구현

을 목표로 하는 Capstone 프로젝트의 기능 검증 및 프로토타입 개발 예제입니다.
