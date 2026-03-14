#!/bin/bash

osascript -l JavaScript <<'JXA'
ObjC.import('Cocoa');
ObjC.import('ApplicationServices');

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

function clickOBSStatusMenuItem(itemName) {
  const se = Application('System Events');
  const obs = se.applicationProcesses.byName('OBS');
  const statusItem = obs.menuBars[1].menuBarItems[0];
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
clickAt(windowPos.x + 270, windowPos.y + 85);
sleepSeconds(0.3);
clickOBSStartRecording();
sleepSeconds(0.5);

for (let i = 0; i < 519; i += 1) {
  pressA();
  sleepSeconds(4.0);
  clickAt(windowPos.x + 1013, windowPos.y + 75);
  sleepSeconds(0.3);
}

clickOBSStopRecording();
JXA
