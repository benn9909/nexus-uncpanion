#include "nexus_core.h"

// The watch's top-level behavior stays here. Feature implementations live in
// the focused .cpp files beside this sketch.
void setup() {
  Serial.begin(115200);
  pinMode(BUTTON_LEFT, INPUT_PULLUP);
  pinMode(BUTTON_CENTER, INPUT_PULLUP);
  pinMode(BUTTON_RIGHT, INPUT_PULLUP);
  Wire.begin(SDA_PIN, SCL_PIN);

  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED failed");
    while (1);
  }
  display.setTextColor(SSD1306_WHITE);

  mpuOK = mpu.begin();
  if (mpuOK) {
    mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
    mpu.setGyroRange(MPU6050_RANGE_500_DEG);
    mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
    Serial.println("MPU6050 OK");
  } else {
    Serial.println("MPU6050 FAILED");
  }

  maxOK = maxSensor.begin(Wire, I2C_SPEED_FAST);
  if (maxOK) {
    maxSensor.setup(0x1F, 8, 2, 100, 411, 4096);
    Serial.println("MAX3010x OK");
  } else {
    Serial.println("MAX3010x FAILED");
  }

  setupBLE();
  unsigned long now = millis();
  lastMovementTime = now;
  lastUncMessageChange = now;
  typewriterStartTime = now;
  randomSeed(micros());
  nextBlinkTime = now + random(2000, 5000);
}

void loop() {
  updateHeartRate();
  updateActivityData();
  updatePomodoro();
  updateUnc();
  updateUncAnimation();
  updateBLE();
  handleButtons();

  static unsigned long lastRenderAt = 0;
  if (millis() - lastRenderAt < 33) return;
  lastRenderAt = millis();

  display.clearDisplay();
  switch (currentScreen) {
    case HOME_SCREEN: drawHomeScreen(); break;
    case FOCUS_SCREEN: drawFocusScreen(); break;
    case HEALTH_SCREEN: drawHealthScreen(); break;
    case ACTIVITY_SCREEN: drawActivityScreen(); break;
  }
  applyPageTransition();
  display.display();
}
