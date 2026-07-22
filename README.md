# Web Dashboard

> **Biomedical Engineering Capstone Design Project**

Firebase 기반 스마트 복약 관리 시스템의 병원·환자 통합 관리 웹 페이지입니다.

의료진 및 관리자 계정을 대상으로 개발되었으며, 환자 관리부터 복약 일정 등록, 약 정보 관리, 음식-약물 상호작용 관리, 복약 기록 조회까지 하나의 웹 환경에서 수행할 수 있습니다.

---

# 📖 프로젝트 소개

Web Dashboard는 **Smart Medication Management System**의 관리자용 웹 페이지입니다.

Firebase Cloud Firestore와 Realtime Database를 기반으로 병원, 약국, 환자, 약 정보 및 복약 데이터를 통합 관리하며, Flutter 모바일 애플리케이션 및 IoT 복약 관리 장치와 실시간으로 연동됩니다.

---

# ✨ 주요 기능

## 🏥 병원 및 약국 관리

- 병원 정보 등록 및 관리
- 약국 정보 등록 및 관리
- 병원-환자 정보 연동

---

## 👤 환자 관리

- 환자 등록 및 수정
- 보호자 정보 관리
- 환자별 복약 일정 관리

---

## 💊 약 정보 관리

- 약 정보 등록
- 약 성분 관리
- 음식-약물 상호작용 정보 관리
- 자동완성 검색

---

## 📅 복약 일정 관리

- 복약 시간 등록
- 식전 / 식후 / 공복 설정
- 반복 복약 설정
- 요일별 복약 설정

---

## 📊 복약 기록 조회

- Firebase Realtime Database 조회
- 환자별 복약 이력 확인
- IoT 장치 복약 기록 확인

---

# 🏗️ 시스템 구성

```text
            Flutter Mobile App
                    │
                    ▼
      Firebase Authentication
 Cloud Firestore / Realtime Database
        │                     │
        ▼                     ▼
 Web Dashboard          ESP8266 IoT Device
```

---

# 🛠️ 기술 스택

| Category | Technology |
|----------|------------|
| Frontend | HTML5, CSS3, JavaScript (ES6) |
| Backend | Firebase Authentication, Cloud Firestore, Realtime Database |
| Development | Visual Studio Code |
| Deployment | Firebase Hosting (Planned) |

---

# 📂 프로젝트 구조

```text
webpage/
│
├── hospital.html
├── css/
├── js/
├── assets/
│
└── README.md
```

---

# 🚀 시작하기

## 개발 환경

- Visual Studio Code
- Firebase Project
- Python 3.x (Local Server)

### 로컬 서버 실행

```bash
python -m http.server 8080
```

브라우저 접속

```
http://localhost:8080
```

---

# 🗄️ Firebase 데이터 구조

## Cloud Firestore

```text
patients
patients/{patientId}/medSchedules

hospitals

pharmacies

medicines

medicineFoodInfo

adminUsers
```

## Realtime Database

```text
patients/{patientId}/medLogs
```

---

# 🔄 데이터 흐름

## 병원 및 환자 등록

```text
Web Dashboard
      │
      ▼
Cloud Firestore
```

## 복약 일정 등록

```text
Web Dashboard
      │
      ▼
Cloud Firestore
```

## 복약 기록 조회

```text
Realtime Database
      │
      ▼
Web Dashboard
```

---

# 🚀 향후 개발 계획

- 실시간 복약 모니터링 대시보드
- 복약 통계 시각화
- 보호자 관리 기능
- 병원별 환자 통계
- 관리자 권한 관리
- Firebase Hosting 배포
- AI 기반 복약 순응도 분석

---

# 📜 License

This project was developed as a Biomedical Engineering Capstone Design Project for educational purposes.
![Arduino](https://img.shields.io/badge/Arduino-00979D?style=for-the-badge&logo=Arduino&logoColor=white)
![ESP8266](https://img.shields.io/badge/ESP8266-E7352C?style=for-the-badge)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
