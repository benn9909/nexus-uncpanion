#pragma once

#include <Arduino.h>

enum UncFace {
  UNC_FACE_HAPPY,
  UNC_FACE_ALERT,
  UNC_FACE_EXCITED,
  UNC_FACE_TIRED,
};

void drawCenteredText(const String &text, int y, uint8_t textSize = 1);
void drawHeader(const char *title);
void drawUncFace(UncFace face, int y);
void drawProgressBar(int x, int y, int width, int height, uint8_t percent);
String formatDuration(unsigned long durationMs);
