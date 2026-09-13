#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>
#include "MAX30105.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <atomic>
#include "activity.h"
#include "display_helpers.h"

void setupBLE();
void updateBLE();
void updateHeartRate();
float medianBPM();
void handleButtons();
void leftAction(unsigned long pressDuration);
void rightAction();
void centerAction();
void nextScreen();
void previousScreen();
void updatePomodoro();
unsigned long getPomodoroDuration();
void updateUnc();
void updateUncAnimation();
void resetUncDialogue();
void drawTypewriterText(String line1, String line2);
void drawHomeScreen();
void drawUncDialogue();
void drawFocusScreen();
void drawFocusSetup();
void updatePulseHistory();
void drawPulseHeart(bool expanded);
void drawPulseWaveform();
void drawHealthScreen();

// ======================================================
// PINS
// ======================================================

#define SDA_PIN 21
#define SCL_PIN 22

#define BUTTON_LEFT   25
#define BUTTON_CENTER 26
#define BUTTON_RIGHT  27

// ======================================================
// OLED
// ======================================================

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1

Adafruit_SSD1306 display(
  SCREEN_WIDTH,
  SCREEN_HEIGHT,
  &Wire,
  OLED_RESET
);

// ======================================================
// SENSORS
// ======================================================

Adafruit_MPU6050 mpu;
MAX30105 maxSensor;

bool mpuOK = false;
bool maxOK = false;

// ======================================================
// MAIN SCREENS
// ======================================================

enum Screen {
  HOME_SCREEN,
  FOCUS_SCREEN,
  HEALTH_SCREEN,
  ACTIVITY_SCREEN
};

Screen currentScreen = HOME_SCREEN;

const unsigned long PAGE_TRANSITION_MS = 160;
bool pageTransitionActive = false;
int8_t pageTransitionDirection = 1;
unsigned long pageTransitionStartedAt = 0;
uint8_t outgoingFrame[SCREEN_WIDTH * SCREEN_HEIGHT / 8];
uint8_t incomingFrame[SCREEN_WIDTH * SCREEN_HEIGHT / 8];

void startPageTransition(int8_t direction) {
  memcpy(outgoingFrame, display.getBuffer(), sizeof(outgoingFrame));
  pageTransitionDirection = direction;
  pageTransitionStartedAt = millis();
  pageTransitionActive = true;
}

void applyPageTransition() {
  if (!pageTransitionActive) return;
  unsigned long elapsed = millis() - pageTransitionStartedAt;
  if (elapsed >= PAGE_TRANSITION_MS) {
    pageTransitionActive = false;
    return;
  }

  memcpy(incomingFrame, display.getBuffer(), sizeof(incomingFrame));
  uint16_t t = (elapsed * 256UL) / PAGE_TRANSITION_MS;
  uint16_t inverse = 256 - t;
  uint16_t eased = 256 - ((inverse * inverse) >> 8);
  int shift = (eased * SCREEN_WIDTH) >> 8;
  uint8_t *frame = display.getBuffer();

  for (int page = 0; page < SCREEN_HEIGHT / 8; page++) {
    int row = page * SCREEN_WIDTH;
    for (int x = 0; x < SCREEN_WIDTH; x++) {
      if (pageTransitionDirection > 0) {
        int source = x + shift;
        frame[row + x] = source < SCREEN_WIDTH
            ? outgoingFrame[row + source]
            : incomingFrame[row + source - SCREEN_WIDTH];
      } else {
        int source = x - shift;
        frame[row + x] = source >= 0
            ? outgoingFrame[row + source]
            : incomingFrame[row + source + SCREEN_WIDTH];
      }
    }
  }
}

// ======================================================
// BUTTONS
// ======================================================

const unsigned long DEBOUNCE_TIME = 180;
const unsigned long LONG_PRESS_TIME = 700;

unsigned long lastLeftPress = 0;
unsigned long lastCenterPress = 0;
unsigned long lastRightPress = 0;
bool leftDown = false;
bool centerDown = false;
bool rightDown = false;
unsigned long leftDownAt = 0;

// ======================================================
// HEART RATE
// ======================================================

const long FINGER_THRESHOLD = 50000;
const long DROP_THRESHOLD = -120;

const unsigned long REFRACTORY_MS = 450;
const unsigned long FINGER_STABILIZE_TIME = 2000;

long currentIR = 0;
long previousIR = 0;

bool fingerPresent = false;
bool heartRateReady = false;

unsigned long fingerPlacedTime = 0;
unsigned long lastBeatTime = 0;

float currentBPM = 0;
float filteredBPM = 0;

// Median filter
const int RATE_SIZE = 5;

float rates[RATE_SIZE];

int rateIndex = 0;
int rateCount = 0;

