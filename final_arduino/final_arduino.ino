// ============================================================
//  복약 알림 - 화면 테스트 (시리얼 입력 제어 + 속도 최적화)
//  보드   : Arduino Mega
//  LCD    : 2.8" TFT ILI9341 (MCUFRIEND shield) 240×320
//  SD CS  : 53번 핀
//  버튼1  : D22
//  버튼2  : D23
//
//  이번 수정 사항
//  1) 모든 복약 질문이 끝난 뒤 ST_SNOOZE/ST_GUARDIAN 상태에서는
//     BTN2 길게 누름이 "BTN2 되돌리기"로 처리되지 않도록 수정
//  2) 질문 종료 후 재알림 대기 상태에서 BTN2 길게 누르면
//     곧바로 남은 약의 ASK 화면으로 이동
//  3) 스누즈/보호자 상태 진입 직전에 btn2UndoPending을 clear하여
//     이전 질문의 undo 상태가 남아 있지 않도록 수정
//
//  시리얼 명령어 (115200 baud):
//    ALERT|09:30|1|DMED
//    ALERT|09:30|2|DMED|BPMED
//    ALERT|09:30|2|LIPID|DMED
//    ALERT|09:30|2|DMED|BPMED|식후 30분|아침 공복
//    CAUTION|식후 30분|아침 공복
//    RESET
//  약 키워드: DMED BPMED LIPID ANTIB ANTICO 또는 한글
// ============================================================

#include <Adafruit_GFX.h>
#include <MCUFRIEND_kbv.h>
#include <SPI.h>
#include <SD.h>

MCUFRIEND_kbv tft;

#define SD_CS     53
#define BTN1_PIN  22
#define BTN2_PIN  23

// ── BMP 출력 버퍼 ──
#define ROW_BUFFER_PX 240
uint16_t rowBuf[ROW_BUFFER_PX];
#define CHUNK 720
uint8_t chunkBuf[CHUNK];

// 전방 선언
extern unsigned long btn1DownMs;
extern bool btn1LongFired;

// BMP 그리는 중 버튼 타이머 업데이트
void pollBtn1Timer() {
  int cur1 = digitalRead(BTN1_PIN);
  unsigned long now = millis();
  if (cur1 == LOW) {
    if (btn1DownMs == 0) btn1DownMs = now;
  } else {
    btn1DownMs = 0;
    btn1LongFired = false;
  }
}

bool drawBMP(const char *filename, int x, int y) {
  File f = SD.open(filename);
  if (!f) { Serial.print(F("FAIL: ")); Serial.println(filename); return false; }
  uint16_t sig = (f.read()) | (f.read() << 8);
  if (sig != 0x4D42) { f.close(); return false; }
  for (int i = 0; i < 8; i++) f.read();
  uint32_t offset = 0;
  for (int i = 0; i < 4; i++) offset |= ((uint32_t)f.read() << (i * 8));
  for (int i = 0; i < 4; i++) f.read();
  int32_t w = 0, h = 0;
  for (int i = 0; i < 4; i++) w |= ((int32_t)f.read() << (i * 8));
  for (int i = 0; i < 4; i++) h |= ((int32_t)f.read() << (i * 8));
  if ((f.read() | (f.read() << 8)) != 1)  { f.close(); return false; }
  if ((f.read() | (f.read() << 8)) != 24) { f.close(); return false; }
  uint32_t compress = 0;
  for (int i = 0; i < 4; i++) compress |= ((uint32_t)f.read() << (i * 8));
  if (compress != 0) { f.close(); return false; }
  bool flip = (h > 0);
  if (h < 0) h = -h;
  uint32_t rowSize = ((w * 3) + 3) & ~3;
  int drawW = min((int)w, tft.width()  - x);
  int drawH = min((int)h, tft.height() - y);
  if (drawW <= 0 || drawH <= 0) { f.close(); return false; }
  tft.setAddrWindow(x, y, x + drawW - 1, y + drawH - 1);
  for (int32_t row = 0; row < drawH; row++) {
    uint32_t pos = flip ? offset + (uint32_t)(h - 1 - row) * rowSize
                        : offset + (uint32_t)row * rowSize;
    f.seek(pos);
    int remaining = drawW, col = 0;
    while (remaining > 0) {
      int pixelsToRead = min(remaining, CHUNK / 3);
      f.read(chunkBuf, pixelsToRead * 3);
      for (int i = 0; i < pixelsToRead; i++) {
        rowBuf[col++] = tft.color565(chunkBuf[i*3+2], chunkBuf[i*3+1], chunkBuf[i*3]);
      }
      remaining -= pixelsToRead;
    }
    tft.pushColors(rowBuf, drawW, row == 0);
    pollBtn1Timer();
  }
  f.close();
  return true;
}

// ── 색상 / 배경 ──
#define COL_BG tft.color565(210, 195, 105)
void fillBg(int y, int h) { tft.fillRect(0, y, 240, h, COL_BG); }

void drawTime(const char *t) {
  fillBg(130, 25);
  tft.setTextColor(0x0000); tft.setTextSize(3);
  int cx = (240 - (int)strlen(t) * 18) / 2;
  tft.setCursor(cx, 130); tft.print(t);
}

void addMinutes(const char *src, int addMin, char *dst) {
  int h = (src[0]-'0')*10 + (src[1]-'0');
  int m = (src[3]-'0')*10 + (src[4]-'0');
  m += addMin; h = (h + m/60) % 24; m = m % 60;
  dst[0]='0'+h/10; dst[1]='0'+h%10; dst[2]=':';
  dst[3]='0'+m/10; dst[4]='0'+m%10; dst[5]='\0';
}

// ── 한글 폰트 ──
#define HY_CHAR_W    24
#define HY_CHAR_H    30
#define HY_BYTES_ROW 3
#define HY_BYTES_CHAR 90
#define HY_START     0xAC00
#define HY_SPACE_W   8
#define HY_HEADER_SIZE 8

void drawHangulChar(uint16_t unicode, int x, int y, uint16_t fg, uint16_t bg) {
  if (unicode < HY_START || unicode > 0xD7A3) return;
  uint32_t idx    = unicode - HY_START;
  uint32_t offset = HY_HEADER_SIZE + idx * HY_BYTES_CHAR;
  File f = SD.open("HYFONT.FNT");
  if (!f) { Serial.println(F("HYFONT open fail")); return; }
  if (!f.seek(offset)) { f.close(); return; }
  uint8_t buf[HY_BYTES_ROW];
  for (int row = 0; row < HY_CHAR_H; row++) {
    f.read(buf, HY_BYTES_ROW);
    for (int col = 0; col < HY_CHAR_W; col++) {
      bool pixel = (buf[col/8] >> (7-(col%8))) & 1;
      int px = x+col, py = y+row;
      if (px>=0 && px<tft.width() && py>=0 && py<tft.height()) {
        tft.drawPixel(px, py, pixel ? fg : bg);
      }
    }
  }
  f.close();
}

