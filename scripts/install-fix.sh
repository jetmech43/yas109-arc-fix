#!/bin/sh
# YAS-109 ARC auto-fix INSTALLER (runs once as root via the USB update path).
# Re-inits HDMI-ARC after the TV powers off/on by resetting the MCU on resume.
# Safe persistence: a NEW systemd service + files in /data. No existing file edited.
# Reversible: the undo payload removes everything below.

USB=$(dirname "$(find /media /mnt /run /tmp -maxdepth 4 -name yamaha_usb_upgrade.enc 2>/dev/null | head -1)")
[ -d "$USB" ] || USB=/media
LOG=/data/yas109-fix-install.log

# --- 1. the resume watcher (persistent, in /data) -------------------------
cat > /data/yas109-arc-watch.sh <<'WATCH'
#!/bin/sh
# Polls the suspend counter; on each resume (TV powered back on) resets the MCU,
# which makes it re-run its one-time HDMI-ARC handshake at MCU boot.
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
      printf 'AXX+DEV+RST' > "$TTY"
      echo "$(date) sent AXX+DEV+RST to $TTY" >> "$LOG"
    else
      echo "$(date) ERROR: $TTY missing" >> "$LOG"
    fi
    last=$cur
  fi
done
WATCH
chmod +x /data/yas109-arc-watch.sh

# --- 2. a NEW systemd unit to run it (no existing file touched) ------------
cat > /etc/systemd/system/yas109-arc.service <<'UNIT'
[Unit]
Description=YAS-109 ARC re-init on resume
RequiresMountsFor=/data
[Service]
Type=simple
ExecStart=/data/yas109-arc-watch.sh
Restart=on-failure
RestartSec=10
[Install]
WantedBy=basic.target
UNIT

# enable it the same way the stock adbd unit is enabled (symlink in wants/)
mkdir -p /etc/systemd/system/basic.target.wants
ln -sf /etc/systemd/system/yas109-arc.service \
       /etc/systemd/system/basic.target.wants/yas109-arc.service

# --- 3. log the install to /data AND the USB stick ------------------------
{
  echo "=== YAS-109 ARC fix installed $(date) ==="
  echo "mcu_ver: $(cat /tmp/mcu_ver 2>/dev/null)"
  echo "installed files:"
  ls -l /data/yas109-arc-watch.sh \
        /etc/systemd/system/yas109-arc.service \
        /etc/systemd/system/basic.target.wants/yas109-arc.service
} 2>&1 | tee "$LOG" > "$USB/yas109-fix-install.txt" 2>/dev/null
sync