// Display-only pulse history. The BPM detector continues to use raw IR.
const int PULSE_SAMPLES = 64;
const unsigned long PULSE_SAMPLE_INTERVAL = 40;
const unsigned long HEART_PULSE_DURATION = 180;
const unsigned long BPM_DISPLAY_TIMEOUT = 3000;
long pulseSamples[PULSE_SAMPLES];
int pulseHead = 0;
int pulseCount = 0;
unsigned long lastPulseSample = 0;
unsigned long lastValidBeatTime = 0;
bool hasValidBeat = false;
float displayIR = 0;
float pulseBaselineIR = 0;
float pulseScaleLow = 0;
float pulseScaleHigh = 0;
bool pulseScaleReady = false;

// ======================================================
// POMODORO
// ======================================================

enum PomodoroState {
  POMO_SETUP,
  POMO_FOCUS,
  POMO_SHORT_BREAK,
  POMO_LONG_BREAK
};

PomodoroState pomoState = POMO_SETUP;

const int MIN_SESSIONS = 1;
const int MAX_SESSIONS = 8;

int selectedSessions = 4;
int pomoSession = 1;

bool pomoRunning = false;

unsigned long pomoStartTime = 0;
unsigned long pomoElapsedBeforePause = 0;

// TEST TIMES
const unsigned long FOCUS_DURATION = 5000;
const unsigned long SHORT_BREAK_DURATION = 2000;
const unsigned long LONG_BREAK_DURATION = 3000;

// ======================================================
// UNC
// ======================================================

enum UncMood {
  UNC_HAPPY,
  UNC_FOCUSED,
  UNC_RESTING,
  UNC_ACTIVE,
  UNC_INACTIVE
};

UncMood uncMood = UNC_HAPPY;

const unsigned long UNC_MESSAGE_INTERVAL = 5000;

unsigned long lastUncMessageChange = 0;
int uncMessageIndex = 0;

// ======================================================
// TYPEWRITER
// ======================================================

const unsigned long LETTER_DELAY = 45;

unsigned long typewriterStartTime = 0;

// ======================================================
// UNC BLINKING
// ======================================================

bool uncBlinking = false;

unsigned long nextBlinkTime = 0;
unsigned long blinkStartTime = 0;

const unsigned long BLINK_DURATION = 160;

// ======================================================
// SETUP
// ======================================================

// Read-only telemetry fits a default 20-byte BLE notification.
const char *UNC_SERVICE_UUID = "b7d10001-6a2b-4c3d-8e9f-102030405060";
const char *UNC_TELEMETRY_UUID = "b7d10002-6a2b-4c3d-8e9f-102030405060";
BLECharacteristic *uncTelemetry = nullptr;
std::atomic<bool> bleConnected(false);
std::atomic<bool> bleRestartRequested(false);
unsigned long bleRestartAt = 0;
bool bleRestartPending = false;
unsigned long lastBleUpdate = 0;
uint16_t bleSequence = 0;

class UncBleCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *) override {
    bleConnected.store(true);
  }
  void onDisconnect(BLEServer *) override {
    bleConnected.store(false);
    bleRestartRequested.store(true);
  }
};

void setupBLE() {
  BLEDevice::init("Uncpanion Watch");
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new UncBleCallbacks());
  BLEService *service = server->createService(UNC_SERVICE_UUID);
  uncTelemetry = service->createCharacteristic(
    UNC_TELEMETRY_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  uncTelemetry->addDescriptor(new BLE2902());
  service->start();
  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(UNC_SERVICE_UUID);
  advertising->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.println("BLE ready: Uncpanion Watch");
}