void drawHangulString(const String &kw, int startX, int y, int areaW, uint16_t bg, int charW) {
  tft.fillRect(startX, y, areaW, HY_CHAR_H, bg);
  int totalW = 0, ci = 0;
  while (ci < (int)kw.length()) {
    uint8_t c = kw[ci];
    if (c < 0x80) { totalW += 12; ci++; }
    else if (c < 0xE0) { totalW += charW; ci += 2; }
    else { totalW += charW; ci += 3; }
  }
  int cx = startX + (areaW - totalW) / 2;
  if (cx < startX) cx = startX;

  File f;
  bool fontOpen = false;
  ci = 0;
  int drawX = cx;
  while (ci < (int)kw.length()) {
    uint8_t c = kw[ci];
    uint32_t u = 0;
    int advance = 0;

    if (c < 0x80) {
      if (fontOpen) { f.close(); fontOpen = false; }
      tft.setTextColor(0x0000); tft.setTextSize(2);
      tft.setCursor(drawX, y + 4);
      tft.print((char)c);
      drawX += 12;
      ci++;
      continue;
    } else if (c < 0xE0) {
      u = ((c & 0x1F) << 6) | (kw[ci+1] & 0x3F);
      advance = 2;
    } else {
      u = ((c & 0x0F) << 12) | ((kw[ci+1] & 0x3F) << 6) | (kw[ci+2] & 0x3F);
      advance = 3;
    }
    ci += advance;

    if (u >= HY_START && u <= 0xD7A3) {
      if (!fontOpen) { f = SD.open("HYFONT.FNT"); fontOpen = f ? true : false; }
      if (fontOpen) {
        uint32_t offset = HY_HEADER_SIZE + (u - HY_START) * HY_BYTES_CHAR;
        f.seek(offset);
        uint8_t buf[HY_BYTES_ROW];
        for (int row = 0; row < HY_CHAR_H; row++) {
          f.read(buf, HY_BYTES_ROW);
          for (int col = 0; col < HY_CHAR_W; col++) {
            bool pixel = (buf[col/8] >> (7-(col%8))) & 1;
            int px = drawX+col, py = y+row;
            if (px>=0 && px<tft.width() && py>=0 && py<tft.height()) {
              tft.drawPixel(px, py, pixel ? 0x0000 : bg);
            }
          }
        }
      }
    }
    drawX += charW;
  }
  if (fontOpen) f.close();
}

void drawHangulTextW(const String &text, int startX, int y, int areaW, uint16_t bg, int charW) {
  const int ASCII_W = 12;
  const int ASCII_Y = 4;

  int totalW = 0, i = 0;
  while (i < (int)text.length()) {
    uint8_t c = text[i];
    uint32_t u = 0;
    if (c < 0x80) { u = c; i++; }
    else if (c < 0xE0) { u = ((c&0x1F)<<6) | (text[i+1]&0x3F); i += 2; }
    else { u = ((c&0x0F)<<12) | ((text[i+1]&0x3F)<<6) | (text[i+2]&0x3F); i += 3; }

    if (u == 0x20) totalW += HY_SPACE_W;
    else if (u < 0x80) totalW += ASCII_W;
    else totalW += charW;
  }

  int cx = startX + (areaW - totalW) / 2;
  if (cx < startX) cx = startX;
  int cy = y;
  tft.fillRect(startX, y, areaW, 36, bg);

  i = 0;
  int drawX = cx;
  while (i < (int)text.length()) {
    uint32_t u = 0;
    uint8_t c = text[i];
    if (c < 0x80) { u = c; i++; }
    else if (c < 0xE0) { u = ((c&0x1F)<<6) | (text[i+1]&0x3F); i += 2; }
    else { u = ((c&0x0F)<<12) | ((text[i+1]&0x3F)<<6) | (text[i+2]&0x3F); i += 3; }

    if (u == 0x20) {
      tft.fillRect(drawX, cy, HY_SPACE_W, HY_CHAR_H, bg);
      drawX += HY_SPACE_W;
    } else if (u < 0x80) {
      tft.setTextColor(0x0000, bg);
      tft.setTextSize(2);
      tft.setCursor(drawX, cy + ASCII_Y);
      tft.print((char)u);
      drawX += ASCII_W;
    } else {
      drawHangulChar(u, drawX, cy, 0x0000, bg);
      drawX += charW;
    }
  }
}

void drawHangulTextLeft(const String &text, int startX, int y, int areaW, uint16_t bg, int charW) {
  tft.fillRect(startX, y, areaW, 36, bg);
  int i = 0;
  int drawX = startX;
  while (i < (int)text.length()) {
    uint32_t u = 0; uint8_t c = text[i];
    if (c < 0x80) { u=c; i++; }
    else if (c < 0xE0) { u=((c&0x1F)<<6)|(text[i+1]&0x3F); i+=2; }
    else { u=((c&0x0F)<<12)|((text[i+1]&0x3F)<<6)|(text[i+2]&0x3F); i+=3; }
    if (u==0x20) {
      tft.fillRect(drawX, y, HY_SPACE_W, HY_CHAR_H, bg);
      drawX += HY_SPACE_W;
    } else if (u < 0x80) {
      tft.setTextColor(0x0000, bg);
      tft.setTextSize(2);
      tft.setCursor(drawX, y + 4);
      tft.print((char)u);
      drawX += 12;
    } else {
      drawHangulChar(u, drawX, y, 0x0000, bg);
      drawX += charW;
    }
  }
}

void drawHangulText(const String &text, int startX, int y, int areaW, uint16_t bg) {
  drawHangulTextW(text, startX, y, areaW, bg, HY_CHAR_W);
}

void drawReAskBang(int x, int y, uint16_t fg, uint16_t bg) {
  tft.fillRect(x, y, 12, HY_CHAR_H, bg);
  tft.fillRoundRect(x + 4, y + 3, 3, 19, 1, fg);
  tft.fillRoundRect(x + 3, y + 25, 5, 4, 1, fg);
}

void drawReAskSecondLine(int y) {
  const int koreanW = 26;
  const int bangW = 12;
  const int totalW = koreanW * 5 + bangW;
  int x = (240 - totalW) / 2;
  if (x < 0) x = 0;

  tft.fillRect(0, y, 240, 38, COL_BG);
  int drawX = x;
  drawHangulChar(0xBB3C, drawX, y, 0x0000, COL_BG); drawX += koreanW;
  drawHangulChar(0xC5B4, drawX, y, 0x0000, COL_BG); drawX += koreanW;
  drawHangulChar(0xBCFC, drawX, y, 0x0000, COL_BG); drawX += koreanW;
  drawHangulChar(0xAC8C, drawX, y, 0x0000, COL_BG); drawX += koreanW;
  drawHangulChar(0xC694, drawX, y, 0x0000, COL_BG); drawX += koreanW;
  drawReAskBang(drawX, y, 0x0000, COL_BG);
}

