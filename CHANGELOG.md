# CHANGELOG

## Version 1.0.1

* 복약 알림 구조를 시간 중심에서 식사/복약 조건 포함 구조로 개선 (아침·점심·저녁, 식전/식후/공복)
* 음식 정보 시스템을 위험도 기반(안전/주의/매우 위험)으로 확장하고 사유 표시 기능 추가
* 로그인 방식을 Root Gate 기반 자동 로그인으로 변경하여 세션 유지 및 UX 개선 (로그아웃 전까지 유지)

---

## Version 1.0.2

* ESP8266(NodeMCU) ↔ Firebase Realtime Database 연동 추가
* 복약 버튼 입력 시 복약 시간 자동 기록 기능 추가
* 웹페이지에서 복약 기록 조회 기능 추가
* 복약 알림 구조를 식사 시간 및 복약 조건 기반 구조로 개선
* 음식 정보 시스템을 위험도(안전/주의/매우 위험) 기반으로 확장
* Root Gate 기반 자동 로그인 적용 및 세션 유지 기능 추가
* Flutter 앱 알림 기능을 조회 및 시간 수정 전용으로 변경
* Flutter 앱 내 알림 삭제 기능 제거
* Firebase 데이터 연동 및 복약 관리 구조 개선

---

## Version 1.0.3

### Added

* 관리자 로그인 기능 추가

  * Firebase Authentication 이메일/비밀번호 로그인 적용
  * Firestore `adminUsers` 컬렉션 기반 관리자 인증 구현
  * 승인된 관리자만 웹페이지 접근 가능

* Firestore 보안 규칙 추가

  * `firestore.rules` 파일 생성
  * 관리자 권한 검증 로직 구현
  * 주요 데이터 컬렉션 접근 제어 적용

* 환자 ID 매핑 기능 추가

  * Firestore 환자 ID와 Realtime Database 환자 ID 연결 기능 구현
  * 환자 문서에 `rtdbPatientId` 필드 추가

* ESP8266 약 이름 매핑 기능 추가

  * 약 정보에 ESP8266용 영문 이름 필드 추가
  * RTDB 영문 약 이름과 Firestore 약 정보를 연동 가능하도록 개선

* 자동완성 기능 추가

  * 환자명 자동완성
  * 약 이름 자동완성
  * 성분명 자동완성
  * 음식 정보 등록 시 성분 검색 기능 추가

### Changed

* 복약 기록 조회 로직 개선

  * Firestore 환자 ID를 RTDB 환자 ID로 변환 후 복약 기록 조회하도록 수정

* 복약 일정 등록 기능 개선

  * 약 선택 시 해당 약의 성분만 자동완성되도록 변경

* 약 정보 관리 기능 개선

  * 약 정보 저장 시 성분명과 ESP8266 영문 이름 함께 저장

* 음식 정보 관리 기능 개선

  * 기존 성분 검색 후 선택하여 위험도 정보 등록 가능하도록 수정

### Security

* Firestore 접근 권한 강화

  * `adminUsers.active == true`
  * `adminUsers.verified == true`
  * 조건을 만족하는 관리자만 데이터 읽기/쓰기 가능

* 다음 컬렉션에 대한 접근 제한 적용

  * `hospitals`
  * `pharmacies`
  * `patients`
  * `medicines`
  * `medicineFoodInfo`

### Configuration

* Firebase 설정 파일 업데이트

  * `capstone2/firestore.rules` 파일 추가
  * `capstone2/firebase.json`에 Firestore Rules 배포 설정 추가
