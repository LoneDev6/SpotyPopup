#!/bin/bash
echo "Watching SpotyPopup logs (Ctrl+C to stop)..."
echo "Open the main window now to see playlist loading..."
echo ""

# Find the app process and tail its output
log show --predicate 'process == "SpotyPopup"' --style compact --last 1m