void drawHangulCharScaledInCell(uint16_t unicode, int cellX, int y, uint16_t fg, uint16_t bg,
                                int cellW, int outW, int outH, int yOffset) {
  if (unicode < HY_START || unicode > 0xD7A3) return;
  tft.fillRect(cellX, y, cellW, HY_CHAR_H, bg);

  uint32_t idx    = unicode - HY_START;
  uint32_t offset = HY_HEADER_SIZE + idx * HY_BYTES_CHAR;
  File f = SD.open("HYFONT.FNT");
  if (!f) { Serial.println(F("HYFONT open fail")); return; }
  if (!f.seek(offset)) { f.close(); return; }

  uint8_t buf[HY_CHAR_H][HY_BYTES_ROW];
  for (int row = 0; row < HY_CHAR_H; row++) f.read(buf[row], HY_BYTES_ROW);
  f.close();

  int x0 = cellX + (cellW - outW) / 2;
  int y0 = y + yOffset;
  for (int dy = 0; dy < outH; dy++) {
    int srcRow = (long)dy * HY_CHAR_H / outH;
    for (int dx = 0; dx < outW; dx++) {
      int srcCol = (long)dx * HY_CHAR_W / outW;
      bool pixel = (buf[srcRow][srcCol/8] >> (7-(srcCol%8))) & 1;
      int px = x0 + dx;
      int py = y0 + dy;
      if (px>=0 && px<tft.width() && py>=0 && py<tft.height()) {
        tft.drawPixel(px, py, pixel ? fg : bg);
      }
    }
  }
}

void drawLipidStatusName(int x, int y) {
  tft.fillRect(x, y, 170, 36, COL_BG);
  int cellW = 24;
  int cx = x;
  drawHangulChar(0xACE0, cx, y, 0x0000, COL_BG); cx += cellW;
  drawHangulChar(0xC9C0, cx, y, 0x0000, COL_BG); cx += cellW;
  drawHangulChar(0xD608, cx, y, 0x0000, COL_BG); cx += cellW;
  drawHangulCharScaledInCell(0xC99D, cx, y, 0x0000, COL_BG, cellW, 22, 27, 2); cx += cellW;
  drawHangulChar(0xC57D, cx, y, 0x0000, COL_BG);
}

void drawHangulLine(const String &kw, int startX, int y, int areaW, int h, uint16_t bg, int charW) {
  tft.fillRect(startX, y, areaW, h, bg);
  int totalW = 0, ci = 0;
  while (ci < (int)kw.length()) {
    uint8_t c = kw[ci];
    if (c < 0x80) { totalW+=charW; ci++; }
    else if (c < 0xE0) { totalW+=charW; ci+=2; }
    else { totalW+=charW; ci+=3; }
  }
  int cx = startX + (areaW - totalW) / 2;
  ci = 0;
  while (ci < (int)kw.length()) {
    uint32_t u = 0; uint8_t c = kw[ci];
    if (c < 0x80) { u=c; ci++; }
    else if (c < 0xE0) { u=((c&0x1F)<<6)|(kw[ci+1]&0x3F); ci+=2; }
    else { u=((c&0x0F)<<12)|((kw[ci+1]&0x3F)<<6)|(kw[ci+2]&0x3F); ci+=3; }
    drawHangulChar(u, cx, y, 0x0000, bg);
    cx += charW;
  }
}

// ── 약 정보 ──
const int MAX_MEDS = 5;
String medKw[MAX_MEDS];
bool   medTaken[MAX_MEDS];
bool   isRetry = false;
String medTakenTime[MAX_MEDS];
int    medCount  = 0;
bool   hasLipid  = false;
char   currentTime[6] = "00:00";

String cautionText[MAX_MEDS];
bool   hasCaution = false;

void parseMeds(const String &cmd) {
  medCount = 0; hasLipid = false; hasCaution = false;
  for (int i=0;i<MAX_MEDS;i++) cautionText[i]="";

  int p1 = cmd.indexOf('|'), p2 = cmd.indexOf('|',p1+1), p3 = cmd.indexOf('|',p2+1);
  if (p2==-1||p3==-1) return;
  currentTime[0]=0;
  String t = cmd.substring(p1+1, p2); t.trim(); t.toCharArray(currentTime, sizeof(currentTime));
  medCount = cmd.substring(p2+1, p3).toInt();
  if (medCount > MAX_MEDS) medCount = MAX_MEDS;

  int start = p3+1;
  for (int i = 0; i < medCount; i++) {
    int sep = cmd.indexOf('|', start);
    medKw[i] = (sep==-1) ? cmd.substring(start) : cmd.substring(start, sep);
    medKw[i].trim();
    if (medKw[i]=="LIPID") hasLipid=true;
    start = (sep==-1) ? cmd.length() : sep+1;
  }

  for (int i = 0; i < medCount; i++) {
    if (start >= (int)cmd.length()) break;
    int sep = cmd.indexOf('|', start);
    cautionText[i] = (sep==-1) ? cmd.substring(start) : cmd.substring(start, sep);
    cautionText[i].trim();
    if (cautionText[i].length() > 0) hasCaution = true;
    start = (sep==-1) ? cmd.length() : sep+1;
  }

  Serial.print(F("시간: ")); Serial.println(currentTime);
  Serial.print(F("약 ")); Serial.print(medCount); Serial.println(F("개"));
  if (hasCaution) {
    for (int i=0;i<medCount;i++) {
      Serial.print(i); Serial.print(F(":")); Serial.println(cautionText[i]);
    }
  }
}

void drawMedBmp(const String &kw, const String &suffix, int x, int y) {
  String fname = kw + suffix + ".BMP";
  char buf[20]; fname.toCharArray(buf, sizeof(buf));
  if (SD.exists(buf)) { drawBMP(buf, x, y); }
  else { drawHangulText(kw, x, y, (suffix=="_H")?120:240, COL_BG); }
}

void drawMedArea() {
  fillBg(155, 60);
  if (medCount==1) { drawMedBmp(medKw[0],"",0,155); }
  else if (medCount==2) {
    if (hasLipid) { drawMedBmp(medKw[0],"_S",0,155); drawMedBmp(medKw[1],"_S",0,185); }
    else { drawMedBmp(medKw[0],"_H",0,155); drawMedBmp(medKw[1],"_H",120,155); }
  } else {
    for (int i=0; i<medCount && i<3; i++) drawMedBmp(medKw[i],"_S",0,155+i*20);
  }
}

void drawMedSingle(int idx, int y) { fillBg(y,60); drawMedBmp(medKw[idx],"",0,y); }

// ── 상태머신 변수 ──
enum State { ST_IDLE, ST_ALARM, ST_ASK, ST_SNOOZE, ST_NOTYET,
             ST_STATUS, ST_OK_CANCEL, ST_DUPLICATE, ST_GUARDIAN,
             ST_CAUTION };
