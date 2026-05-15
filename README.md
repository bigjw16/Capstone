# Patient Medication Sync System (Web + Firebase + Flutter + Handmade Device)

이 저장소는 다음 요구사항을 만족하는 최소 구현 예시를 제공합니다.

- 웹에서 병원/환자 정보 입력 후 Firebase 저장
- 웹에서 환자 복약 시간 조회
- 웹에서 저장한 환자 목록을 Flutter에서 실시간으로 선택/조회
- 웹에서 약 정보 입력 후 Firebase 저장
- 웹에서 약과 함께 복용시 좋은/나쁜 음식 정보 입력 후 Firebase 저장
- Flutter 앱에서 환자/병원 정보 자동 조회
- Flutter 환자 조회 시 hospitalId가 문서 ID든 병원명이든 병원 정보 fallback 조회
- Flutter 앱에서 복약 시간 입력 후 Firebase 저장
- Flutter 홈 대시보드(상단 캘린더 + 하단 2x2 메뉴)에서 기능 페이지 이동
- ---캘린더에 복약 알림 날짜 점 표시---
- 홈 우측 상단 설정 아이콘에서 설정 페이지 진입 후 환자 이름+생년월일로 로그인 검증
- 설정 로그인 후에만 알림등록/복약통계 등 메뉴 사용 가능
- 알림등록 페이지를 2등분(상단: 알림 저장+스크롤 시간 선택 / 하단: 저장된 알림 확인)으로 구성
- 식품관리 페이지에서 알림에 등록된 약과 함께 복용시 좋은/나쁜 음식 정보 자동 조회

## 구조

- `web-portal/`: 병원/환자 입력 및 복약시간 조회용 웹 페이지 (Firebase Web SDK)
- `flutter_app/`: 환자/병원/복약 정보 조회 및 복약시간 등록 앱 (Flutter + Firebase)
- `firebase/firestore.rules`: Firestore 보안 규칙 예시

## 데이터 모델

- `hospitals/{hospitalId}`
- `patients/{patientId}` (현재 예제에서는 patientId를 환자명과 동일하게 사용)
- `patients/{patientId}/medSchedules/{scheduleId}`

## 빠른 시작

### 1) Firebase 프로젝트 생성

1. Firebase Console에서 프로젝트 생성
2. Authentication 활성화
   - 최소 **익명 로그인(Anonymous)** 을 켜주세요. (웹 예제에서 자동 로그인 사용)
   - 필요 시 이메일/비밀번호도 추가로 활성화
3. Cloud Firestore 생성

### 2) Firestore Rules 적용

`firebase/firestore.rules` 내용을 Rules 탭에 반영합니다.

### 3) 웹 앱 설정 (자세히)

#### 3-1. Firebase Web 앱 등록 및 설정값 복사

1. Firebase Console > **프로젝트 설정** > **내 앱**에서 **웹 앱(`</>`)** 추가
2. 앱 등록 후 표시되는 설정 객체(`apiKey`, `authDomain`, `projectId` 등) 복사
3. `web-portal/index.html`의 `firebaseConfig`를 실제 값으로 교체

```js
const firebaseConfig = {
  apiKey: 'AIzaSyB3n9cTNNBa2hFTVRddtMU9pG-Tha7n_u0',
  authDomain: 'test2-814d1.firebaseapp.com',
  projectId: 'test2-814d1',
  storageBucket: 'test2-814d1.firebasestorage.app',
  messagingSenderId: '510762522149',
  appId: '1:510762522149:web:12c8b9d20e7c2d1c7c51cc',
};
```

> `projectId`가 Firestore 프로젝트와 정확히 일치해야 데이터가 정상 저장/조회됩니다.

#### 3-2. Firestore 데이터베이스/규칙 확인

1. Firestore Database가 생성되어 있는지 확인
2. `firebase/firestore.rules`가 배포(또는 콘솔 반영)되어 있는지 확인
3. 테스트 시에는 최소 1개의 사용자로 로그인 가능한 상태를 준비

> 현재 예제 규칙은 `request.auth != null` 조건이므로, 인증 없이 접근하면 저장/조회가 거부됩니다.

#### 3-3. 로컬 서버 실행

