#include <ESP8266WiFi.h>
#include <WiFiUdp.h>
#include <NTPClient.h>
#include <Firebase_ESP_Client.h>

// ======================
// WiFi 설정
// ======================
#define WIFI_SSID "HANBYEOL"
#define WIFI_PASSWORD "19911102"

// ======================
// Firebase 설정
// ======================
#define API_KEY "AIzaSyB3n9cTNNBa2hFTVRddtMU9pG-Tha7n_u0"

#define DATABASE_URL "https://test2-814d1-default-rtdb.asia-southeast1.firebasedatabase.app/"

// Firebase 객체
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// NTP 객체
WiFiUDP ntpUDP;

// 한국 시간 UTC+9
NTPClient timeClient(
  ntpUDP,
  "pool.ntp.org",
  9 * 3600,
  60000
);

void setup() {

  Serial.begin(115200);
  Serial.println();

  // WiFi 연결
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("WiFi 연결 중");

  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(500);
  }

  Serial.println();
  Serial.println("WiFi 연결 성공");

  Serial.print("IP : ");
  Serial.println(WiFi.localIP());

  // Firebase 설정
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;

  // 익명 로그인
  if (Firebase.signUp(&config, &auth, "", "")) {

    Serial.println("Firebase 익명 로그인 성공");

  } else {

    Serial.println("Firebase 로그인 실패");
    Serial.println(config.signer.signupError.message.c_str());
  }

  Firebase.begin(&config, &auth);

  Firebase.reconnectWiFi(true);

  fbdo.setBSSLBufferSize(4096, 1024);

  Serial.print("Firebase 준비 중");

  while (!Firebase.ready()) {
    Serial.print(".");
    delay(500);
  }

  Serial.println();
  Serial.println("Firebase 연결 성공");

  // 시간 시작
  timeClient.begin();

  Serial.println();
  Serial.println("'a' 입력 시 복약 기록 저장");
}

void loop() {

  timeClient.update();

  if (Serial.available()) {

    char cmd = Serial.read();

    if (cmd == 'a') {

      time_t rawTime = timeClient.getEpochTime();

      struct tm* ptm = localtime(&rawTime);

      char formattedTime[25];

      sprintf(
        formattedTime,
        "%04d-%02d-%02d %02d:%02d:%02d",
        ptm->tm_year + 1900,
        ptm->tm_mon + 1,
        ptm->tm_mday,
        ptm->tm_hour,
        ptm->tm_min,
        ptm->tm_sec
      );

      Serial.print("저장할 시간 : ");
      Serial.println(formattedTime);

      String path = "/patients/patient001/medLogs";

      if (Firebase.RTDB.pushString(
            &fbdo,
            path,
            formattedTime)) {

        Serial.println("복약 기록 저장 성공");

      } else {

        Serial.println("복약 기록 저장 실패");
        Serial.println(fbdo.errorReason());
      }
    }
  }
}