State curState = ST_IDLE;

int           askIdx        = 0;
int           cancelMedIdx  = -1;
int           snoozeCount   = 0;
bool          snoozeIdled   = false;
unsigned long snoozeStartMs = 0;
unsigned long statusStartMs = 0;
unsigned long okCancelMs    = 0;
bool          statusFromSnooze = false;

bool          btn2UndoPending = false;
int           btn2UndoIdx = -1;
int           btn2UndoSnoozeCount = 0;
bool          btn2UndoIsRetry = false;
char          btn2UndoTime[6] = "00:00";

#define SNOOZE_DELAY    900000UL
#define STATUS_DURATION  60000UL
#define OK_CANCEL_DELAY   5000UL
#define SNOOZE_LIMIT         2

// ── 버튼 변수 ──
int  prevBtn1 = HIGH, prevBtn2 = HIGH;
bool btn1Edge = false, btn2Edge = false;
bool btn1ShortEdge = false;
bool btn2ShortEdge = false;
bool btn1LongEdge  = false;
bool btn2LongEdge  = false;
unsigned long btn1DownMs = 0;
unsigned long btn2DownMs = 0;
bool btn1LongFired = false;
bool btn2LongFired = false;
#define BUTTON_LONG_MS 3000UL

void readButtons() {
  int cur1 = digitalRead(BTN1_PIN);
  int cur2 = digitalRead(BTN2_PIN);
  unsigned long now = millis();

  btn1Edge = (prevBtn1 == HIGH && cur1 == LOW);
  btn2Edge = (prevBtn2 == HIGH && cur2 == LOW);
  btn1ShortEdge = false;
  btn2ShortEdge = false;
  btn1LongEdge  = false;
  btn2LongEdge  = false;

  if (cur1 == LOW) {
    if (prevBtn1 == HIGH || btn1DownMs == 0) {
      btn1DownMs = now;
      btn1LongFired = false;
    }
    if (!btn1LongFired && (now - btn1DownMs >= BUTTON_LONG_MS)) {
      btn1LongFired = true;
      btn1LongEdge = true;
      Serial.println(F("BTN1_LONG"));
    }
  } else {
    if (prevBtn1 == LOW && !btn1LongFired) {
      btn1ShortEdge = true;
      Serial.println(F("BTN1_SHORT"));
    }
    btn1DownMs = 0;
    btn1LongFired = false;
  }

  if (cur2 == LOW) {
    if (prevBtn2 == HIGH || btn2DownMs == 0) {
      btn2DownMs = now;
      btn2LongFired = false;
    }
    if (!btn2LongFired && (now - btn2DownMs >= BUTTON_LONG_MS)) {
      btn2LongFired = true;
      btn2LongEdge = true;
      Serial.println(F("BTN2_LONG"));
    }
  } else {
    if (prevBtn2 == LOW && !btn2LongFired) {
      btn2ShortEdge = true;
      Serial.println(F("BTN2_SHORT"));
    }
    btn2DownMs = 0;
    btn2LongFired = false;
  }

  prevBtn1 = cur1;
  prevBtn2 = cur2;
}

// ── 화면 함수 ──
void showIdle() {
  Serial.println(F("[IDLE]"));
  tft.fillScreen(COL_BG);
  drawBMP("BACK.BMP", 0, 0);
  drawBMP("FACE.BMP", 0, 0);
}

void showIdleFastFromStatus() {
  Serial.println(F("[IDLE_FROM_STATUS]"));
  tft.fillScreen(COL_BG);
  delay(150);
  drawBMP("FACE.BMP", 0, 0);
}

void exitStatusScreen() {
  if (statusFromSnooze) {
    Serial.println(F("STATUS_RETURN_TO_SNOOZE_FACE"));
    statusFromSnooze = false;
    curState = ST_SNOOZE;
    snoozeIdled = true;
    showIdleFastFromStatus();
  } else {
    Serial.println(F("STATUS_RETURN_TO_IDLE"));
    statusFromSnooze = false;
    snoozeIdled = false;
    curState = ST_IDLE;
    showIdleFastFromStatus();
  }
}

void showFaceOnly() {
  tft.fillScreen(COL_BG);
  drawBMP("FACE.BMP", 0, 0);
}

void showAlarm() {
  tft.fillScreen(COL_BG);
  if (isRetry) drawBMP("CRY.BMP",0,0); else drawBMP("SMILE.BMP",0,0);
  drawTime(currentTime);
  drawMedArea();
  if (isRetry) drawBMP("NOTYET.BMP",0,215);
  else         drawBMP("TAKE.BMP",0,215);
}

void showAsk(int idx) {
  tft.fillScreen(COL_BG);
  if (isRetry) drawBMP("CRY.BMP",0,0); else drawBMP("SMILE.BMP",0,0);
  drawTime(currentTime);
  drawMedSingle(idx,155);
  drawBMP("ASK.BMP",0,215);
}

void showOk(int idx) {
  tft.fillScreen(COL_BG);
  if (isRetry) drawBMP("CRY.BMP",0,0); else drawBMP("SMILE.BMP",0,0);
  drawMedSingle(idx,130);
  fillBg(190,25);
  drawBMP("OK.BMP",0,215);
}

void showOkCancel(int idx) {
  tft.fillScreen(COL_BG);
  if (isRetry) drawBMP("CRY.BMP",0,0); else drawBMP("SMILE.BMP",0,0);
  drawMedSingle(idx,130);
  fillBg(190,25);
  drawBMP("OK.BMP",0,215);
}

void showSnooze() {
  tft.fillScreen(COL_BG);
  drawBMP("CRY.BMP",0,0);
  drawTime(currentTime);
  drawBMP("SNOOZE.BMP",0,155);
}

void showNotyet() {
  tft.fillScreen(COL_BG);
  drawBMP("CRY.BMP",0,0);
  String pendingKw[MAX_MEDS]; bool pendingLipid=false; int pendingCount=0;
  for (int i=0;i<medCount;i++) {
    if (!medTaken[i]) {
      pendingKw[pendingCount]=medKw[i];
      if(medKw[i]=="LIPID") pendingLipid=true;
      pendingCount++;
    }
  }
  fillBg(130,30);
  if (pendingCount==1) drawMedBmp(pendingKw[0],"_S",0,130);
  else if (pendingCount==2) {
    if (pendingLipid) { drawMedBmp(pendingKw[0],"_S",0,130); drawMedBmp(pendingKw[1],"_S",0,150); }
    else { drawMedBmp(pendingKw[0],"_H",0,130); drawMedBmp(pendingKw[1],"_H",120,130); }
  }
  int notyetY = (pendingCount==2&&!pendingLipid)?190:160;
  drawBMP("NOTYET.BMP",0,notyetY);
}

