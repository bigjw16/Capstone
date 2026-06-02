# Capstone Project Development Guide

## Smart Medication Management System

이 문서는 Capstone 프로젝트를 처음 사용하는 사용자가
Windows 환경에서 Flutter + Firebase + Web + IoT 시스템을 **설치 → 설정 → 실행**까지 수행할 수 있도록 정리한 가이드입니다.

---

# 0. 전체 개발 환경 구조

본 프로젝트는 다음 구성으로 이루어져 있습니다.

* Flutter (Mobile App)
* Firebase (Backend)
* Web (HTML + JS Dashboard)
* IoT (ESP8266)

---

# 1. 필수 프로그램 설치

## 1.1 Chocolatey 설치 (패키지 관리자)

PowerShell (관리자 실행)

다운로드 경로: https://chocolatey.org/install
다운로드 경로내 다운로드 방법을 사용하여 chocolatey 설치

설치 확인:

```bash id="ch2"
choco -v
```

---

## 1.2 Flutter SDK 설치

```bash id="fl1"
choco install flutter
```

설치 확인:

```bash id="fl2"
flutter --version
```

---

## 1.3 환경 변수 설정

Flutter 경로 추가:

```text id="env1"
C:\tools\flutter\bin
```

설정 후 확인:

```bash id="env2"
flutter doctor
```

---

## 1.4 Android Studio 설치

[Android Studio Download](https://developer.android.com/studio?utm_source=chatgpt.com)

### 설치 필수 항목

* Android SDK
* Android SDK Platform Tools
* Android Emulator

---

## 1.5 VS Code 설치

[VS Code Download](https://code.visualstudio.com)

### 필수 Extension

* Flutter
* Dart

---

# 2. Flutter 환경 검증

설치 완료 후 필수 확인:

```bash id="check1"
flutter doctor
```

정상 예:

```text id="check2"
[✓] Flutter
[✓] Android toolchain
[✓] Chrome
[✗] iOS toolchain (Windows에서는 정상)
```

---

# 3. Android Emulator 설정

## 3.1 AVD 생성

Android Studio → Device Manager

* Pixel 4 / Pixel 6 추천
* Android 13 이상 선택

---

## 3.2 Emulator 실행

```bash id="emu1"
flutter devices
```

---

## 3.3 실제 기기 연결 방법

### Andriod
* 개발자 옵션 활성화: 설정 → 휴대폰 정보 → 소프트웨어 정보 → 빌드 번호 7번 연속 클릭 (개발자 모드가 활성화되었습니다)
* 설정 → 개발자 옵션 → USB 디버깅 ON
* 데이터 전송 가능한 USB 케이블로 PC 연결 → 휴대폰 팝업 확인(이 컴퓨터를 신뢰하시겠습니까?, 허용/항상허용 선택)
* 터미널에서 명령어 실행
```
flutter devices
```
* 정상 출력 예( 1 connected device: Samsung Galaxy S23 (mobile))
* 앱실행
```
flutter run
```
* 문제 해결
  * 기기가 안뜨는 경우(USB 모드 변경 → "파일 전송(MTP), 드라이버 설치 (Samsung USB Driver))
---

### iOS
1. iOS 실행을 위한 필수 조건 (Mac 필요)
  iOS 실행을 위해 반드시 다음이 필요합니다.
  
  macOS (MacBook / iMac / Mac mini)
  Xcode 설치
  Apple ID
  Flutter SDK (Mac에도 설치 필요)
  iPhone 또는 iOS Simulator

2. Mac에서 Flutter iOS 환경 구성
  3.1 Flutter 설치 확인

  flutter doctor

  정상 상태:
  [✓] Flutter
  [✓] Xcode
  [✓] iOS toolchain

  3.2 Xcode 설치

  App Store에서 설치:
  
  Xcode Download
  
  설치 후 필수 실행:
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -runFirstLaunch

  3.3 CocoaPods 설치
  sudo gem install cocoapods

  확인: 
  pod --version

4. iPhone 실제 기기 연결
  4.1 iPhone 설정

  경로:
  설정 → 개인정보 보호 및 보안 → 개발자 모드 → ON
  
  또는:
  설정 → 일반 → VPN 및 기기 관리 → 신뢰 설정

  4.2 USB 연결
  iPhone을 Mac에 USB 연결
  “이 컴퓨터를 신뢰하시겠습니까?” → 신뢰 선택

  4.3 Flutter에서 기기 확인
  flutter devices
  
  예시:
  1 connected device:
  iPhone 15 Pro (mobile)
  4.4 실행
  flutter run
---

# 4. GitHub 프로젝트 다운로드

## 4.1 Clone

```bash id="gh1"
git clone https://github.com/bigjw16/Capstone.git
```

---

## 4.2 이동

```bash id="gh2"
cd Capstone
```

---

# 5. Flutter 프로젝트 실행

## 5.1 패키지 및 리소스 리셋
```bash id="run1"
flutter clean
```

## 5.2 패키지 설치

```bash id="run2"
flutter pub get
```

---

## 5.3 실행

```bash id="run3"
flutter run
```

---

# 6. Web 페이지 실행

## 6.1 실행 위치 이동

```bash id="web1"
cd index.html이 있는 폴더
```

---

## 6.2 Local Server 실행

터미널 열기 사용하여 window powershell 실행
```bash id="web2"
python -m http.server 8080
```

---

## 6.3 접속

인터넷 주소창에 해당 주소 입력후 접속
```text id="web3"
http://localhost:8080/
```

---

## 6.4 직접 실행 (간단 방식)

* index.html 더블 클릭 실행 가능
* Firebase 일부 기능 제한 가능

---

# 11. 전체 시스템 구조

```text id="sys1"
GitHub
  │
  ▼
Windows (VS Code)
  │
  ├──────────────┐
  ▼              ▼
Flutter App     Web Page
  │              │
  ▼              ▼
     Firebase Database
          │
          ▼
       IoT Device
```

---

# 12. 실행 순서 (중요)

1. Flutter 설치 확인 (`flutter doctor`)
2. Android Studio + Emulator 설정
3. GitHub clone
4. flutter pub get
5. flutter run
6. Web server 실행
7. Firebase 연결 확인

---

# 13. 문제 해결

## Flutter 안될 때

```bash id="err1"
flutter doctor
```

## Emulator 없음

→ Android Studio AVD 생성

# Capstone Note

본 문서는 Capstone 프로젝트 전체 시스템을 Windows 환경에서 처음 설치하는 사용자가
별도 도움 없이 실행할 수 있도록 구성된 통합 개발 환경 가이드입니다.
