#!/bin/bash

# Arturia template:
# when copying this script for another plugin, usually only these two values need changing.
NEXT_BUTTON_X="${NEXT_BUTTON_X:-1000}"
NEXT_BUTTON_Y="${NEXT_BUTTON_Y:-97}"

# Optional overrides for batch generation.
PRESET_COUNT="${PRESET_COUNT:-255}"
PRESET_DURATION="${PRESET_DURATION:-4.0}"
INITIAL_CLICK_X="${INITIAL_CLICK_X:-270}"
INITIAL_CLICK_Y="${INITIAL_CLICK_Y:-85}"

NEXT_BUTTON_X="$NEXT_BUTTON_X" \
NEXT_BUTTON_Y="$NEXT_BUTTON_Y" \
PRESET_COUNT="$PRESET_COUNT" \
PRESET_DURATION="$PRESET_DURATION" \
INITIAL_CLICK_X="$INITIAL_CLICK_X" \
INITIAL_CLICK_Y="$INITIAL_CLICK_Y" \
osascript -l JavaScript <<'JXA'
ObjC.import('Cocoa');
ObjC.import('ApplicationServices');

const env = $.NSProcessInfo.processInfo.environment;
const envValue = (name) => ObjC.unwrap(env.objectForKey(name));

const nextButtonX = Number(envValue('NEXT_BUTTON_X'));
const nextButtonY = Number(envValue('NEXT_BUTTON_Y'));
const presetCount = Number(envValue('PRESET_COUNT'));
const presetDuration = Number(envValue('PRESET_DURATION'));
const initialClickX = Number(envValue('INITIAL_CLICK_X'));
const initialClickY = Number(envValue('INITIAL_CLICK_Y'));

function sleepSeconds(seconds) {
  $.NSThread.sleepForTimeInterval(seconds);
}

function clickAt(x, y) {
  const point = $.CGPointMake(x, y);
  const move = $.CGEventCreateMouseEvent(null, $.kCGEventMouseMoved, point, $.kCGMouseButtonLeft);
  $.CGEventPost($.kCGHIDEventTap, move);
  sleepSeconds(0.05);

  const down = $.CGEventCreateMouseEvent(null, $.kCGEventLeftMouseDown, point, $.kCGMouseButtonLeft);
  $.CGEventPost($.kCGHIDEventTap, down);
  sleepSeconds(0.03);

  const up = $.CGEventCreateMouseEvent(null, $.kCGEventLeftMouseUp, point, $.kCGMouseButtonLeft);
  $.CGEventPost($.kCGHIDEventTap, up);
}

function focusPreviewerAndGetWindowPosition() {
  const se = Application('System Events');
  const previewer = se.applicationProcesses.byName('previewer');
  previewer.frontmost = true;
  sleepSeconds(0.5);

  const pos = previewer.windows()[0].position();
  return { x: pos[0], y: pos[1] };
}

function getOBSStatusItem() {
  const se = Application('System Events');
  const obs = se.applicationProcesses.byName('OBS');
  return obs.menuBars[1].menuBarItems[0];
}

function clickOBSStatusMenuItem(itemName) {
  const statusItem = getOBSStatusItem();
  statusItem.click();
  sleepSeconds(0.4);
  statusItem.menus[0].menuItems.byName(itemName).click();
}

function clickOBSStartRecording() {
  clickOBSStatusMenuItem('Start Recording');
}

function clickOBSStopRecording() {
  clickOBSStatusMenuItem('Stop Recording');
}

function pressA() {
  Application('System Events').keystroke('a');
}

const windowPos = focusPreviewerAndGetWindowPosition();

clickOBSStartRecording();
sleepSeconds(1);

clickAt(windowPos.x + initialClickX, windowPos.y + initialClickY);
sleepSeconds(0.2);

for (let i = 0; i < presetCount; i += 1) {
  pressA();
  sleepSeconds(presetDuration);
  clickAt(windowPos.x + nextButtonX, windowPos.y + nextButtonY);
  sleepSeconds(0.2);
}

clickOBSStopRecording();
JXA