브라우저에서 ES Module(`type="module"`)을 사용하므로 **파일 직접 열기(file://)** 대신 로컬 서버를 사용해야 합니다.
**파일 직접 열기 동작함**

- macOS / Linux

```bash
python3 -m http.server 8080
```

- Windows (PowerShell / CMD)

```bash
python -m http.server 8080
```

실행 후 브라우저에서 아래 주소 접속:

```text
http://localhost:8080/web-portal/
```

#### 3-4. 기본 동작 확인 순서

1. **병원 정보 입력** 후 `병원 저장` 클릭
   - 화면에 `hospitalId`가 출력됨
2. 출력된 `hospitalId`를 복사해 **환자 정보 입력**의 병원 ID에 붙여넣기
3. `환자 저장` 클릭 후 `patientId(=환자명)` 확인
4. (Flutter 또는 Firestore 콘솔에서) `patients/{patientId}/medSchedules`에 복약정보 추가
5. 웹의 `환자 복약시간 조회`에서 해당 `patientId`로 조회

#### 3-5. 자주 발생하는 오류

- `Firebase: Error (auth/api-key-not-valid.-please-pass-a-valid-api-key.)`
  - `web-portal/index.html`의 `firebaseConfig.apiKey`가 실제 Web 앱 키인지 확인
  - Firebase Console > 프로젝트 설정 > 일반 > 내 앱(Web)에서 설정 객체를 다시 복사
  - `YOUR_API_KEY` 같은 placeholder가 남아 있으면 인증이 실패함

- **`Missing or insufficient permissions`**
  - 인증 미적용 또는 Rules 조건 미충족
  - Authentication > Sign-in method에서 Anonymous가 꺼져 있으면 저장 실패
- **`Failed to fetch` / CORS 관련 오류**
  - `file://`로 열었거나 잘못된 실행 환경
- **데이터가 안 보임**
  - 다른 Firebase 프로젝트 설정값을 사용했는지 확인

### 4) Flutter 앱 설정

1. 'flutter clean'로 flutter 의존성 초기화
2. `flutter_app/pubspec.yaml` 의존성 설치 (`flutter pub get`)
3. `flutterfire configure`로 Firebase 연결 파일 생성
4. Firebase Console > Authentication > Sign-in method에서 **Anonymous** 활성화
5. 앱 실행 (`flutter run`)

> Flutter도 Firestore Rules(`request.auth != null`)를 만족해야 하므로, 예제 앱은 익명 로그인 후 조회/저장을 수행합니다.

## 참고

실서비스에서는 사용자 역할(role), 병원-사용자 매핑, 개인정보 비식별화/암호화, 감사 로그를 추가하세요.


### Flutter에서 저장/조회가 안 될 때

- `firebase_options.dart`가 생성되지 않았거나 앱에 연결되지 않으면 초기화 실패 가능
- Authentication에서 Anonymous가 꺼져 있으면 `permission-denied` 발생
- Firestore Rules가 배포되지 않았으면 접근이 거부될 수 있음

- `FirebaseAuthException ([firebase_auth/unknown] ... CONFIGURATION_NOT_FOUND)`
  - Authentication > Sign-in method에서 Anonymous 활성화
  - `flutterfire configure` 재실행 후 앱 재빌드
  - Firebase 프로젝트/앱 등록(패키지명, 번들ID)이 현재 앱과 일치하는지 확인

### Android에서 여전히 안 될 때 (필수 점검)

아래 6가지를 모두 만족해야 Android에서 FirebaseAuth/Firestore가 정상 동작합니다.

1. **패키지명 일치**
   - Firebase Console에 등록한 Android 앱의 패키지명과 실제 앱 패키지명이 동일해야 함
   - 예: `applicationId "com.example.patient_med_sync_app"`

2. **`google-services.json` 위치 확인**
   - 파일 경로: `flutter_app/android/app/google-services.json`

3. **Gradle 플러그인 적용 확인**
   - `flutter_app/android/build.gradle` 또는 `settings.gradle`에 Google Services 플러그인 설정
   - `flutter_app/android/app/build.gradle`에 `com.google.gms.google-services` 적용

4. **Anonymous 로그인 활성화**
   - Firebase Console > Authentication > Sign-in method > Anonymous ON

5. **`flutterfire configure`를 `flutter_app` 폴더에서 실행**
   - 잘못된 폴더에서 실행하면 다른 프로젝트 설정이 생성될 수 있음

6. **앱 완전 재설치**
   - 기존 설치 앱 삭제 후 `flutter clean` → `flutter pub get` → `flutter run`

Android에서 `CONFIGURATION_NOT_FOUND`가 지속되면, 대부분 1번(패키지명 불일치) 또는 2번(`google-services.json` 누락/오위치)입니다.