void updateBLE() {
  unsigned long now = millis();
  if (bleRestartRequested.exchange(false)) {
    bleRestartAt = now;
    bleRestartPending = true;
  }
  if (bleRestartPending && now - bleRestartAt >= 500) {
    bleRestartPending = false;
    if (!bleConnected.load()) BLEDevice::startAdvertising();
  }
  if (!uncTelemetry || now - lastBleUpdate < 100) return;
  lastBleUpdate = now;
  bool validBPM = maxOK && fingerPresent && heartRateReady && hasValidBeat &&
                  now - lastValidBeatTime < BPM_DISPLAY_TIMEOUT && filteredBPM > 0;
  uint8_t packet[20] = {0};
  packet[0] = 1; // Protocol version
  packet[1] = (maxOK ? 1 : 0) | (mpuOK ? 2 : 0) |
              (fingerPresent ? 4 : 0) | (heartRateReady ? 8 : 0) |
              (validBPM ? 16 : 0) | (pomoRunning ? 32 : 0);
  packet[2] = validBPM ? (uint8_t)round(filteredBPM) : 255;
  packet[3] = !mpuOK ? 255 : inactiveTooLong ? 2 : currentlyMoving ? 1 : 0;
  packet[4] = (uint8_t)pomoState;
  packet[5] = (uint8_t)pomoSession;
  packet[6] = (uint8_t)selectedSessions;
  packet[7] = (uint8_t)uncMood;
  uint32_t remainingMs = 0;
  if (pomoState != POMO_SETUP) {
    unsigned long elapsed = pomoElapsedBeforePause + (pomoRunning ? now - pomoStartTime : 0);
    unsigned long duration = getPomodoroDuration();
    remainingMs = elapsed < duration ? duration - elapsed : 0;
  }
  uint16_t acceleration = mpuOK ? (uint16_t)(constrain(currentAccelMagnitude, 0.0f, 655.34f) * 100) : 65535;
  uint32_t ir = maxOK && fingerPresent ? (uint32_t)currentIR : 0;
  for (int i = 0; i < 4; i++) {
    packet[8 + i] = (remainingMs >> (8 * i)) & 255;
    packet[14 + i] = (ir >> (8 * i)) & 255;
  }
  packet[12] = acceleration & 255;
  packet[13] = acceleration >> 8;
  packet[18] = bleSequence & 255;
  packet[19] = bleSequence >> 8;
  bleSequence++;
  uncTelemetry->setValue(packet, sizeof(packet));
  if (bleConnected.load()) uncTelemetry->notify();
}

void updateHeartRate() {

  if (!maxOK) {
    return;
  }

  currentIR =
    maxSensor.getIR();

  updatePulseHistory();

  // ----------------------------------------------------
  // NO FINGER
  // ----------------------------------------------------

  if (
    currentIR <
    FINGER_THRESHOLD
  ) {

    fingerPresent = false;
    heartRateReady = false;

    currentBPM = 0;
    filteredBPM = 0;

    rateCount = 0;
    rateIndex = 0;

    lastBeatTime = 0;

    previousIR =
      currentIR;

    return;
  }

  // ----------------------------------------------------
  // FINGER JUST PLACED
  // ----------------------------------------------------

  if (!fingerPresent) {

    fingerPresent = true;

    heartRateReady = false;

    fingerPlacedTime =
      millis();

    previousIR =
      currentIR;

    lastBeatTime = 0;

    rateCount = 0;
    rateIndex = 0;

    currentBPM = 0;
    filteredBPM = 0;

    return;
  }

  // ----------------------------------------------------
  // STABILIZE
  // ----------------------------------------------------

  if (!heartRateReady) {

    if (
      millis() -
        fingerPlacedTime >=
      FINGER_STABILIZE_TIME
    ) {

      heartRateReady =
        true;

      previousIR =
        currentIR;
    }

    else {

      previousIR =
        currentIR;

      return;
    }
  }

  // ----------------------------------------------------
  // FALLING EDGE DETECTION
  // ----------------------------------------------------

  long change =
    currentIR -
    previousIR;

  previousIR =
    currentIR;

  if (
    change <
    DROP_THRESHOLD
  ) {

    unsigned long now =
      millis();

    if (
      lastBeatTime == 0 ||
      now - lastBeatTime >=
        REFRACTORY_MS
    ) {

      if (
        lastBeatTime != 0
      ) {

        unsigned long beatInterval =
          now -
          lastBeatTime;

        float bpm =
          60000.0 /
          beatInterval;

        if (
          bpm >= 50 &&
          bpm <= 140
        ) {

          currentBPM =
            bpm;

          rates[rateIndex] =
            bpm;

          rateIndex++;

          if (
            rateIndex >=
            RATE_SIZE
          ) {

            rateIndex = 0;
          }

          if (
            rateCount <
            RATE_SIZE
          ) {

            rateCount++;
          }

          filteredBPM =
            medianBPM();

          lastValidBeatTime = now;
          hasValidBeat = true;

          Serial.print("BPM: ");

          Serial.print(
            currentBPM,
            1
          );

          Serial.print(
            " | Filtered: "
          );

          Serial.println(
            filteredBPM,
            1
          );
        }
      }

      lastBeatTime =
        now;
    }
  }
}

// ======================================================
// BPM MEDIAN FILTER
// ======================================================

float medianBPM() {

  if (
    rateCount == 0
  ) {

    return 0;
  }

  float temp[RATE_SIZE];

  for (
    int i = 0;
    i < rateCount;
    i++
  ) {

    temp[i] =
      rates[i];
  }

  for (
    int i = 0;
    i < rateCount - 1;
    i++
  ) {

    for (
      int j = i + 1;
      j < rateCount;
      j++
    ) {

      if (
        temp[j] <
        temp[i]
      ) {

        float t =
          temp[i];

        temp[i] =
          temp[j];

        temp[j] =
          t;
      }
    }
  }

  if (
    rateCount % 2 == 1
  ) {

    return temp[
      rateCount / 2
    ];
  }

  return (
    temp[
      rateCount / 2 - 1
    ] +

    temp[
      rateCount / 2
    ]
  ) / 2.0;
}

