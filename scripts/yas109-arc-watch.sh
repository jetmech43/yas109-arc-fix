#!/bin/sh
# yas109-arc-watch.sh  —  runs ON THE SOUNDBAR (MediaTek MT8516 Linux side), as root.
# Installed to /data by install-fix.sh and started by yas109-arc.service.
#
# Why: the bar's MCU runs its HDMI-ARC init exactly ONCE at MCU boot and never
# re-runs it, so after the TV powers off/on, ARC never re-handshakes. Pulsing a
# reset at the MCU makes it re-run that one-time init, and ARC comes back.
#
# How: poll the kernel suspend counter; each time it increments (the bar resumed,
# i.e. the TV powered back on), send the MCU's reset command over the UART.
TTY=/dev/ttyS1
LOG=/data/yas109-arc.log
STAT=/sys/power/suspend_stats/success
echo "$(date) watcher started (pid $$)" >> "$LOG"
last=$(cat "$STAT" 2>/dev/null || echo 0)
while true; do
  sleep 5
  cur=$(cat "$STAT" 2>/dev/null || echo "$last")
  if [ "$cur" != "$last" ]; then
    echo "$(date) resume detected (count $last -> $cur)" >> "$LOG"
    if [ -c "$TTY" ]; then
      stty -F "$TTY" 115200 cs8 -parenb -cstopb raw 2>/dev/null
      sleep 2
      printf 'AXX+DEV+RST' > "$TTY"   # 11 ASCII bytes, no terminator (verified)
      echo "$(date) sent AXX+DEV+RST to $TTY" >> "$LOG"
    else
      echo "$(date) ERROR: $TTY missing" >> "$LOG"
    fi
    last=$cur
  fi
done
