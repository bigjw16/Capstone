#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecureBearSSL.h>
#include <ArduinoJson.h>
#include <SoftwareSerial.h>
#include <time.h>
#include <DFRobotDFPlayerMini.h>

// ==========================
// ==========================
// Wi-Fi settings
// ==========================
#define WIFI_SSID "GalaxyS25Edge"
#define WIFI_PASSWORD "wkdwnsdn12!"

// ==========================
// Firebase settings
// - Keep these values private in real deployments.
// - FIREBASE_RTDB_URL example: https://your-project-default-rtdb.firebaseio.com
// ==========================
#define FIREBASE_PROJECT_ID "test2-814d1"
#define FIREBASE_WEB_API_KEY "AIzaSyB3n9cTNNBa2hFTVRddtMU9pG-Tha7n_u0"
#define FIREBASE_RTDB_URL "https://test2-814d1-default-rtdb.asia-southeast1.firebasedatabase.app/"

#define FIREBASE_USER_EMAIL "admin@example.com"
#define FIREBASE_USER_PASSWORD "admin1234"

// ==========================
// Patient and device settings
// Firestore path: /patients/{patientId}/medSchedules
// RTDB path: /medicationResponses/{patientId}/{autoPushId}
// ==========================
String patientId = "무한";

// Optional physical confirmation button.
// NodeMCU D3 is GPIO0. INPUT_PULLUP means pressed == LOW.
#define CONFIRM_BUTTON_PIN D3
#define USE_CONFIRM_BUTTON true

// Arduino Mega TFT bridge.
// ESP8266 USB Serial keeps Firebase debug logs on the Serial Monitor.
// A dedicated SoftwareSerial link sends only Mega protocol lines:
//   ESP8266 MEGA_TX_PIN -> Mega RX1(19) : ALERT|HH:MM|1|medicineName
//   Mega TX1(18) -> ESP8266 MEGA_RX_PIN through a 3.3V level shifter : TAKEN|...
#define USE_MEGA_DISPLAY_BRIDGE true
#define MEGA_RX_PIN D6
#define MEGA_TX_PIN D5
#define MEGA_SERIAL_BAUD 9600

// Poll only when the minute changes to avoid 60 Firestore reads per minute.
#define SCHEDULE_POLL_INTERVAL_MS 1000UL
#define ALERT_RESPONSE_TIMEOUT_MS 300000UL
#define KST_OFFSET_SECONDS (9 * 3600)

String idToken = "";
unsigned long tokenExpiresAtMillis = 0;
String lastCheckedMinute = "";
String lastTriggeredKey = "";

struct LocalDateTimeParts {
  int year;
  int month;
  int day;
  int hour;
  int minute;
  int second;
  int weekday; // 0=Sunday, 1=Monday, ... 6=Saturday
  bool valid;
};

struct PendingMedicationAlert {
  bool active;
  String scheduleId;
  String medicineName;
  String scheduledDate;
  String scheduledTime;
  unsigned long alertedAtMillis;
};

PendingMedicationAlert pendingAlert = {false, "", "", "", "", 0};
unsigned long lastPollMillis = 0;
SoftwareSerial megaSerial(MEGA_RX_PIN, MEGA_TX_PIN);

#define DF_RX_PIN D1
#define DF_TX_PIN D2

SoftwareSerial dfSerial(DF_RX_PIN, DF_TX_PIN);
DFRobotDFPlayerMini dfPlayer;

bool dfPlayerReady = false;

// ==========================
// Formatting helpers
// ==========================
String twoDigits(int value) {
  return value < 10 ? "0" + String(value) : String(value);
}

String formatDate(const tm& timeinfo) {
  return String(timeinfo.tm_year + 1900) + "-" +
         twoDigits(timeinfo.tm_mon + 1) + "-" +
         twoDigits(timeinfo.tm_mday);
}

String formatClockTime(const tm& timeinfo) {
  return twoDigits(timeinfo.tm_hour) + ":" + twoDigits(timeinfo.tm_min);
}