void showDuplicate(int idx) {
  tft.fillScreen(COL_BG);
  drawBMP("CRY.BMP",0,0);
  drawMedSingle(idx,130);
  fillBg(210,110);
  drawHangulText("이미 복용하셨어요!", 0, 220, 240, COL_BG);
  tft.setTextColor(0x0000); tft.setTextSize(2);
  char tbuf[6]; medTakenTime[idx].toCharArray(tbuf,sizeof(tbuf));
  int cx=(240-5*12)/2; tft.setCursor(cx,260); tft.print(tbuf);
  drawHangulText("복용 완료", 0, 278, 240, COL_BG);
}

void showGuardian() {
  tft.fillScreen(COL_BG);
  drawBMP("CRY.BMP",0,0);
  drawTime(currentTime);
  drawHangulText("보호자에게", 0, 185, 240, COL_BG);
  drawHangulText("연락을 보냈어요", 0, 230, 240, COL_BG);
  Serial.println(F("GUARDIAN_ALERT"));
}

// ── 주의사항 화면 ──
int cautionIdx = 0;

int cautionAsciiW(uint32_t u) {
  if (u == 0x20) return 8;
  if (u >= '0' && u <= '9') return 18;
  if (u == '.' || u == ',' || u == ':' || u == ';') return 8;
  return 12;
}

uint32_t readUtf8Char(const String &s, int &i) {
  uint8_t c = s[i];
  uint32_t u = 0;
  if (c < 0x80) {
    u = c;
    i += 1;
  } else if (c < 0xE0) {
    u = ((c & 0x1F) << 6) | (s[i+1] & 0x3F);
    i += 2;
  } else {
    u = ((c & 0x0F) << 12) | ((s[i+1] & 0x3F) << 6) | (s[i+2] & 0x3F);
    i += 3;
  }
  return u;
}

int cautionTextWidth(const String &s, int hangulW) {
  int w = 0;
  int i = 0;
  while (i < (int)s.length()) {
    uint32_t u = readUtf8Char(s, i);
    if (u == 0x20) w += HY_SPACE_W;
    else if (u < 0x80) w += cautionAsciiW(u);
    else w += hangulW;
  }
  return w;
}

void drawCautionAscii(uint32_t u, int x, int y, uint16_t bg) {
  if (u == 0x20) return;
  tft.setTextColor(0x0000, bg);
  if (u >= '0' && u <= '9') {
    tft.setTextSize(3);
    tft.setCursor(x, y + 2);
    tft.print((char)u);
    tft.setCursor(x + 1, y + 2);
    tft.print((char)u);
  } else {
    tft.setTextSize(2);
    tft.setCursor(x, y + 10);
    tft.print((char)u);
  }
}

void drawCautionLineCentered(const String &s, int y, int areaX, int areaW, uint16_t bg, int hangulW) {
  int totalW = cautionTextWidth(s, hangulW);
  int x = areaX + (areaW - totalW) / 2;
  if (x < areaX) x = areaX;
  tft.fillRect(areaX, y, areaW, 36, bg);

  int i = 0;
  int drawX = x;
  while (i < (int)s.length()) {
    uint32_t u = readUtf8Char(s, i);
    if (u == 0x20) {
      drawX += HY_SPACE_W;
    } else if (u < 0x80) {
      drawCautionAscii(u, drawX, y, bg);
      drawX += cautionAsciiW(u);
    } else {
      drawHangulChar(u, drawX, y, 0x0000, bg);
      drawX += hangulW;
    }
  }
}

void drawCautionTextCentered(const String &txt) {
  const int areaX = 10;
  const int areaW = 220;
  const int maxW  = 220;
  const int hangulW = 22;

  tft.fillRect(0, 195, 240, 100, COL_BG);
  if (cautionTextWidth(txt, hangulW) <= maxW) {
    drawCautionLineCentered(txt, 218, areaX, areaW, COL_BG, hangulW);
    return;
  }

  String line1 = "";
  String line2 = "";
  int i = 0;
  while (i < (int)txt.length()) {
    int before = i;
    readUtf8Char(txt, i);
    String token = txt.substring(before, i);
    String trial = line1 + token;
    if (cautionTextWidth(trial, hangulW) <= maxW) {
      line1 = trial;
    } else {
      line2 = txt.substring(before);
      break;
    }
  }
  line1.trim(); line2.trim();
  drawCautionLineCentered(line1, 202, areaX, areaW, COL_BG, hangulW);
  drawCautionLineCentered(line2, 238, areaX, areaW, COL_BG, hangulW);
}

void showCaution(int idx) {
  Serial.print(F("[CAUTION] 약")); Serial.print(idx);
  Serial.print(F(": ")); Serial.println(cautionText[idx]);
  tft.fillScreen(COL_BG);
  drawBMP("SMILE.BMP", 0, 0);
  drawMedSingle(idx, 130);
  String &txt = cautionText[idx];
  drawCautionTextCentered(txt);
}

// ── STATUS 화면 약 이름 표시 보조 함수 ──
bool equalsBytesStatus(const String &s, const uint8_t *bytes, int n) {
  if ((int)s.length() != n) return false;
  for (int i = 0; i < n; i++) {
    if ((uint8_t)s[i] != bytes[i]) return false;
  }
  return true;
}

bool statusIsCP949_BPMED(const String &s) {
  const uint8_t b[] = {0xC7,0xF7,0xBE,0xD0,0xBE,0xE0};
  return equalsBytesStatus(s, b, sizeof(b));
}
bool statusIsCP949_DMED(const String &s) {
  const uint8_t b[] = {0xB4,0xE7,0xB4,0xA2,0xBE,0xE0};
  return equalsBytesStatus(s, b, sizeof(b));
}
bool statusIsCP949_LIPID(const String &s) {
  const uint8_t b[] = {0xB0,0xED,0xC1,0xF6,0xC7,0xF7,0xC1,0xF5,0xBE,0xE0};
  return equalsBytesStatus(s, b, sizeof(b));
}
bool statusIsCP949_ANTIB(const String &s) {
  const uint8_t b[] = {0xC7,0xD7,0xBB,0xFD,0xC1,0xA6};
  return equalsBytesStatus(s, b, sizeof(b));
}
bool statusIsCP949_ANTICO(const String &s) {
  const uint8_t b[] = {0xC7,0xD7,0xC0,0xC0,0xB0,0xED,0xC1,0xA6};
  return equalsBytesStatus(s, b, sizeof(b));
}