// ======================================================
// BUTTON HANDLING
// ======================================================

void handleButtons() {
  unsigned long now = millis();
  bool leftPressed = digitalRead(BUTTON_LEFT) == LOW;
  bool rightPressed = digitalRead(BUTTON_RIGHT) == LOW;
  bool centerPressed = digitalRead(BUTTON_CENTER) == LOW;
  if (leftPressed && !leftDown) leftDownAt = now;
  if (!leftPressed && leftDown && now - lastLeftPress > DEBOUNCE_TIME) {
    leftAction(now - leftDownAt);
    lastLeftPress = now;
  }
  if (rightPressed && !rightDown && now - lastRightPress > DEBOUNCE_TIME) {
    rightAction();
    lastRightPress = now;
  }
  if (centerPressed && !centerDown && now - lastCenterPress > DEBOUNCE_TIME) {
    centerAction();
    lastCenterPress = now;
  }
  leftDown = leftPressed;
  rightDown = rightPressed;
  centerDown = centerPressed;
}

// ======================================================
// LEFT
// ======================================================

void leftAction(unsigned long pressDuration) {

  if (
    currentScreen ==
      FOCUS_SCREEN &&

    pomoState ==
      POMO_SETUP
  ) {

    if (
      pressDuration >=
      LONG_PRESS_TIME
    ) {

      previousScreen();

      return;
    }

    selectedSessions--;

    if (
      selectedSessions <
      MIN_SESSIONS
    ) {

      selectedSessions =
        MIN_SESSIONS;
    }

    return;
  }

  previousScreen();
}

// ======================================================
// RIGHT
// ======================================================

void rightAction() {

  if (
    currentScreen ==
      FOCUS_SCREEN &&

    pomoState ==
      POMO_SETUP
  ) {

    selectedSessions++;

    if (
      selectedSessions >
      MAX_SESSIONS
    ) {

      selectedSessions =
        MAX_SESSIONS;
    }

    return;
  }

  nextScreen();
}

// ======================================================
// CENTER
// ======================================================

void centerAction() {

  if (
    currentScreen !=
    FOCUS_SCREEN
  ) {

    return;
  }

  // ----------------------------------------------------
  // START
  // ----------------------------------------------------

  if (
    pomoState ==
    POMO_SETUP
  ) {

    pomoState =
      POMO_FOCUS;

    pomoSession =
      1;

    pomoRunning =
      true;

    pomoElapsedBeforePause =
      0;

    pomoStartTime =
      millis();

    return;
  }

  // ----------------------------------------------------
  // PAUSE
  // ----------------------------------------------------

  if (pomoRunning) {

    pomoElapsedBeforePause +=
      millis() -
      pomoStartTime;

    pomoRunning =
      false;

    return;
  }

  // ----------------------------------------------------
  // RESUME
  // ----------------------------------------------------

  pomoRunning =
    true;

  pomoStartTime =
    millis();
}

// ======================================================
// NAVIGATION
// ======================================================

void nextScreen() {

  startPageTransition(1);

  int screenNumber =
    (int)currentScreen;

  screenNumber++;

  if (
    screenNumber >
    ACTIVITY_SCREEN
  ) {

    screenNumber =
      HOME_SCREEN;
  }

  currentScreen =
    (Screen)screenNumber;
}

void previousScreen() {

  startPageTransition(-1);

  int screenNumber =
    (int)currentScreen;

  screenNumber--;

  if (
    screenNumber <
    HOME_SCREEN
  ) {

    screenNumber =
      ACTIVITY_SCREEN;
  }

  currentScreen =
    (Screen)screenNumber;
}

// ======================================================
// POMODORO
// ======================================================

void updatePomodoro() {

  if (
    pomoState ==
      POMO_SETUP ||
    !pomoRunning
  ) {

    return;
  }

  unsigned long elapsed =
    pomoElapsedBeforePause +
    (
      millis() -
      pomoStartTime
    );

  unsigned long duration =
    getPomodoroDuration();

  if (
    elapsed <
    duration
  ) {

    return;
  }

  // ----------------------------------------------------
  // FOCUS FINISHED
  // ----------------------------------------------------

  if (
    pomoState ==
    POMO_FOCUS
  ) {

    if (
      pomoSession >=
      selectedSessions
    ) {

      pomoState =
        POMO_LONG_BREAK;
    }

    else {

      pomoState =
        POMO_SHORT_BREAK;
    }
  }

  // ----------------------------------------------------
  // SHORT BREAK FINISHED
  // ----------------------------------------------------

  else if (
    pomoState ==
    POMO_SHORT_BREAK
  ) {

    pomoSession++;

    pomoState =
      POMO_FOCUS;
  }

  // ----------------------------------------------------
  // LONG BREAK FINISHED
  // ----------------------------------------------------

  else if (
    pomoState ==
    POMO_LONG_BREAK
  ) {

    pomoState =
      POMO_SETUP;

    pomoSession =
      1;

    pomoRunning =
      false;

    pomoElapsedBeforePause =
      0;

    resetUncDialogue();

    return;
  }

  pomoElapsedBeforePause =
    0;

  pomoStartTime =
    millis();

  resetUncDialogue();
}