String formatTimestamp(const tm& timeinfo) {
  return formatDate(timeinfo) + " " +
         twoDigits(timeinfo.tm_hour) + ":" +
         twoDigits(timeinfo.tm_min) + ":" +
         twoDigits(timeinfo.tm_sec);
}

String formatDateParts(const LocalDateTimeParts& parts) {
  if (!parts.valid) return "";
  return String(parts.year) + "-" + twoDigits(parts.month) + "-" + twoDigits(parts.day);
}

String normalizeTime(String value) {
  value.trim();
  value.replace("-", ":");

  if (value.length() >= 5) {
    return value.substring(0, 5);
  }

  return value;
}

String jsonEscape(String value) {
  String escaped = "";
  for (size_t i = 0; i < value.length(); i++) {
    char c = value[i];
    if (c == '"' || c == '\\') {
      escaped += '\\';
      escaped += c;
    } else if (c == '\n') {
      escaped += "\\n";
    } else if (c == '\r') {
      escaped += "\\r";
    } else if (c == '\t') {
      escaped += "\\t";
    } else {
      escaped += c;
    }
  }
  return escaped;
}

String urlEncode(const String& value) {
  const char* hex = "0123456789ABCDEF";
  String encoded = "";

  for (size_t i = 0; i < value.length(); i++) {
    uint8_t c = static_cast<uint8_t>(value[i]);
    bool unreserved = (c >= 'A' && c <= 'Z') ||
                      (c >= 'a' && c <= 'z') ||
                      (c >= '0' && c <= '9') ||
                      c == '-' || c == '_' || c == '.' || c == '~';

    if (unreserved) {
      encoded += static_cast<char>(c);
    } else {
      encoded += '%';
      encoded += hex[(c >> 4) & 0x0F];
      encoded += hex[c & 0x0F];
    }
  }

  return encoded;
}

// ==========================
// Time conversion helpers
// ==========================
long daysFromCivil(int year, unsigned month, unsigned day) {
  year -= month <= 2;
  const long era = (year >= 0 ? year : year - 399) / 400;
  const unsigned yoe = static_cast<unsigned>(year - era * 400);
  const unsigned doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1;
  const unsigned doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
  return era * 146097L + static_cast<long>(doe) - 719468L;
}

time_t epochFromUtcParts(int year, int month, int day, int hour, int minute, int second) {
  return static_cast<time_t>(daysFromCivil(year, month, day) * 86400L +
                             hour * 3600L + minute * 60L + second);
}

bool parseFirestoreTimestampToLocalParts(String timestampValue, LocalDateTimeParts& parts) {
  parts.valid = false;

  if (timestampValue.length() < 19) {
    return false;
  }

  int year = timestampValue.substring(0, 4).toInt();
  int month = timestampValue.substring(5, 7).toInt();
  int day = timestampValue.substring(8, 10).toInt();
  int hour = timestampValue.substring(11, 13).toInt();
  int minute = timestampValue.substring(14, 16).toInt();
  int second = timestampValue.substring(17, 19).toInt();

  if (year < 2020 || month < 1 || month > 12 || day < 1 || day > 31) {
    return false;
  }

  time_t localEpoch = epochFromUtcParts(year, month, day, hour, minute, second) + KST_OFFSET_SECONDS;
  tm localTm;
  gmtime_r(&localEpoch, &localTm);

  parts.year = localTm.tm_year + 1900;
  parts.month = localTm.tm_mon + 1;
  parts.day = localTm.tm_mday;
  parts.hour = localTm.tm_hour;
  parts.minute = localTm.tm_min;
  parts.second = localTm.tm_sec;
  parts.weekday = localTm.tm_wday;
  parts.valid = true;

  return true;
}

int dateKey(const String& yyyyMmDd) {
  if (yyyyMmDd.length() < 10) return 0;
  return yyyyMmDd.substring(0, 4).toInt() * 10000 +
         yyyyMmDd.substring(5, 7).toInt() * 100 +
         yyyyMmDd.substring(8, 10).toInt();
}

