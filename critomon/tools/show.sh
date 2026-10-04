#!/bin/bash
# Run Godot with a (virtual) screen so it can take pictures, hiding the sound-card noise.
# Usage: tools/show.sh -s res://tools/test/gallery.gd -- --dir=res://assets/arena
cd "$(dirname "$0")/.."
if [ -z "$DISPLAY" ] && command -v xvfb-run >/dev/null; then
  exec > >(grep -vE 'ALSA lib|libpulse|audio driver|dummy driver|init_output_device|audio_server.cpp|V-Sync|gl_manager_x11|^Godot Engine|^OpenGL API|^$') 2>&1
  timeout ${TIMEOUT:-300} xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 "$@"
else
  timeout ${TIMEOUT:-300} godot "$@"
fi
