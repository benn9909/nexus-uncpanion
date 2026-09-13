#pragma once

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_MPU6050.h>
#include "MAX30105.h"
#include "activity.h"
#include "display_helpers.h"

#define SDA_PIN 21
#define SCL_PIN 22
#define BUTTON_LEFT 25
#define BUTTON_CENTER 26
#define BUTTON_RIGHT 27

enum Screen { HOME_SCREEN, FOCUS_SCREEN, HEALTH_SCREEN, ACTIVITY_SCREEN };

extern Adafruit_SSD1306 display;
extern Adafruit_MPU6050 mpu;
extern MAX30105 maxSensor;
extern bool mpuOK, maxOK;
extern Screen currentScreen;
extern unsigned long lastUncMessageChange, typewriterStartTime, nextBlinkTime;

void setupBLE();
void updateBLE();
void updateHeartRate();
void updatePomodoro();
void updateUnc();
void updateUncAnimation();
void handleButtons();
void drawHomeScreen();
void drawFocusScreen();
void drawHealthScreen();
void applyPageTransition();