// ==========================
// Firestore field readers
// ==========================
String fieldString(JsonObject fields, const char* fieldName) {
  JsonVariant field = fields[fieldName];

  if (field.isNull()) return "";

  if (!field["stringValue"].isNull()) {
    return field["stringValue"].as<String>();
  }

  if (!field["timestampValue"].isNull()) {
    return field["timestampValue"].as<String>();
  }

  if (!field["integerValue"].isNull()) {
    return field["integerValue"].as<String>();
  }

  if (!field["booleanValue"].isNull()) {
    return field["booleanValue"].as<bool>() ? "true" : "false";
  }

  return "";
}

bool fieldBool(JsonObject fields, const char* fieldName) {
  JsonVariant field = fields[fieldName];
  if (field.isNull() || field["booleanValue"].isNull()) {
    return false;
  }
  return field["booleanValue"].as<bool>();
}

String documentIdFromName(String documentName) {
  int slashIndex = documentName.lastIndexOf('/');

  if (slashIndex < 0) {
    return documentName;
  }

  return documentName.substring(slashIndex + 1);
}

bool firestoreIntegerArrayContains(JsonObject fields, const char* fieldName, int target) {
  JsonArray values = fields[fieldName]["arrayValue"]["values"].as<JsonArray>();
  if (values.isNull()) return false;

  for (JsonObject value : values) {
    if (!value["integerValue"].isNull() && value["integerValue"].as<int>() == target) {
      return true;
    }
  }

  return false;
}

bool firestoreTimesContainsCurrentMinute(JsonObject fields, const String& currentMinute) {
  JsonArray values = fields["times"]["arrayValue"]["values"].as<JsonArray>();

  if (!values.isNull()) {
    for (JsonObject value : values) {
      String scheduleTime = normalizeTime(value["stringValue"].as<String>());
      if (scheduleTime == currentMinute) {
        return true;
      }
    }
  }

  String alarmTime = normalizeTime(fieldString(fields, "alarmTime"));
  String legacyTime = normalizeTime(fieldString(fields, "time"));

  return alarmTime == currentMinute || legacyTime == currentMinute;
}

bool scheduleAppliesToday(JsonObject fields, const tm& currentTm, const String& todayDate) {
  int todayKey = dateKey(todayDate);
  int todayWeekday = currentTm.tm_wday;

  LocalDateTimeParts alarmAtParts;
  parseFirestoreTimestampToLocalParts(fieldString(fields, "alarmAt"), alarmAtParts);
  String alarmAtDate = formatDateParts(alarmAtParts);

  LocalDateTimeParts repeatUntilParts;
  parseFirestoreTimestampToLocalParts(fieldString(fields, "repeatUntilAt"), repeatUntilParts);
  String repeatUntilDate = formatDateParts(repeatUntilParts);

  bool repeatDaily = fieldBool(fields, "repeatDaily");
  bool repeatByWeekday = firestoreIntegerArrayContains(fields, "repeatWeekdays", todayWeekday);

  if (repeatDaily || repeatByWeekday) {
    if (alarmAtDate != "" && todayKey < dateKey(alarmAtDate)) {
      return false;
    }
    if (repeatUntilDate != "" && todayKey > dateKey(repeatUntilDate)) {
      return false;
    }
    return true;
  }

  String alarmDate = fieldString(fields, "alarmDate");
  if (alarmDate != "") {
    return alarmDate.substring(0, 10) == todayDate;
  }

  if (alarmAtDate != "") {
    return alarmAtDate == todayDate;
  }

  // Legacy schedules without a date are treated as daily schedules.
  return true;
}

// ==========================
// Wi-Fi and NTP
// ==========================
void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("WiFi 연결 중");

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.println("WiFi 연결 성공");
  Serial.print("IP 주소: ");
  Serial.println(WiFi.localIP());
}

bool readCurrentTime(tm& timeinfo) {
  unsigned long startMillis = millis();

  while (millis() - startMillis < 5000) {
    time_t now = time(nullptr);

    if (now > 1700000000) {
      localtime_r(&now, &timeinfo);
      return true;
    }

    delay(100);
  }

  return false;
}

