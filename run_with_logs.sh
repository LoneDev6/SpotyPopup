#!/bin/bash
LOG_FILE="/tmp/spotypopup.log"
echo "Starting SpotyPopup with logging to $LOG_FILE"
echo "=== App started at $(date) ===" > "$LOG_FILE"

# Redirect stdout and stderr to log file
./SpotyPopup.app/Contents/MacOS/SpotyPopup >> "$LOG_FILE" 2>&1 &

echo "App started. Tail the log with:"
echo "tail -f $LOG_FILE"
