#include <Adafruit_GFX.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_Sensor.h>
#include "activity.h"
#include "display_helpers.h"

extern Adafruit_MPU6050 mpu;
extern Adafruit_SSD1306 display;
extern bool mpuOK;

float currentAccelMagnitude = 9.8;
bool currentlyMoving = false;
bool inactiveTooLong = false;
unsigned long lastMovementTime = 0;

namespace {
const unsigned long activityUpdateInterval = 100;
const unsigned long inactivityThreshold = 20000;  // Demo threshold: 20 seconds.
const unsigned long movementGoal = 120000;
const unsigned long completionDuration = 900;

enum ActivityState { RESTING, REMINDER, MOVING, COMPLETE };
ActivityState activityState = RESTING;
unsigned long lastActivityUpdate = 0;
unsigned long lastMotionTick = 0;
unsigned long movementProgress = 0;
unsigned long completionStartedAt = 0;

uint8_t percent(unsigned long value, unsigned long maximum) {
  if (maximum == 0) return 0;
  return (uint8_t)min(100UL, (value * 100UL) / maximum);
}

void updateState(unsigned long now, bool wasMoving) {
  if (activityState == COMPLETE) {
    if (now - completionStartedAt >= completionDuration) {
      movementProgress = 0;
      lastMovementTime = now;
      inactiveTooLong = false;
      activityState = currentlyMoving ? MOVING : RESTING;
      lastMotionTick = now;
    }
    return;
  }

  if (currentlyMoving) {
    lastMovementTime = now;
    inactiveTooLong = false;
    if (!wasMoving) lastMotionTick = now;
    movementProgress = min(movementGoal, movementProgress + (now - lastMotionTick));
    lastMotionTick = now;
    activityState = MOVING;
    if (movementProgress >= movementGoal) {
      activityState = COMPLETE;
      completionStartedAt = now;
    }
    return;
  }

  lastMotionTick = now;
  inactiveTooLong = now - lastMovementTime >= inactivityThreshold;
  activityState = inactiveTooLong ? REMINDER : RESTING;
}
}  // namespace

void updateActivityData() {
  if (!mpuOK || millis() - lastActivityUpdate < activityUpdateInterval) return;
  const unsigned long now = millis();
  lastActivityUpdate = now;

  sensors_event_t accel, gyro, temp;
  mpu.getEvent(&accel, &gyro, &temp);
  currentAccelMagnitude = sqrt(
      accel.acceleration.x * accel.acceleration.x +
      accel.acceleration.y * accel.acceleration.y +
      accel.acceleration.z * accel.acceleration.z);

  const bool wasMoving = currentlyMoving;
  currentlyMoving = currentAccelMagnitude > 12.0 || currentAccelMagnitude < 7.0;
  updateState(now, wasMoving);
}

void drawActivityScreen() {
  drawHeader("ACTIVITY");
  if (!mpuOK) {
    drawUncFace(UNC_FACE_TIRED, 14);
    drawCenteredText("SENSOR OFF", 35);
    drawCenteredText("Check MPU6050", 51);
    return;
  }

  const unsigned long now = millis();
  if (activityState == RESTING) {
    drawUncFace(UNC_FACE_HAPPY, 14);
    drawCenteredText("RESTING", 33, 2);
    drawCenteredText(formatDuration(now - lastMovementTime) + " sitting", 50);
    drawProgressBar(8, 58, 112, 5, percent(now - lastMovementTime, inactivityThreshold));
  } else if (activityState == REMINDER) {
    drawUncFace(UNC_FACE_ALERT, 14);
    drawCenteredText("MOVE NOW", 33, 2);
    drawCenteredText(formatDuration(now - lastMovementTime) + " sitting", 50);
    drawCenteredText("Move for 2 min", 57);
  } else if (activityState == MOVING) {
    drawUncFace((now / 150) % 2 ? UNC_FACE_EXCITED : UNC_FACE_HAPPY, 14);
    drawCenteredText("MOVING", 33, 2);
    drawCenteredText(formatDuration(movementProgress), 50);
    drawProgressBar(8, 58, 112, 5, percent(movementProgress, movementGoal));
  } else {
    drawUncFace(UNC_FACE_EXCITED, 14);
    drawCenteredText("NICE WORK!", 33, 2);
    drawCenteredText("Movement complete", 50);
    drawCenteredText("+1 BREAK", 57);
  }
}
