#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "display_helpers.h"

extern Adafruit_SSD1306 display;

void drawCenteredText(const String &text, int y, uint8_t textSize) {
  display.setTextSize(textSize);
  int width = text.length() * 6 * textSize;
  display.setCursor((128 - width) / 2, y);
  display.print(text);
}

void drawHeader(const char *title) {
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.print("<");
  drawCenteredText(String(title), 0);
  display.setCursor(122, 0);
  display.print(">");
  display.drawLine(0, 10, 127, 10, SSD1306_WHITE);
}

void drawUncFace(UncFace face, int y) {
  const char *expression = "^_^";
  if (face == UNC_FACE_ALERT) expression = "o_o";
  if (face == UNC_FACE_EXCITED) expression = "^o^";
  if (face == UNC_FACE_TIRED) expression = "-_-";
  drawCenteredText(String(expression), y, 2);
}

void drawProgressBar(int x, int y, int width, int height, uint8_t percent) {
  percent = constrain(percent, 0, 100);
  display.drawRect(x, y, width, height, SSD1306_WHITE);
  int fillWidth = ((width - 2) * percent) / 100;
  if (fillWidth > 0) display.fillRect(x + 1, y + 1, fillWidth, height - 2, SSD1306_WHITE);
}

String formatDuration(unsigned long durationMs) {
  unsigned long totalSeconds = durationMs / 1000;
  unsigned long minutes = totalSeconds / 60;
  unsigned long seconds = totalSeconds % 60;
  char buffer[12];
  snprintf(buffer, sizeof(buffer), "%02lu:%02lu", minutes, seconds);
  return String(buffer);
}