// ======================================================
// POMODORO DURATION
// ======================================================

unsigned long getPomodoroDuration() {

  if (
    pomoState ==
    POMO_FOCUS
  ) {

    return
      FOCUS_DURATION;
  }

  if (
    pomoState ==
    POMO_SHORT_BREAK
  ) {

    return
      SHORT_BREAK_DURATION;
  }

  if (
    pomoState ==
    POMO_LONG_BREAK
  ) {

    return
      LONG_BREAK_DURATION;
  }

  return 0;
}

// ======================================================
// UNC LOGIC
// ======================================================

void updateUnc() {

  UncMood newMood;

  // Pomodoro always has priority
  if (
    pomoState ==
    POMO_FOCUS
  ) {

    newMood =
      UNC_FOCUSED;
  }

  else if (
    pomoState ==
      POMO_SHORT_BREAK ||

    pomoState ==
      POMO_LONG_BREAK
  ) {

    newMood =
      UNC_RESTING;
  }

  // Then inactivity
  else if (
    inactiveTooLong
  ) {

    newMood =
      UNC_INACTIVE;
  }

  // Then current movement
  else if (
    currentlyMoving
  ) {

    newMood =
      UNC_ACTIVE;
  }

  else {

    newMood =
      UNC_HAPPY;
  }

  // ----------------------------------------------------
  // MOOD CHANGED
  // ----------------------------------------------------

  if (
    newMood !=
    uncMood
  ) {

    uncMood =
      newMood;

    uncMessageIndex =
      0;

    resetUncDialogue();
  }

  // ----------------------------------------------------
  // NEXT MESSAGE
  // ----------------------------------------------------

  if (
    millis() -
      lastUncMessageChange >=
    UNC_MESSAGE_INTERVAL
  ) {

    uncMessageIndex++;

    if (
      uncMessageIndex > 2
    ) {

      uncMessageIndex =
        0;
    }

    resetUncDialogue();
  }
}

// ======================================================
// UNC BLINK ANIMATION
// ======================================================

void updateUncAnimation() {

  unsigned long now =
    millis();

  // Start blink
  if (
    !uncBlinking &&
    now >=
      nextBlinkTime
  ) {

    uncBlinking =
      true;

    blinkStartTime =
      now;
  }

  // End blink
  if (
    uncBlinking &&
    now -
      blinkStartTime >=
      BLINK_DURATION
  ) {

    uncBlinking =
      false;

    nextBlinkTime =
      now +
      random(
        2500,
        6500
      );
  }
}

// ======================================================
// UNC DIALOGUE RESET
// ======================================================

void resetUncDialogue() {

  lastUncMessageChange =
    millis();

  typewriterStartTime =
    millis();
}

// ======================================================
// TYPEWRITER
// ======================================================

void drawTypewriterText(
  String line1,
  String line2
) {

  unsigned long elapsed =
    millis() -
    typewriterStartTime;

  int totalCharacters =
    elapsed /
    LETTER_DELAY;

  int line1Length =
    line1.length();

  int line2Length =
    line2.length();

  // ----------------------------------------------------
  // LINE 1
  // ----------------------------------------------------

  int line1Visible =
    totalCharacters;

  if (
    line1Visible >
    line1Length
  ) {

    line1Visible =
      line1Length;
  }

  String visibleLine1 =
    line1.substring(
      0,
      line1Visible
    );

  // Keep the origin fixed while characters arrive; centering a partial line
  // makes it visibly drift left on every frame.
  display.setCursor(8, 43);
  display.print(visibleLine1);

  // ----------------------------------------------------
  // LINE 2
  // ----------------------------------------------------

  int line2Visible =
    totalCharacters -
    line1Length;

  if (
    line2Visible <
    0
  ) {

    line2Visible =
      0;
  }

  if (
    line2Visible >
    line2Length
  ) {

    line2Visible =
      line2Length;
  }

  String visibleLine2 =
    line2.substring(
      0,
      line2Visible
    );

  display.setCursor(8, 54);
  display.print(visibleLine2);
}