void setupTime() {
  configTime(KST_OFFSET_SECONDS, 0, "pool.ntp.org", "time.nist.gov");

  tm timeinfo;

  Serial.print("NTP 시간 동기화 중");

  while (!readCurrentTime(timeinfo)) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.print("현재 시간: ");
  Serial.println(formatTimestamp(timeinfo));
}

// ==========================
// Firebase Auth
// ==========================
bool ensureFirebaseIdToken() {
  if (idToken != "" && millis() < tokenExpiresAtMillis) {
    return true;
  }

  BearSSL::WiFiClientSecure client;
  client.setInsecure();

  HTTPClient https;

  String url = String("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=") +
               FIREBASE_WEB_API_KEY;

  if (!https.begin(client, url)) {
    Serial.println("Firebase Auth 연결 실패");
    return false;
  }

  https.addHeader("Content-Type", "application/json");

  String body = String("{\"email\":\"") + jsonEscape(FIREBASE_USER_EMAIL) +
                "\",\"password\":\"" + jsonEscape(FIREBASE_USER_PASSWORD) +
                "\",\"returnSecureToken\":true}";

  int httpCode = https.POST(body);
  String response = https.getString();

  https.end();

  if (httpCode != 200) {
    Serial.print("Firebase Auth 실패: ");
    Serial.println(httpCode);
    Serial.println(response);
    return false;
  }

  DynamicJsonDocument doc(4096);
  DeserializationError error = deserializeJson(doc, response);

  if (error) {
    Serial.print("Auth JSON 파싱 실패: ");
    Serial.println(error.c_str());
    return false;
  }

  idToken = doc["idToken"].as<String>();
  int expiresInSeconds = doc["expiresIn"].as<int>();
  tokenExpiresAtMillis = millis() + ((unsigned long)expiresInSeconds - 60) * 1000UL;

  Serial.println("Firebase Auth 로그인 성공");

  return true;
}

// ==========================
// Firestore schedule lookup
// ==========================
bool fetchMedSchedulesPage(String pageToken, String& response) {
  if (!ensureFirebaseIdToken()) {
    return false;
  }

  BearSSL::WiFiClientSecure client;
  client.setInsecure();

  HTTPClient https;

  String url = String("https://firestore.googleapis.com/v1/projects/") +
               FIREBASE_PROJECT_ID +
               "/databases/(default)/documents/patients/" +
               urlEncode(patientId) +
               "/medSchedules"
               "?pageSize=100"
               "&mask.fieldPaths=medicineName"
               "&mask.fieldPaths=times"
               "&mask.fieldPaths=alarmAt"
               "&mask.fieldPaths=alarmDate"
               "&mask.fieldPaths=alarmTime"
               "&mask.fieldPaths=time"
               "&mask.fieldPaths=repeatDaily"
               "&mask.fieldPaths=repeatWeekdays"
               "&mask.fieldPaths=repeatUntilAt";

  if (pageToken != "") {
    url += "&pageToken=" + urlEncode(pageToken);
  }

  if (!https.begin(client, url)) {
    Serial.println("Firestore 연결 실패");
    return false;
  }

  https.addHeader("Authorization", "Bearer " + idToken);

  int httpCode = https.GET();
  response = https.getString();

  https.end();

  if (httpCode != 200) {
    Serial.print("Firestore 조회 실패: ");
    Serial.println(httpCode);
    Serial.println(response);
    return false;
  }

  return true;
}

String megaProtocolField(String value) {
  value.trim();
  value.replace("|", " ");
  value.replace("\r", " ");
  value.replace("\n", " ");

  if (value == "") {
    return "MED";
  }

  return value;
}


