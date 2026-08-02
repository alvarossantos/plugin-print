#!/bin/bash
# Cancel recording: kill process and delete file BEFORE the service detects it
pkill -9 -f 'gpu-screen-recorder' 2>/dev/null || true
f=$(ls -t "$HOME"/Videos/Recordings/*.mp4 "$HOME"/Videos/*.mp4 2>/dev/null | head -1)
[ -n "$f" ] && [ -f "$f" ] && rm -f "$f"