void drawStatusMedName(const String &raw, int y) {
  String s = raw;
  s.trim();
  if (s == "BPMED" || s == "BP" || s == "HTN" || s == "혈압약" || statusIsCP949_BPMED(s)) {
    drawHangulTextLeft("혈압약", 20, y+4, 170, COL_BG, 24); return;
  }
  if (s == "DMED" || s == "DM" || s == "당뇨약" || statusIsCP949_DMED(s)) {
    drawHangulTextLeft("당뇨약", 20, y+4, 170, COL_BG, 24); return;
  }
  if (s == "LIPID" || s == "고지혈증약" || statusIsCP949_LIPID(s)) {
    tft.fillRect(20, y+4, 170, 36, COL_BG);
    int cx = 20; int cw = 24;
    drawHangulChar(0xACE0, cx, y+4, 0x0000, COL_BG); cx += cw;
    drawHangulChar(0xC9C0, cx, y+4, 0x0000, COL_BG); cx += cw;
    drawHangulChar(0xD608, cx, y+4, 0x0000, COL_BG); cx += cw;
    drawHangulCharScaledInCell(0xC99D, cx, y+4, 0x0000, COL_BG, cw, 22, 27, 2); cx += cw;
    drawHangulChar(0xC57D, cx, y+4, 0x0000, COL_BG); return;
  }
  if (s == "ANTIB" || s == "항생제" || statusIsCP949_ANTIB(s)) {
    drawHangulTextLeft("항생제", 20, y+4, 170, COL_BG, 24); return;
  }
  if (s == "ANTICO" || s == "항응고제" || statusIsCP949_ANTICO(s)) {
    drawHangulTextLeft("항응고제", 20, y+4, 170, COL_BG, 24); return;
  }

  bool isKorean = (s.length() > 0 && (uint8_t)s[0] >= 0xE0);
  if (isKorean) drawHangulTextLeft(s, 20, y+4, 170, COL_BG, 24);
  else {
    tft.setTextColor(0x0000); tft.setTextSize(2);
    tft.setCursor(20, y+8); tft.print(s);
  }
}

void showStatus() {
  Serial.println(F("[STATUS]"));
  tft.fillScreen(COL_BG);
  drawBMP("SMILE.BMP",0,0);
  tft.fillRect(0,118,240,30,COL_BG);
  drawHangulTextW("복약 현황", 0, 118, 240, COL_BG, 26);

  for (int i=0; i<medCount; i++) {
    int y = 163 + i * 36;
    tft.fillRect(0, y, 240, 34, COL_BG);
    Serial.print(F("약")); Serial.print(i);
    Serial.print(F(":")); Serial.println(medKw[i]);
    drawStatusMedName(medKw[i], y);
    tft.setTextColor(0x0000, COL_BG);
    tft.setTextSize(2);
    tft.setCursor(212, y+8);
    tft.print(medTaken[i] ? F("O") : F("X"));
  }

  int barY=290, barH=18, totalW=200;
  int startX=20;
  int cellW=(medCount>0)?totalW/medCount:totalW;
  int takenCount = 0;
  for (int i=0; i<medCount; i++) if (medTaken[i]) takenCount++;
  for (int i=0; i<medCount; i++) {
    int x=startX+i*cellW;
    bool fillFromLeft = (i < takenCount);
    tft.drawRect(x,barY,cellW,barH,0x0000);
    tft.fillRect(x+1,barY+1,cellW-2,barH-2, fillFromLeft ? 0x0000 : COL_BG);
  }
}

void sendTakenToEsp(int idx) {
  if (idx < 0 || idx >= medCount) return;

  String msg = "TAKEN|";
  msg += currentTime;
  msg += "|";
  msg += medKw[idx];

  Serial1.println(msg);

  Serial.print("ESP 전송: ");
  Serial.println(msg);
}

// ── 상태머신 함수 ──
void goToAskOrCaution(int idx) {
  askIdx = idx;
  if (askIdx < 0) askIdx = 0;
  if (askIdx >= medCount) return;

  if (cautionText[askIdx].length() > 0) {
    cautionIdx = askIdx;
    curState = ST_CAUTION;
    showCaution(cautionIdx);
  } else {
    curState = ST_ASK;
    showAsk(askIdx);
  }
}

void clearBtn2Undo() {
  btn2UndoPending = false;
  btn2UndoIdx = -1;
}

void rememberBtn2UndoPoint() {
  btn2UndoPending = true;
  btn2UndoIdx = askIdx;
  btn2UndoSnoozeCount = snoozeCount;
  btn2UndoIsRetry = isRetry;
  strncpy(btn2UndoTime, currentTime, sizeof(btn2UndoTime));
  btn2UndoTime[5] = '\0';
  Serial.print(F("BTN2_UNDO_SAVE "));
  Serial.println(btn2UndoIdx);
}

void showReAskMessage() {
  tft.fillScreen(COL_BG);
  drawBMP("SMILE.BMP",0,0);
  tft.fillRect(0,160,240,100,COL_BG);
  drawHangulTextW("다시", 0, 168, 240, COL_BG, 28);
  drawReAskSecondLine(210);
  delay(1500);
}

void undoBtn2ToPreviousAsk() {
  if (!btn2UndoPending || btn2UndoIdx < 0 || btn2UndoIdx >= medCount) return;

  Serial.print(F("BTN2_UNDO_TO_ASK "));
  Serial.println(btn2UndoIdx);

  snoozeCount = btn2UndoSnoozeCount;
  isRetry = btn2UndoIsRetry;
  strncpy(currentTime, btn2UndoTime, sizeof(currentTime));
  currentTime[5] = '\0';

  snoozeIdled = false;
  statusFromSnooze = false;
  askIdx = btn2UndoIdx;
  clearBtn2Undo();

  btn1Edge = false;
  btn1ShortEdge = false;
  btn1LongEdge = false;
  btn2Edge = false;
  btn2ShortEdge = false;
  btn2LongEdge = false;
  btn1DownMs = 0;
  btn2DownMs = 0;
  btn1LongFired = false;
  btn2LongFired = false;

  showReAskMessage();
  curState = ST_ASK;
  showAsk(askIdx);
}

bool canUndoBtn2InCurrentState() {
  // 중요 수정:
  // BTN2 길게 되돌리기는 실제 질문/주의사항 흐름 안에서만 허용한다.
  // 모든 질문 종료 후 ST_SNOOZE/ST_GUARDIAN에서는 BTN2 길게가
  // 재알림 전 ASK 이동 기능으로 동작해야 하므로 제외한다.
  return curState == ST_ASK || curState == ST_CAUTION;
}

bool handleBtn2UndoByBtn2Hold(unsigned long now) {
  if (!btn2UndoPending || !canUndoBtn2InCurrentState()) return false;
  if (btn2LongEdge || (digitalRead(BTN2_PIN) == LOW && btn2DownMs > 0 && (now - btn2DownMs >= BUTTON_LONG_MS))) {
    undoBtn2ToPreviousAsk();
    return true;
  }
  return false;
}

void startAlarm() {
  for (int i=0;i<medCount;i++) { medTaken[i]=false; medTakenTime[i]=""; }
  snoozeCount=0; snoozeIdled=false; statusFromSnooze=false; isRetry=false; clearBtn2Undo();
  curState=ST_ALARM; showAlarm();
}

