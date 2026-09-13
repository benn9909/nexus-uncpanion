#pragma once

#include <Arduino.h>

extern float currentAccelMagnitude;
extern bool currentlyMoving;
extern bool inactiveTooLong;
extern unsigned long lastMovementTime;

void updateActivityData();
void drawActivityScreen();
