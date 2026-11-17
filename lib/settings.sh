#!/usr/bin/env bash
# Open Rice Settings, or close it if it's already open.
dir="$HOME/.config/hypr/settings"
qs -p "$dir" kill >/dev/null 2>&1 || exec qs -p "$dir"