void moveNextAsk() {
  if (curState == ST_OK_CANCEL) askIdx = cancelMedIdx;
  curState = ST_ASK;
  askIdx++;
  while (askIdx<medCount && medTaken[askIdx]) askIdx++;

  bool anySkipped=false;
  for (int i=0;i<medCount;i++) if (!medTaken[i]) anySkipped=true;

  if (askIdx<medCount) { goToAskOrCaution(askIdx); return; }

  if (anySkipped) {
    snoozeCount++;

    // 중요 수정:
    // 마지막 질문에서 BTN2로 넘어온 기록이 남아 있으면,
    // 스누즈 대기 중 BTN2 길게가 "다시 물어볼게요!" undo로 먼저 잡힌다.
    // 따라서 질문 세트가 끝나는 순간 undo 상태를 지운다.
    clearBtn2Undo();

    if (snoozeCount>=SNOOZE_LIMIT) {
      curState=ST_GUARDIAN;
      showGuardian();
      return;
    }

    char snoozedTime[6];
    addMinutes(currentTime, SNOOZE_DELAY<60000UL ? 1 : SNOOZE_DELAY/1000/60, snoozedTime);
    memcpy(currentTime,snoozedTime,6);
    isRetry=true;
    snoozeIdled=false;
    curState=ST_SNOOZE;
    snoozeStartMs=millis();
    showSnooze();
    Serial.print(F("스누즈 ")); Serial.print(snoozeCount); Serial.print(F("회 → ")); Serial.println(currentTime);
  } else {
    clearBtn2Undo();
    isRetry=false; snoozeCount=0; curState=ST_IDLE; showIdleFastFromStatus();
    Serial.println(F("전체 복용 완료!"));
  }
}

String rxBufUSB = "";
String rxBufWiFi = "";

void printCommandHelp() {
  Serial.println(F("명령어:"));
  Serial.println(F("  ALERT|09:30|2|DMED|BPMED"));
  Serial.println(F("  ALERT|09:30|2|DMED|BPMED|식후 30분|아침 공복"));
  Serial.println(F("  RESET"));
}

void parseCommand(String cmd, bool showHelpOnInvalid) {
  cmd.trim();

  // 빈 줄, ESP8266 부팅 잡음, 기타 이상한 문자열은 무시
  if (cmd.length() == 0) return;

  Serial.print(F("CMD: "));
  Serial.println(cmd);

  if (cmd == "RESET") {
    medCount=0; isRetry=false; askIdx=0; snoozeCount=0;
    cancelMedIdx=-1; snoozeIdled=false; statusFromSnooze=false; clearBtn2Undo(); curState=ST_IDLE;
    hasCaution=false;
    for (int i=0;i<MAX_MEDS;i++) {
      medTaken[i]=false; medTakenTime[i]=""; cautionText[i]="";
    }
    showIdle();
    return;
  }

  if (cmd.startsWith("ALERT|")) {
    parseMeds(cmd);
    if (medCount > 0) startAlarm();
    return;
  }

  if (cmd.startsWith("CAUTION|")) {
    int start = 8;
    hasCaution = false;
    for (int i=0; i<medCount; i++) {
      int sep = cmd.indexOf('|', start);
      if (sep == -1) {
        cautionText[i] = cmd.substring(start);
        cautionText[i].trim();
        if (cautionText[i].length() > 0) hasCaution = true;
        break;
      } else {
        cautionText[i] = cmd.substring(start, sep);
        cautionText[i].trim();
        if (cautionText[i].length() > 0) hasCaution = true;
        start = sep + 1;
      }
    }
    Serial.print(F("주의사항 등록: "));
    for (int i=0;i<medCount;i++) {
      Serial.print(i); Serial.print(F(":")); Serial.print(cautionText[i]); Serial.print(F(" "));
    }
    Serial.println();
    return;
  }

  // USB 시리얼 모니터에서 직접 잘못 입력했을 때만 도움말 출력
  // WiFi 모듈 쪽에서 들어오는 빈 줄/부팅 잡음 때문에 화면 흐름이 깨지는 것을 방지
  if (showHelpOnInvalid) {
    printCommandHelp();
  } else {
    Serial.println(F("WiFi serial ignored: invalid command"));
  }
}

void readOneSerial(Stream &port, String &buf, bool showHelpOnInvalid) {
  while (port.available()) {
    char c = port.read();

    if (c == '\r') continue;

    if (c == '\n') {
      buf.trim();
      if (buf.length() > 0) {
        parseCommand(buf, showHelpOnInvalid);
      }
      buf = "";
    } else {
      if (buf.length() < 160) {
        buf += c;
      } else {
        // 비정상적으로 긴 문자열은 버림
        buf = "";
      }
    }
  }
}

void readSerial() {
  // USB Serial: 사람이 시리얼 모니터에 직접 ALERT를 입력하는 용도
  readOneSerial(Serial, rxBufUSB, true);

  // Serial1: ESP8266/ESP32 WiFi 모듈 전용 입력
  // 연결: WiFi TX -> Mega RX1(19), WiFi GND -> Mega GND
  readOneSerial(Serial1, rxBufWiFi, false);
}

void setup() {
  Serial.begin(115200);
  Serial1.begin(9600);  // WiFi 모듈 전용 입력: Mega RX1(19) 사용
  delay(500);
  Serial.println(F("=== MedReminder ==="));
  pinMode(BTN1_PIN,INPUT_PULLUP);
  pinMode(BTN2_PIN,INPUT_PULLUP);
  prevBtn1=digitalRead(BTN1_PIN);
  prevBtn2=digitalRead(BTN2_PIN);
  uint16_t ID=tft.readID();
  if (ID==0xD3D3||ID==0xFFFF||ID==0x0000) ID=0x9341;
  tft.begin(ID); tft.setRotation(0); tft.fillScreen(0xFFFF);
  pinMode(SD_CS,OUTPUT); digitalWrite(SD_CS,HIGH);
  if (!SD.begin(SD_CS)) {
    tft.setTextColor(0xF800); tft.setTextSize(2); tft.setCursor(10,140); tft.print(F("SD FAIL")); return;
  }
  Serial.println(F("SD OK"));
  showIdle();
}

void goToFirstPendingAskOrIdleFromSnooze() {
  clearBtn2Undo();
  askIdx=0;
  while (askIdx<medCount && medTaken[askIdx]) askIdx++;
  if (askIdx<medCount) {
    goToAskOrCaution(askIdx);
  } else {
    isRetry=false;
    curState=ST_IDLE;
    showIdleFastFromStatus();
  }
}

