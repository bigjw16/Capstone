# Changelog

이 프로젝트의 모든 주요 변경 사항은 이 파일에 기록됩니다.

버전은 Semantic Versioning을 따릅니다:
- MAJOR: 큰 구조 변경
- MINOR: 기능 추가
- PATCH: 기능 수정

---

## [Unreleased]
- 진행 중인 변경 사항

---

## [v1.0.1] - 2026-05-21

### Added
- 복약 알림 구조 개선 (식사/복약 조건 포함: 아침·점심·저녁, 식전/식후/공복)
- 음식 정보 시스템 위험도 기반 확장 (안전/주의/매우 위험 + 사유 표시)
- Root Gate 기반 자동 로그인 및 세션 유지 기능 추가

---

## [v1.0.2] - 20262-05-28

### Added
- ESP8266(NodeMCU) ↔ Firebase Realtime Database 연동 추가
- 복약 버튼 입력 시 복약 시간 자동 기록 기능 추가
- 웹페이지 복약 기록 조회 기능 추가
- Flutter 앱 알림 조회 및 시간 수정 기능 추가
- Firebase 기반 복약 관리 구조 개선

### Changed
- 복약 알림 구조를 식사 시간/복약 조건 기반 구조로 개선
- 음식 정보 시스템을 위험도 기반 구조로 확장
- Flutter 앱 알림 삭제 기능 제거

---

## [v1.0.3] - 2026-06-01

### Added
- 관리자 로그인 기능 추가
  - Firebase Authentication 이메일/비밀번호 로그인 적용
  - Firestore `adminUsers` 기반 관리자 인증 구현
  - 승인된 관리자만 웹페이지 접근 가능

- Firestore 보안 규칙 추가
  - `firestore.rules` 파일 생성
  - 관리자 권한 검증 로직 구현
  - 주요 컬렉션 접근 제어 적용

- 환자 ID 매핑 기능 추가
  - Firestore 환자 ID ↔ RTDB 환자 ID 연결 기능 구현
  - 환자 문서에 `rtdbPatientId` 필드 추가

- ESP8266 약 이름 매핑 기능 추가
  - ESP8266용 영문 약 이름 필드 추가
  - RTDB ↔ Firestore 약 정보 연동 구조 개선

- 자동완성 기능 추가
  - 환자명 / 약 이름 / 성분명 자동완성
  - 음식 정보 등록 시 성분 검색 기능 추가

---

### Changed
- 복약 기록 조회 로직 개선
  - Firestore 환자 ID → RTDB 환자 ID 변환 후 조회

- 복약 일정 등록 로직 개선
  - 약 선택 시 해당 약 성분 자동 반영

- 약 정보 저장 구조 개선
  - 성분명 + ESP8266 영문 이름 함께 저장

- 음식 정보 등록 방식 개선
  - 성분 검색 기반 위험도 등록 방식으로 변경

---

### Security
- Firestore 접근 권한 강화
  - `adminUsers.active == true`
  - `adminUsers.verified == true`

- 보호 컬렉션 접근 제한 적용
  - `hospitals`
  - `pharmacies`
  - `patients`
  - `medicines`
  - `medicineFoodInfo`

---

### Configuration
- Firebase 설정 업데이트
  - `firestore.rules` 추가
  - `firebase.json` Firestore Rules 배포 설정 추가