// ======================================================
// HOME
// ======================================================

void drawHomeScreen() {

  display.setTextSize(1);

  // ----------------------------------------------------
  // HEADER
  // ----------------------------------------------------

  drawHeader("UNC");

  // ----------------------------------------------------
  // SESSION COUNTER
  // ----------------------------------------------------

  if (
    pomoState ==
      POMO_FOCUS ||

    pomoState ==
      POMO_SHORT_BREAK ||

    pomoState ==
      POMO_LONG_BREAK
  ) {

    String counter =
      String(pomoSession) +
      "/" +
      String(selectedSessions);

    int x =
      116 -
      counter.length() * 6;

    display.setCursor(
      x,
      0
    );

    display.print(
      counter
    );
  }

  // ----------------------------------------------------
  // UNC FACE
  // ----------------------------------------------------

  display.setTextSize(3);

  display.setCursor(
    37,
    14
  );

  if (uncBlinking) {

    display.print(
      "-_-"
    );
  }

  else {

    switch (uncMood) {

      case UNC_HAPPY:

        display.print(
          "^_^"
        );

        break;

      case UNC_FOCUSED:

        display.print(
          "o_o"
        );

        break;

      case UNC_RESTING:

        display.print(
          "-_-"
        );

        break;

      case UNC_ACTIVE:

        display.print(
          "^o^"
        );

        break;

      case UNC_INACTIVE:

        display.print(
          "o_o"
        );

        break;
    }
  }

  // ----------------------------------------------------
  // DIALOGUE
  // ----------------------------------------------------

  display.setTextSize(1);

  drawUncDialogue();
}

// ======================================================
// UNC DIALOGUE
// ======================================================

void drawUncDialogue() {

  // ----------------------------------------------------
  // HAPPY
  // ----------------------------------------------------

  if (
    uncMood ==
    UNC_HAPPY
  ) {

    if (
      uncMessageIndex ==
      0
    ) {

      drawTypewriterText(
        "Hey, I'm Unc!",
        "Ready to lock in?"
      );
    }

    else if (
      uncMessageIndex ==
      1
    ) {

      drawTypewriterText(
        "What's the move?",
        "Focus session?"
      );
    }

    else {

      drawTypewriterText(
        "Let's make today",
        "count."
      );
    }
  }

  // ----------------------------------------------------
  // FOCUSED
  // ----------------------------------------------------

  else if (
    uncMood ==
    UNC_FOCUSED
  ) {

    if (
      uncMessageIndex ==
      0
    ) {

      drawTypewriterText(
        "Locked in.",
        "Keep going!"
      );
    }

    else if (
      uncMessageIndex ==
      1
    ) {

      drawTypewriterText(
        "No scrolling.",
        "You got this."
      );
    }

    else {

      drawTypewriterText(
        "Stay on it.",
        "Almost there."
      );
    }
  }

  // ----------------------------------------------------
  // RESTING
  // ----------------------------------------------------

  else if (
    uncMood ==
    UNC_RESTING
  ) {

    if (
      uncMessageIndex ==
      0
    ) {

      drawTypewriterText(
        "Break time.",
        "Get up a bit."
      );
    }

    else if (
      uncMessageIndex ==
      1
    ) {

      drawTypewriterText(
        "Eyes off screen.",
        "You earned it."
      );
    }

    else {

      drawTypewriterText(
        "Reset yourself.",
        "Round two soon."
      );
    }
  }

  // ----------------------------------------------------
  // ACTIVE
  // ----------------------------------------------------

  else if (
    uncMood ==
    UNC_ACTIVE
  ) {

    if (
      uncMessageIndex ==
      0
    ) {

      drawTypewriterText(
        "We're moving!",
        "Love to see it."
      );
    }

    else if (
      uncMessageIndex ==
      1
    ) {

      drawTypewriterText(
        "Nice.",
        "Keep it moving."
      );
    }

    else {

      drawTypewriterText(
        "Movement check:",
        "passed."
      );
    }
  }

  // ----------------------------------------------------
  // INACTIVE
  // ----------------------------------------------------

  else if (
    uncMood ==
    UNC_INACTIVE
  ) {

    if (
      uncMessageIndex ==
      0
    ) {

      drawTypewriterText(
        "Been still awhile.",
        "Wanna stretch?"
      );
    }

    else if (
      uncMessageIndex ==
      1
    ) {

      drawTypewriterText(
        "Quick break?",
        "Move around a bit."
      );
    }

    else {

      drawTypewriterText(
        "Your legs called.",
        "They miss you."
      );
    }
  }
}

// ======================================================
// FOCUS SCREEN
// ======================================================