void loop() {
  unsigned long now = millis();
  readSerial();
  readButtons();

  // 질문/주의사항 흐름 안에서만 BTN2 길게 undo를 최우선 처리한다.
  if (handleBtn2UndoByBtn2Hold(now)) return;

  switch (curState) {
    case ST_IDLE:
      if (btn1ShortEdge && medCount>0) {
        btn1ShortEdge=false; btn1Edge=false;
        statusFromSnooze=false;
        curState=ST_STATUS; statusStartMs=millis(); showStatus();
        break;
      }
      break;

    case ST_STATUS:
      if (btn2LongEdge && medCount>0) {
        Serial.println(F("STATUS_BTN2_LONG_TO_ASK"));
        btn2LongEdge=false; btn2Edge=false; btn2ShortEdge=false;
        btn1ShortEdge=false; btn1Edge=false;
        statusFromSnooze=false;
        snoozeIdled=false;
        goToFirstPendingAskOrIdleFromSnooze();
      }
      else if (btn1ShortEdge) {
        btn1ShortEdge=false; btn1Edge=false;
        btn2Edge=false; btn2ShortEdge=false; btn2LongEdge=false;
        exitStatusScreen();
      }
      break;

    case ST_ALARM:
      if (btn1Edge||btn2Edge) {
        btn1Edge=false; btn2Edge=false; btn2ShortEdge=false;
        goToAskOrCaution(0);
      }
      break;

    case ST_CAUTION:
      if ((btn2UndoPending && (btn1ShortEdge || btn2ShortEdge)) || (!btn2UndoPending && (btn1Edge || btn2Edge))) {
        btn1Edge=false; btn1ShortEdge=false; btn2Edge=false; btn2ShortEdge=false;
        clearBtn2Undo();
        askIdx = cautionIdx;
        curState = ST_ASK;
        showAsk(askIdx);
      }
      break;

    case ST_ASK:
      if ((!btn2UndoPending && btn1Edge) || (btn2UndoPending && btn1ShortEdge)) {
        btn1Edge=false; btn1ShortEdge=false;
        clearBtn2Undo();
        if (medTaken[askIdx]) {
          curState=ST_DUPLICATE; showDuplicate(askIdx);
        } else {
          medTaken[askIdx]=true; medTakenTime[askIdx]=String(currentTime);
          cancelMedIdx=askIdx; okCancelMs=millis();
          curState=ST_OK_CANCEL; showOkCancel(askIdx);
        }
      }
      else if ((!btn2UndoPending && btn2Edge) || (btn2UndoPending && btn2ShortEdge)) {
        btn2Edge=false; btn2ShortEdge=false;
        rememberBtn2UndoPoint();
        moveNextAsk();
      }
      break;

    case ST_OK_CANCEL:
      if (btn2Edge || btn2ShortEdge) {
        Serial.println(F("복용 완료 취소"));
        btn2Edge=false; btn2ShortEdge=false; btn2LongEdge=false;
        if (cancelMedIdx>=0 && cancelMedIdx<medCount) {
          medTaken[cancelMedIdx]=false;
          medTakenTime[cancelMedIdx]="";
          askIdx=cancelMedIdx;
          curState=ST_ASK;
          showAsk(askIdx);
        }
      }
      break;

    case ST_DUPLICATE:
      if (btn1Edge||btn2Edge||btn1ShortEdge||btn2ShortEdge) {
        btn1Edge=false; btn2Edge=false; btn1ShortEdge=false; btn2ShortEdge=false;
        moveNextAsk();
      }
      break;

    case ST_GUARDIAN:
      // 보호자 화면에서도 BTN2 길게 누르면 남은 약 ASK로 바로 진입 가능
      if (btn2LongEdge && medCount>0) {
        Serial.println(F("GUARDIAN_BTN2_LONG_TO_ASK"));
        btn2LongEdge=false; btn2Edge=false; btn2ShortEdge=false;
        goToFirstPendingAskOrIdleFromSnooze();
      }
      break;

    case ST_SNOOZE:
      // 중요 수정: 재알림 전 대기 상태에서 BTN2 길게 → 바로 미복용 약 ASK
      // BTN2를 누르는 순간의 btn2Edge로 먼저 처리하면 3초 길게 누름을 기다리지 못하므로,
      // BTN2는 long edge만 ASK 이동으로 사용한다.
      if (btn2LongEdge && medCount>0) {
        clearBtn2Undo();
        Serial.println(F("SNOOZE_BTN2_LONG_TO_ASK"));
        btn2LongEdge=false; btn2Edge=false; btn2ShortEdge=false;
        btn1ShortEdge=false; btn1Edge=false;
        snoozeIdled=false;
        goToFirstPendingAskOrIdleFromSnooze();
      }
      // BTN1 짧게 → 복약 현황. 단, FACE 대기 화면으로 넘어간 뒤에만 동작
      else if (btn1ShortEdge && snoozeIdled && medCount>0) {
        Serial.println(F("SNOOZE_BTN1_SHORT_TO_STATUS"));
        btn1ShortEdge=false; btn1Edge=false;
        btn2Edge=false; btn2ShortEdge=false;
        statusFromSnooze=true;
        curState=ST_STATUS;
        statusStartMs=millis();
        showStatus();
      }
      // 스누즈 안내 화면이 아직 떠 있는 초기 5초 동안 BTN1을 누르면 기존처럼 ASK로 진입
      else if (btn1Edge && !snoozeIdled) {
        btn1Edge=false;
        askIdx=0;
        while (askIdx<medCount && medTaken[askIdx]) askIdx++;
        if (askIdx<medCount) {
          clearBtn2Undo();
          curState=ST_ASK; showAsk(askIdx);
        }
      }
      // BTN2 짧게는 스누즈 대기 중 오동작 방지를 위해 무시
      else if (btn2ShortEdge) {
        btn2ShortEdge=false; btn2Edge=false;
      }
      break;

    case ST_NOTYET:
      if (btn1Edge||btn2Edge) {
        btn1Edge=false; btn2Edge=false;
        askIdx=0;
        while (askIdx<medCount && medTaken[askIdx]) askIdx++;
        if (askIdx<medCount) { clearBtn2Undo(); goToAskOrCaution(askIdx); }
        else { isRetry=false; curState=ST_IDLE; showIdle(); }
      }
      break;

    default: break;
  }

  if (curState==ST_SNOOZE && !snoozeIdled && now-snoozeStartMs>=5000UL) {
    snoozeIdled=true;
    Serial.println(F("스누즈 대기 → FACE"));
    showFaceOnly();
  }

  if (curState==ST_SNOOZE && now-snoozeStartMs>=SNOOZE_DELAY) {
    Serial.println(F("스누즈 만료 → NOTYET"));
    snoozeIdled=false; curState=ST_NOTYET; showNotyet();
  }

  if (curState==ST_STATUS && now-statusStartMs>=STATUS_DURATION) {
    exitStatusScreen();
  }

  if (curState==ST_OK_CANCEL && now-okCancelMs>=OK_CANCEL_DELAY) {
    Serial.println(F("복용 완료 확정"));
    sendTakenToEsp(cancelMedIdx);
    moveNextAsk();
  }
  
}