void playMedicationMp3() {
  if (!dfPlayerReady) {
    Serial.println("DFPlayer 준비 안 됨");
    return;
  }

  Serial.println("DFPlayer 0001.mp3 재생 시도");

  // ESP8266 SoftwareSerial은 동시에 하나만 안정적으로 listen 가능하다.
  // DFPlayer 명령 전송 전 DFPlayer serial로 전환한다.
  dfSerial.listen();
  delay(80);

  dfPlayer.volume(25);
  delay(50);
  dfPlayer.play(1);  // /mp3/0001.mp3 또는 0001.mp3 재생
  delay(250);

  // 복약 완료 응답(TAKEN|...)을 다시 받을 수 있도록 Mega serial로 복귀한다.
  megaSerial.listen();
  delay(20);
}

void sendAlertCommandToMega(const String& medicineName, const String& scheduledTime) {
  String command = "ALERT|" + scheduledTime + "|1|" + megaProtocolField(medicineName);

  if (USE_MEGA_DISPLAY_BRIDGE) {
    // Mega로 ALERT 명령 전송
    megaSerial.listen();
    delay(50);
    megaSerial.println(command);
    megaSerial.flush();

    Serial.print("Mega 전송: ");
    Serial.println(command);
  }

  // LCD 알림 전송과 별개로 MP3 알림 재생
  playMedicationMp3();
}

void printMedicationAlert(const String& scheduleId, const String& medicineName,
                          const String& scheduledDate, const String& scheduledTime) {
  Serial.println();
  Serial.println("====== 복약 알림 ======");
  Serial.print("날짜: ");
  Serial.println(scheduledDate);
  Serial.print("시간: ");
  Serial.println(scheduledTime);
  Serial.print("약 이름: ");
  Serial.println(medicineName);
  Serial.print("문서 ID: ");
  Serial.println(scheduleId);
  Serial.println("Mega 화면으로 ALERT 명령을 전송합니다.");
  Serial.println("복약 완료는 Mega가 TAKEN 명령을 보내거나, 시리얼 모니터에 y 입력/ESP 버튼으로 저장합니다.");
  Serial.println("======================");

  sendAlertCommandToMega(medicineName, scheduledTime);
}

void armPendingAlert(const String& scheduleId, const String& medicineName,
                     const String& scheduledDate, const String& scheduledTime) {
  pendingAlert.active = true;
  pendingAlert.scheduleId = scheduleId;
  pendingAlert.medicineName = medicineName;
  pendingAlert.scheduledDate = scheduledDate;
  pendingAlert.scheduledTime = scheduledTime;
  pendingAlert.alertedAtMillis = millis();
}

void checkSchedulesAndPrintMatchedOne() {
  if (pendingAlert.active) {
    Serial.println("이전 복약 알림의 확인 응답을 기다리는 중입니다.");
    return;
  }

  tm timeinfo;

  if (!readCurrentTime(timeinfo)) {
    Serial.println("현재 시간 읽기 실패");
    return;
  }

  String todayDate = formatDate(timeinfo);
  String currentMinute = formatClockTime(timeinfo);

  Serial.println();
  Serial.print("현재 날짜: ");
  Serial.println(todayDate);
  Serial.print("현재 시간: ");
  Serial.println(currentMinute);

  bool matched = false;
  String pageToken = "";

  do {
    String response;

    if (!fetchMedSchedulesPage(pageToken, response)) {
      Serial.println("Firestore 일정 조회 실패");
      return;
    }

    DynamicJsonDocument doc(16384);
    DeserializationError error = deserializeJson(doc, response);

    if (error) {
      Serial.print("Firestore JSON 파싱 실패: ");
      Serial.println(error.c_str());
      Serial.println("받은 응답:");
      Serial.println(response);
      return;
    }

    JsonArray documents = doc["documents"].as<JsonArray>();

    if (!documents.isNull()) {
      for (JsonObject document : documents) {
        String documentName = document["name"].as<String>();
        String scheduleId = documentIdFromName(documentName);
        JsonObject fields = document["fields"].as<JsonObject>();

        if (fields.isNull()) {
          continue;
        }

        if (!scheduleAppliesToday(fields, timeinfo, todayDate)) {
          continue;
        }

        if (!firestoreTimesContainsCurrentMinute(fields, currentMinute)) {
          continue;
        }

        String triggerKey = todayDate + "_" + scheduleId + "_" + currentMinute;
        if (lastTriggeredKey == triggerKey) {
          matched = true;
          continue;
        }

        String medicineName = fieldString(fields, "medicineName");
        if (medicineName == "") medicineName = "이름 없는 약";

        lastTriggeredKey = triggerKey;
        matched = true;

        printMedicationAlert(scheduleId, medicineName, todayDate, currentMinute);
        armPendingAlert(scheduleId, medicineName, todayDate, currentMinute);
        return;
      }
    }

    JsonVariant nextPageTokenField = doc["nextPageToken"];
    if (nextPageTokenField.isNull()) {
      pageToken = "";
    } else {
      pageToken = nextPageTokenField.as<String>();
    }
  } while (pageToken != "");

  if (!matched) {
    Serial.println("현재 날짜/시간과 일치하는 복약 문서 없음");
  }
}

