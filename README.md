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
2. 맨 위 위젯 **알림 등록** 탭
3. 약 이름 입력
4. **시간 선택** 버튼으로 알림 시간 선택
5. **등록** 버튼 클릭
6. 리스트에 항목이 추가되면 예약 완료
7. 선택한 시간에 알림이 오는지 확인

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

## 핵심 파일
- `lib/main.dart`: 화면/상태관리/알림 예약 로직
- `android/app/src/main/AndroidManifest.xml`: 알림/정확한 알람/부팅 리시버 설정
- `pubspec.yaml`: 패키지 의존성