void drawFocusScreen() {

  if (
    pomoState ==
    POMO_SETUP
  ) {

    drawFocusSetup();

    return;
  }

  display.setTextSize(1);

  unsigned long elapsed =
    pomoElapsedBeforePause;

  if (pomoRunning) {

    elapsed +=
      millis() -
      pomoStartTime;
  }

  unsigned long duration =
    getPomodoroDuration();

  float progress =
    (float)elapsed /
    (float)duration;

  if (
    progress > 1.0
  ) {

    progress =
      1.0;
  }

  // ----------------------------------------------------
  // HEADER
  // ----------------------------------------------------

  const char *headerTitle = "LONG BREAK";
  if (
    pomoState ==
    POMO_FOCUS
  ) {
    headerTitle = "FOCUS";
  }

  else if (
    pomoState ==
    POMO_SHORT_BREAK
  ) {

    headerTitle = "BREAK";
  }
  drawHeader(headerTitle);

  String sessionText =
    String(pomoSession) +
    "/" +
    String(selectedSessions);

  int sessionX =
    128 -
    sessionText.length() *
    6;

  display.setCursor(
    sessionX,
    0
  );

  display.print(
    sessionText
  );

  // ----------------------------------------------------
  // DISPLAY TIME
  // ----------------------------------------------------

  int totalSeconds;

  if (
    pomoState ==
    POMO_FOCUS
  ) {

    totalSeconds =
      25 * 60;
  }

  else if (
    pomoState ==
    POMO_SHORT_BREAK
  ) {

    totalSeconds =
      5 * 60;
  }

  else {

    totalSeconds =
      15 * 60;
  }

  int remaining =
    totalSeconds *
    (1.0 - progress);

  if (
    remaining < 0
  ) {

    remaining =
      0;
  }

  int minutes =
    remaining / 60;

  int seconds =
    remaining % 60;

  display.setTextSize(3);

  display.setCursor(
    19,
    15
  );

  if (
    minutes < 10
  ) {

    display.print("0");
  }

  display.print(
    minutes
  );

  display.print(":");

  if (
    seconds < 10
  ) {

    display.print("0");
  }

  display.print(
    seconds
  );

  // ----------------------------------------------------
  // PROGRESS BAR
  // ----------------------------------------------------

  display.drawRect(
    9,
    44,
    110,
    8,
    SSD1306_WHITE
  );

  int fillWidth =
    progress *
    108;

  display.fillRect(
    10,
    45,
    fillWidth,
    6,
    SSD1306_WHITE
  );

  // ----------------------------------------------------
  // STATUS
  // ----------------------------------------------------

  display.setTextSize(1);

  if (!pomoRunning) {

    display.setCursor(
      46,
      55
    );

    display.print(
      "PAUSED"
    );
  }

  else if (
    pomoState ==
    POMO_FOCUS
  ) {

    display.setCursor(
      40,
      55
    );

    display.print(
      "FOCUSING"
    );
  }

  else {

    display.setCursor(
      43,
      55
    );

    display.print(
      "RESTING"
    );
  }
}

// ======================================================
// FOCUS SETUP
// ======================================================

void drawFocusSetup() {

  display.setTextSize(1);

  display.setCursor(
    0,
    0
  );

  display.print(
    "<HOLD"
  );

  display.setCursor(
    62,
    0
  );

  display.print(
    "FOCUS SETUP"
  );

  display.drawLine(
    0,
    10,
    127,
    10,
    SSD1306_WHITE
  );

  display.setCursor(
    40,
    15
  );

  display.print(
    "Sessions"
  );

  display.setTextSize(3);

  display.setCursor(
    55,
    26
  );

  display.print(
    selectedSessions
  );

  display.setTextSize(2);

  display.setCursor(
    19,
    29
  );

  display.print("-");

  display.setCursor(
    99,
    29
  );

  display.print("+");

  display.setTextSize(1);

  display.setCursor(
    22,
    55
  );

  display.print(
    "CENTER = START"
  );
}

// ======================================================
// HEALTH
// ======================================================

