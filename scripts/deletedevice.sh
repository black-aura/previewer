#!/bin/bash

osascript <<EOF
tell application "Live"
    activate
end tell

delay 0.2

tell application "System Events"
    keystroke "4" using option down
    key code 51
end tell


EOF
