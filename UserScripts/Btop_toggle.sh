#!/bin/bash

if pgrep -x btop > /dev/null; then
  pkill -x btop
else 
  hyprctl dispatch exec '[float; size 1200 650] kitty -e btop'
fi