// Called after each sensor read, even when another screen is open.
void updatePulseHistory() {
  if (currentIR < FINGER_THRESHOLD) {
    pulseHead = 0;
    pulseCount = 0;
    pulseScaleReady = false;
    hasValidBeat = false;
    return;
  }

  unsigned long now = millis();
  if (pulseCount > 0 && now - lastPulseSample < PULSE_SAMPLE_INTERVAL) {
    return;
  }
  lastPulseSample = now;

  // Remove slow contact/brightness drift so small pulses stay visible.
  // These display-only values never feed back into beat detection.
  if (pulseCount == 0) {
    pulseBaselineIR = currentIR;
    displayIR = 0;
  } else {
    pulseBaselineIR += 0.08f * (currentIR - pulseBaselineIR);
    float pulseIR = currentIR - pulseBaselineIR;
    displayIR += 0.85f * (pulseIR - displayIR);
  }
  pulseSamples[pulseHead] = (long)displayIR;
  pulseHead = (pulseHead + 1) % PULSE_SAMPLES;
  if (pulseCount < PULSE_SAMPLES) pulseCount++;

  int oldest = (pulseHead - pulseCount + PULSE_SAMPLES) % PULSE_SAMPLES;
  // Ignore isolated extremes when choosing scale. Large contact bumps may
  // clip at the graph edges instead of flattening several seconds of pulses.
  long sorted[PULSE_SAMPLES];
  for (int i = 0; i < pulseCount; i++) {
    sorted[i] = pulseSamples[(oldest + i) % PULSE_SAMPLES];
    int j = i;
    while (j > 0 && sorted[j] < sorted[j - 1]) {
      long value = sorted[j];
      sorted[j] = sorted[j - 1];
      sorted[j - 1] = value;
      j--;
    }
  }
  int trim = pulseCount / 10;
  long low = sorted[trim];
  long high = sorted[pulseCount - 1 - trim];
  float midpoint = (low + high) * 0.5f;
  // Minimum span prevents tiny noise from filling the graph.
  float span = (high - low) * 1.1f;
  if (span < 80.0f) span = 80.0f;
  float targetLow = midpoint - span * 0.5f;
  float targetHigh = midpoint + span * 0.5f;
  if (!pulseScaleReady) {
    pulseScaleLow = targetLow;
    pulseScaleHigh = targetHigh;
    pulseScaleReady = true;
  } else {
    // Expand immediately; contract gently to avoid scale flicker.
    pulseScaleLow += (targetLow < pulseScaleLow ? 1.0f : 0.25f) *
                     (targetLow - pulseScaleLow);
    pulseScaleHigh += (targetHigh > pulseScaleHigh ? 1.0f : 0.25f) *
                      (targetHigh - pulseScaleHigh);
  }
}

void drawPulseHeart(bool expanded) {
  int radius = expanded ? 5 : 4;
  int left = expanded ? 12 : 13;
  int right = expanded ? 22 : 21;
  int top = expanded ? 18 : 19;
  display.fillCircle(left, top, radius, SSD1306_WHITE);
  display.fillCircle(right, top, radius, SSD1306_WHITE);
  display.fillTriangle(left - radius, top + 1,
                       right + radius, top + 1,
                       17, expanded ? 33 : 31, SSD1306_WHITE);
}

void drawPulseWaveform() {
  // 64 samples span x=1..127; new readings enter at the right edge.
  if (!maxOK || !fingerPresent || pulseCount < 2) {
    for (int x = 2; x < 128; x += 6) {
      display.drawPixel(x, 45, SSD1306_WHITE);
    }
    return;
  }
  int oldest = (pulseHead - pulseCount + PULSE_SAMPLES) % PULSE_SAMPLES;
  int previousX = 0;
  int previousY = 0;
  for (int i = 0; i < pulseCount; i++) {
    long value = pulseSamples[(oldest + i) % PULSE_SAMPLES];
    float normalized = (value - pulseScaleLow) / (pulseScaleHigh - pulseScaleLow);
    normalized = constrain(normalized, 0.0f, 1.0f);
    int x = 1 + (PULSE_SAMPLES - pulseCount + i) * 2;
    // Falling IR pulses appear as upward peaks on the screen.
    int y = 38 + (int)(normalized * 14.0f);
    if (i > 0) display.drawLine(previousX, previousY, x, y, SSD1306_WHITE);
    previousX = x;
    previousY = y;
  }
}

void drawHealthScreen() {
  unsigned long now = millis();
  bool recentBeat = hasValidBeat && now - lastValidBeatTime < BPM_DISPLAY_TIMEOUT;
  bool showBPM = maxOK && fingerPresent && heartRateReady &&
                 filteredBPM > 0 && recentBeat;

  drawHeader("HEART RATE");

  drawPulseHeart(showBPM && now - lastValidBeatTime < HEART_PULSE_DURATION);
  display.setTextSize(3);
  String value = showBPM ? String((int)round(filteredBPM)) : "--";
  // Right-aligned value reserves space for all three digits and the unit.
  display.setCursor(100 - value.length() * 18, 14);
  display.print(value);
  display.setTextSize(1);
  display.setCursor(106, 27);
  display.print("BPM");

  drawPulseWaveform();

  String status;
  if (!maxOK) status = "SENSOR ERROR";
  else if (!fingerPresent) status = "PLACE FINGER";
  else if (!heartRateReady) status = "READING...";
  else if (!showBPM) status = "HOLD STILL";
  else status = "LIVE PULSE";
  drawCenteredText(status, 56);
}
