# 복약 알림 앱 (Flutter)

Flutter + Android Studio 기반 복약 알림 예제입니다.

## 1) 사전 준비
1. **Flutter SDK 설치**
   - https://docs.flutter.dev/get-started/install
2. **Android Studio 설치**
   - 설치 시 Android SDK / Android SDK Platform-Tools 포함
3. **Android Studio 플러그인 설치**
   - `Settings > Plugins`에서 `Flutter`, `Dart` 설치
4. **환경 점검**
   ```bash
   flutter doctor
   ```
   - Android toolchain, connected device 항목이 모두 OK인지 확인

---

## 2) 프로젝트 열기 (Android Studio)
1. Android Studio 실행
2. **Open** 클릭 후 현재 프로젝트 폴더 선택
3. 하단 Terminal에서 아래 명령 실행
   ```bash
   flutter pub get
   ```
4. IDE 우상단 Device 선택에서 에뮬레이터/실기기 선택

---

## 3) 에뮬레이터 또는 실기기 준비

### A. 에뮬레이터
1. `Tools > Device Manager`
2. `Create device`로 Android 12+ 이미지 권장 생성
3. 생성한 가상기기 실행

### B. 실기기
1. 휴대폰에서 **개발자 옵션 + USB 디버깅** 활성화
2. USB 연결 후 권한 허용
3. 아래 명령으로 인식 확인
   ```bash
   flutter devices
   ```

---

## 4) 앱 실행
터미널에서:
```bash
flutter run
```

> 여러 기기가 연결되어 있으면 `flutter run -d <device_id>` 사용

---

## 5) 복약 알림 기능 확인 방법
1. 앱 실행 후 첫 화면 하단 영역(화면 절반~하단)에 있는 2x2 형태의 4개 위젯 확인
2. 맨 위 위젯 **알림 등록** 탭 (뒤로 돌아와도 등록 목록 유지)
3. 약 이름 입력
4. **시간 선택** 버튼 클릭 후 시/분 숫자 스크롤 리스트로 시간 선택
5. 시/분 입력칸을 터치하면 키보드로 직접 시간 수정 가능
6. **등록** 버튼 클릭
7. 리스트에 항목이 추가되면 예약 완료
8. 등록된 알림 항목을 터치하면 이름/시간 수정 가능
9. 백그라운드/앱 종료 상태에서도 알림 표시 없이 바로 AlarmRingPage로 전환
10. 앱을 사용 중일 때도 알림 없이 바로 알람 화면으로 전환
11. 화면에 복약해야 하는 약 이름 표시 + "복약 완료 (알림 종료)" 버튼으로 종료
12. 1분 안에 종료 버튼 미클릭 시 3분 뒤 재알림
13. 복약 완료 시 종료 시간이 복약 기록 화면에 저장

---

## 6) Android 알림 권한/정확한 알람 설정
Android 13 이상에서는 알림 권한을 허용해야 합니다.

- 앱 첫 실행 시 알림 권한 요청이 나오면 **허용**
- 기기에 따라 배터리 최적화가 알림을 지연시킬 수 있으므로 필요 시 예외 처리
- 정확한 알람 권한이 필요한 기기에서는 앱 설정에서 허용 필요 가능

---

## 7) 자주 발생하는 문제

### `flutter: command not found`
- Flutter SDK PATH 설정이 안 된 상태
- 설치 가이드의 PATH 설정 후 터미널 재실행

### 기기 인식 안 됨
- `flutter doctor`로 Android toolchain 문제 확인
- USB 케이블/드라이버/디버깅 허용 여부 재확인

### 알림이 안 옴
- 앱 알림 권한이 차단되어 있는지 확인
- 절전 모드/배터리 최적화로 백그라운드 제한되는지 확인
- 선택 시간이 현재 시각보다 이전이면 다음 날 같은 시간에 울림

### `Build failed due to use of deleted Android v1 embedding`
- Android 설정이 v1 임베딩 형태로 인식될 때 발생
- 이 프로젝트는 `MainActivity : FlutterActivity()` + `AndroidManifest.xml`의 `flutterEmbedding=2`로 v2 임베딩을 사용하도록 수정됨
- Android Studio에서 `flutter clean` 후 `flutter pub get`, `flutter run` 순서로 재실행

---

복약 기록/통계/설정 위젯도 각각 개별 화면으로 이동합니다.


## 8) 실제 휴대폰에서 알림이 안 울릴 때 (소리/진동/백그라운드)
1. 앱 알림 채널(복약 알림)에서 **소리/진동 허용** 확인
2. 앱 정보 > 배터리에서 **백그라운드 제한 해제** 또는 **배터리 최적화 제외**
3. 앱 알림 권한 + 정확한 알람 권한 허용
4. 전체화면 알림 권한(풀스크린 인텐트) 허용
5. 앱을 최근 앱에서 닫아도 스케줄은 동작하지만, 일부 제조사(샤오미/화웨이 등)는 자동 시작 허용이 필요
6. 첫 화면 상단 영상 자동재생은 네트워크 연결이 필요

## 핵심 파일
- `lib/main.dart`: 앱 시작/시스템 UI 설정/DI 초기화
- `lib/app.dart`: MaterialApp, 라우트 구성
- `lib/pages/*`: 화면(Home/Reminder/Alarm/History) 분리
- `lib/services/notification_service.dart`: 알림 예약/권한/페이로드 처리
- `lib/models/*`, `lib/widgets/*`: 데이터 모델/재사용 위젯
- `android/app/src/main/AndroidManifest.xml`: 알림/정확한 알람/부팅 리시버 설정
- `pubspec.yaml`: 패키지 의존성


## 9) 알람 동작 정책
- 알람 시 잠금화면에서도 화면을 켜고(가능한 경우) 바로 알람 화면으로 전환되도록 설정했습니다.
- 복약 시간이 되면 자동으로 앱 화면을 깨우고 알람이 울리도록 구성했습니다.
- 앱 상태(백그라운드/실행 중)와 관계없이 알람이 울리도록 전체화면 알림 + 소리/진동을 사용합니다.
- 앱 사용 중에는 내비게이션 바를 항상 표시합니다.
- 알람 화면 진입 시 1분 동안 소리 + 진동이 계속 울립니다.
- 1분 내 종료하지 않으면 3분 후 재알림이 울립니다.
- 종료 버튼을 누르면 즉시 알람이 멈추고 복약 기록이 저장됩니다.
