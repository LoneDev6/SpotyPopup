#!/bin/bash
LOG_FILE="/tmp/spotifydui.log"
echo "Starting SpotifydUI with logging to $LOG_FILE"
echo "=== App started at $(date) ===" > "$LOG_FILE"

# Redirect stdout and stderr to log file
./SpotifydUI.app/Contents/MacOS/SpotifydUI >> "$LOG_FILE" 2>&1 &

echo "App started. Tail the log with:"
echo "tail -f $LOG_FILE"