// ==========================
// RTDB medication response save
// ==========================
bool saveMedicationResponseToRtdb(const String& responseType) {
  if (!pendingAlert.active) {
    return false;
  }

  if (!ensureFirebaseIdToken()) {
    Serial.println("RTDB 저장 전 Firebase Auth 실패");
    return false;
  }

  tm timeinfo;
  if (!readCurrentTime(timeinfo)) {
    Serial.println("복약 응답 시간 읽기 실패");
    return false;
  }

  time_t nowEpoch = time(nullptr);
  String takenAt = formatTimestamp(timeinfo);

  BearSSL::WiFiClientSecure client;
  client.setInsecure();

  HTTPClient https;

  String url = String(FIREBASE_RTDB_URL) +
               "/medicationResponses/" +
               urlEncode(patientId) +
               ".json?auth=" +
               urlEncode(idToken);

  if (!https.begin(client, url)) {
    Serial.println("RTDB 연결 실패");
    return false;
  }

  https.addHeader("Content-Type", "application/json");

  DynamicJsonDocument bodyDoc(1024);
  bodyDoc["patientId"] = patientId;
  bodyDoc["scheduleId"] = pendingAlert.scheduleId;
  bodyDoc["medicineName"] = pendingAlert.medicineName;
  bodyDoc["scheduledDate"] = pendingAlert.scheduledDate;
  bodyDoc["scheduledTime"] = pendingAlert.scheduledTime;
  bodyDoc["takenAt"] = takenAt;
  bodyDoc["takenAtEpoch"] = static_cast<long>(nowEpoch);
  bodyDoc["source"] = "esp8266";
  bodyDoc["responseType"] = responseType;

  String body;
  serializeJson(bodyDoc, body);

  int httpCode = https.POST(body);
  String response = https.getString();

  https.end();

  if (httpCode != 200 && httpCode != 201) {
    Serial.print("RTDB 복약 응답 저장 실패: ");
    Serial.println(httpCode);
    Serial.println(response);
    return false;
  }

  Serial.println();
  Serial.println("====== 복약 응답 저장 완료 ======");
  Serial.print("약 이름: ");
  Serial.println(pendingAlert.medicineName);
  Serial.print("예정 날짜/시간: ");
  Serial.print(pendingAlert.scheduledDate);
  Serial.print(" ");
  Serial.println(pendingAlert.scheduledTime);
  Serial.print("응답 시간: ");
  Serial.println(takenAt);
  Serial.print("RTDB 응답: ");
  Serial.println(response);
  Serial.println("================================");

  pendingAlert.active = false;
  return true;
}

bool handleMegaDisplayCommand(String input) {
  input.trim();
  if (input == "") {
    return true;
  }

  if (input.startsWith("TAKEN|")) {
    Serial.print("Mega 복약 완료 응답 수신: ");
    Serial.println(input);
    saveMedicationResponseToRtdb("mega_display");
    return true;
  }

  if (input == "ALL_DONE") {
    Serial.println("Mega 전체 복용 완료 응답 수신");
    pendingAlert.active = false;
    return true;
  }

  if (input == "GUARDIAN_ALERT") {
    Serial.println("Mega 보호자 알림 상태 수신");
    return true;
  }

  return false;
}

void handleMegaSerialInput() {
  if (!USE_MEGA_DISPLAY_BRIDGE || megaSerial.available() <= 0) {
    return;
  }

  String input = megaSerial.readStringUntil('\n');
  input.trim();
  if (input != "") {
    Serial.print("Mega 수신: ");
    Serial.println(input);
  }
  handleMegaDisplayCommand(input);
}

void handleUsbSerialInput() {
  if (Serial.available() <= 0) {
    return;
  }

  String input = Serial.readStringUntil('\n');
  input.trim();

  String lowerInput = input;
  lowerInput.toLowerCase();
  if (pendingAlert.active &&
      (lowerInput == "y" || lowerInput == "yes" || lowerInput == "ok" || input == "완료")) {
    saveMedicationResponseToRtdb("serial");
    return;
  }

  if (pendingAlert.active && input != "") {
    Serial.println("복약 완료 저장은 Mega의 TAKEN 응답 또는 y, yes, ok, 완료 중 하나를 사용하세요.");
  }
}

void handleMedicationConfirmation() {
  handleMegaSerialInput();
  handleUsbSerialInput();

  if (!pendingAlert.active) {
    return;
  }

  if (millis() - pendingAlert.alertedAtMillis > ALERT_RESPONSE_TIMEOUT_MS) {
    Serial.println("복약 확인 응답 대기 시간이 만료되었습니다.");
    pendingAlert.active = false;
    return;
  }

  if (USE_CONFIRM_BUTTON && digitalRead(CONFIRM_BUTTON_PIN) == LOW) {
    delay(30);
    if (digitalRead(CONFIRM_BUTTON_PIN) == LOW) {
      saveMedicationResponseToRtdb("button");
      while (digitalRead(CONFIRM_BUTTON_PIN) == LOW) {
        delay(10);
      }
    }
  }
}

// ==========================
// setup / loop
// ==========================
void setup() {
  Serial.begin(115200);
  Serial.setTimeout(1000);
  delay(500);

  if (USE_MEGA_DISPLAY_BRIDGE) {
    megaSerial.begin(MEGA_SERIAL_BAUD);
  }

  dfSerial.begin(9600);
delay(1000);

dfSerial.listen();
delay(300);

Serial.println("DFPlayer 초기화 중");

if (!dfPlayer.begin(dfSerial, false, false)) {
  Serial.println("DFPlayer 연결 실패");
  dfPlayerReady = false;
} else {
  Serial.println("DFPlayer 연결 성공");
  dfPlayer.volume(25);
  delay(300);
  dfPlayerReady = true;
}

delay(500);
megaSerial.listen();

  // 기본 대기 상태는 Mega 응답 수신(TAKEN|...)이다.
  if (USE_MEGA_DISPLAY_BRIDGE) {
    megaSerial.listen();
  }

  delay(1000);

  if (USE_CONFIRM_BUTTON) {
    pinMode(CONFIRM_BUTTON_PIN, INPUT_PULLUP);
  }

  connectWiFi();
  setupTime();

  Serial.println("Firebase 준비 완료");
}

void loop() {
  handleMedicationConfirmation();

  unsigned long nowMillis = millis();
  if (nowMillis - lastPollMillis < SCHEDULE_POLL_INTERVAL_MS) {
    delay(20);
    return;
  }
  lastPollMillis = nowMillis;

  tm timeinfo;
  if (!readCurrentTime(timeinfo)) {
    Serial.println("현재 시간 읽기 실패");
    delay(1000);
    return;
  }

  String currentMinute = formatDate(timeinfo) + " " + formatClockTime(timeinfo);
  if (currentMinute != lastCheckedMinute) {
    lastCheckedMinute = currentMinute;
    checkSchedulesAndPrintMatchedOne();
  }

  delay(20);
}
